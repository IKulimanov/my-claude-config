#!/usr/bin/env python3
"""Импорт плана 02-plan.md в Jira: этапы — задачами, подзадачи — сабтасками.

Создаёт задачи в указанном эпике, проставляет оценки и связи «блокирует».
Только стандартная библиотека: сторонние пакеты не нужны.

Авторизация — через переменные окружения, чтобы токен не попадал в историю
команд и в список процессов:

    export JIRA_URL=https://jirasd.o.kg
    export JIRA_TOKEN=<personal access token>   # Jira DC: Profile → Personal Access Tokens
    export JIRA_USER=<логин>                    # только если нужен basic-режим

Те же переменные можно положить в файл (строки KEY=VALUE) и передать через --env .env;
переменные, уже заданные в окружении, файл не перекрывает. Файл с токеном держите вне
git — .env в tools/ уже в .gitignore.

Запуск:

    python3 jira_import.py --epic IT-1234 --dry-run        # показать, что будет создано
    python3 jira_import.py --epic IT-1234                  # создать в проекте эпика
    python3 jira_import.py --epic IT-1234 --project ORSP   # создать в другом проекте
    python3 jira_import.py --epic IT-1234 --stage 1        # только этап 1 с подзадачами
    python3 jira_import.py --epic IT-1234 --confirm        # подтверждать каждую задачу
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

PLAN_PREFIX = "dba-ops-assistant"

STAGE_RE = re.compile(r"^# Этап (\d+)\.\s*\[" + PLAN_PREFIX + r"\]\s*(.+?)\s*$")
SUBTASK_RE = re.compile(r"^### (\d+\.\d+)\s+((?:\[[^\]]+\]\s*)+)(.+?)\s*$")
COMPONENT_RE = re.compile(r"\[([^\]]+)\]")
ESTIMATE_RE = re.compile(r"^Оценка:\s*(\d+(?:[.,]\d+)?)\s*час\w*\.?\s*(\(лимит\))?")


@dataclass
class Subtask:
    number: str
    stage: int
    components: list[str]
    title: str
    what: str = ""
    criteria: list[str] = field(default_factory=list)
    open_questions: list[str] = field(default_factory=list)
    depends_on: list[str] = field(default_factory=list)
    hours: float = 0
    timeboxed: bool = False

    @property
    def summary(self) -> str:
        prefix = "".join(f"[{c}] " for c in self.components)
        return f"{prefix}{self.number} {self.title}"


@dataclass
class Stage:
    number: int
    title: str
    why: str = ""
    result: str = ""
    open_questions: list[str] = field(default_factory=list)
    composition: list[str] = field(default_factory=list)
    depends_note: str = ""
    subtasks: list[Subtask] = field(default_factory=list)

    @property
    def summary(self) -> str:
        return f"[{PLAN_PREFIX}] Этап {self.number}. {self.title}"

    @property
    def key(self) -> str:
        return f"stage-{self.number}"


def _clean(lines: list[str]) -> str:
    return " ".join(line.strip() for line in lines if line.strip()).strip()


def _bullets(lines: list[str]) -> list[str]:
    """Собирает пункты списка, склеивая перенесённые строки."""
    items: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("- "):
            items.append(stripped[2:].strip())
        elif items:
            items[-1] += " " + stripped
    return items


def _parse_dependencies(text: str) -> list[str]:
    if text.strip().lower().startswith("нет"):
        return []
    result = []
    for part in text.split(","):
        part = part.strip().rstrip(".").strip()
        if not part:
            continue
        if re.fullmatch(r"\d+\.\d+", part) or re.fullmatch(r"этап \d+", part):
            result.append(part)
    return result


def parse_plan(text: str) -> list[Stage]:
    """Разбирает 02-plan.md в список этапов с подзадачами.

    Все подзадачи, включая «Анализ», описаны в плане разделами `### N.M` — скрипт
    ничего не достраивает сам.
    """
    stages: list[Stage] = []
    stage: Stage | None = None
    task: Subtask | None = None
    section: str | None = None   # текущий раздел этапа: why/result/questions/composition/depends
    field_name: str | None = None  # текущее поле подзадачи
    buffer: list[str] = []

    def flush_field():
        """Записывает накопленный буфер в поле подзадачи. Буфер чужой секции не трогает."""
        nonlocal buffer, field_name
        if field_name is None:
            return
        if task is not None:
            if field_name == "what":
                task.what = _clean(buffer)
            elif field_name == "criteria":
                task.criteria = _bullets(buffer)
            elif field_name == "open_questions":
                task.open_questions = _bullets(buffer)
        buffer = []
        field_name = None

    def flush_section():
        """Записывает накопленный буфер в раздел этапа."""
        nonlocal buffer, section
        if section is None:
            return
        if stage is not None:
            if section == "why":
                stage.why = _clean(buffer)
            elif section == "result":
                stage.result = _clean(buffer)
            elif section == "questions":
                stage.open_questions = _bullets(buffer)
            elif section == "composition":
                stage.composition = [
                    re.sub(r"^\d+\.\s*", "", line.strip())
                    for line in buffer
                    if re.match(r"^\d+\.", line.strip())
                ]
            elif section == "depends":
                stage.depends_note = _clean(buffer)
        buffer = []
        section = None

    for line in text.splitlines():
        stage_match = STAGE_RE.match(line)
        if stage_match:
            flush_field()
            flush_section()
            task = None
            stage = Stage(number=int(stage_match.group(1)), title=stage_match.group(2))
            stages.append(stage)
            continue

        if stage is None:
            continue

        subtask_match = SUBTASK_RE.match(line)
        if subtask_match:
            flush_field()
            flush_section()
            number = subtask_match.group(1)
            task = Subtask(
                number=number,
                stage=int(number.split(".")[0]),
                components=COMPONENT_RE.findall(subtask_match.group(2)),
                title=subtask_match.group(3),
            )
            stage.subtasks.append(task)
            continue

        if line.startswith("## "):
            flush_field()
            flush_section()
            task = None
            buffer = []   # текст между разделами (разделители, вводные абзацы) не нужен
            heading = line[3:].strip()
            if heading == "Зачем":
                section = "why"
            elif heading.startswith("Результат"):
                section = "result"
            elif heading.startswith("Открытые вопросы"):
                section = "questions"
            elif heading == "Состав":
                section = "composition"
            elif heading == "Зависимости":
                section = "depends"
            continue

        if task is None:
            buffer.append(line)
            continue

        if line.startswith("Что сделать:"):
            flush_field()
            field_name = "what"
            buffer = [line[len("Что сделать:"):]]
        elif line.startswith("Критерии приёмки:"):
            flush_field()
            field_name = "criteria"
        elif line.startswith("Открытые вопросы:"):
            flush_field()
            field_name = "open_questions"
        elif line.startswith("Зависимости:"):
            flush_field()
            task.depends_on = _parse_dependencies(line[len("Зависимости:"):])
        elif ESTIMATE_RE.match(line):
            flush_field()
            estimate = ESTIMATE_RE.match(line)
            task.hours = float(estimate.group(1).replace(",", "."))
            task.timeboxed = bool(estimate.group(2))
        else:
            buffer.append(line)

    flush_field()
    flush_section()
    return stages


def render_description(task: Subtask) -> str:
    """Описание подзадачи в разметке Jira wiki."""
    what = task.what[:1].upper() + task.what[1:] if task.what else ""
    blocks = [f"h3. Что сделать\n{what}"]
    if task.criteria:
        blocks.append("h3. Критерии приёмки\n" + "\n".join(f"* {c}" for c in task.criteria))
    if task.open_questions:
        blocks.append("h3. Открытые вопросы\n"
                      + "\n".join(f"* {q}" for q in task.open_questions))
    if task.timeboxed:
        blocks.append("h3. Ограничение\nТаймбокс: "
                      f"{task.hours:g} ч — по их истечении фиксируется найденное решение.")
    return "\n\n".join(blocks)


def render_stage_description(stage: Stage) -> str:
    blocks = [f"h3. Зачем\n{stage.why}", f"h3. Результат этапа\n{stage.result}"]
    if stage.open_questions:
        blocks.append("h3. Открытые вопросы\n"
                      + "\n".join(f"* {q}" for q in stage.open_questions))
    if stage.composition:
        blocks.append("h3. Состав\n" + "\n".join(f"# {c}" for c in stage.composition))
    if stage.depends_note:
        blocks.append(f"h3. Зависимости\n{stage.depends_note}")
    return "\n\n".join(blocks)


class JiraError(RuntimeError):
    pass


class Jira:
    def __init__(self, base_url: str, token: str, user: str | None = None, timeout: int = 30):
        self.base = base_url.rstrip("/")
        self.timeout = timeout
        if user:
            raw = base64.b64encode(f"{user}:{token}".encode()).decode()
            self.auth = f"Basic {raw}"
        else:
            self.auth = f"Bearer {token}"

    def _request(self, method: str, path: str, payload: dict | None = None) -> dict:
        url = f"{self.base}{path}"
        data = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", self.auth)
        request.add_header("Content-Type", "application/json")
        request.add_header("Accept", "application/json")

        last_error = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    body = response.read().decode() or "{}"
                    return json.loads(body) if body.strip() else {}
            except urllib.error.HTTPError as error:
                body = error.read().decode(errors="replace")
                if error.code in (429, 500, 502, 503, 504) and attempt < 2:
                    last_error = body
                    time.sleep(2 * (attempt + 1))
                    continue
                raise JiraError(f"{method} {path} → HTTP {error.code}: {body}") from error
            except urllib.error.URLError as error:
                if attempt < 2:
                    last_error = str(error.reason)
                    time.sleep(2 * (attempt + 1))
                    continue
                raise JiraError(f"{method} {path} → сеть недоступна: {error.reason}") from error
        raise JiraError(f"{method} {path} → не удалось после трёх попыток: {last_error}")

    def myself(self) -> dict:
        return self._request("GET", "/rest/api/2/myself")

    def issue(self, key: str) -> dict:
        return self._request("GET", f"/rest/api/2/issue/{urllib.parse.quote(key)}")

    def project(self, key: str) -> dict:
        return self._request("GET", f"/rest/api/2/project/{urllib.parse.quote(key)}")

    def epic_link_field(self) -> str | None:
        for item in self._request("GET", "/rest/api/2/field"):
            if item.get("name") == "Epic Link":
                return item["id"]
        return None

    def create_issue(self, fields: dict) -> str:
        return self._request("POST", "/rest/api/2/issue", {"fields": fields})["key"]

    def link(self, blocker: str, blocked: str) -> None:
        self._request("POST", "/rest/api/2/issueLink", {
            "type": {"name": "Blocks"},
            "outwardIssue": {"key": blocker},
            "inwardIssue": {"key": blocked},
        })


class State:
    """Соответствие «номер в плане → ключ задачи»: повторный запуск не создаёт дублей."""

    def __init__(self, path: Path):
        self.path = path
        self.data = {"epic": None, "issues": {}, "links": []}
        if path.exists():
            self.data.update(json.loads(path.read_text(encoding="utf-8")))

    def save(self) -> None:
        self.path.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")

    def key_of(self, number: str) -> str | None:
        return self.data["issues"].get(number)

    def remember(self, number: str, issue_key: str) -> None:
        self.data["issues"][number] = issue_key
        self.save()

    def linked(self, blocker: str, blocked: str) -> bool:
        return f"{blocker}->{blocked}" in self.data["links"]

    def remember_link(self, blocker: str, blocked: str) -> None:
        self.data["links"].append(f"{blocker}->{blocked}")
        self.save()


def pick_issue_types(project: dict, task_name: str | None, subtask_name: str | None) -> tuple[str, str]:
    types = project.get("issueTypes", [])
    names = [t["name"] for t in types]

    def find(preferred: list[str], want_subtask: bool) -> str:
        for name in preferred:
            for issue_type in types:
                if issue_type["name"].lower() == name.lower():
                    return issue_type["name"]
        for issue_type in types:
            if bool(issue_type.get("subtask")) == want_subtask and issue_type["name"] != "Epic":
                return issue_type["name"]
        raise JiraError(f"не найден тип задачи (subtask={want_subtask}); есть: {names}")

    task = task_name or find(["Task", "Задача"], want_subtask=False)
    subtask = subtask_name or find(["Sub-task", "Подзадача", "Подзадание"], want_subtask=True)
    return task, subtask


ENV_LINE_RE = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")


def load_env_file(path: Path, environ) -> None:
    """Читает файл вида KEY=VALUE в окружение; уже заданные переменные не перекрывает."""
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = ENV_LINE_RE.match(stripped)
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        environ.setdefault(key, value)


def select_stages(stages: list[Stage], numbers: list[int] | None) -> list[Stage]:
    """Оставляет только запрошенные этапы; без фильтра возвращает все."""
    if not numbers:
        return stages
    missing = sorted(set(numbers) - {s.number for s in stages})
    if missing:
        raise ValueError(f"в плане нет этапов: {', '.join(map(str, missing))}")
    return [s for s in stages if s.number in numbers]


def parse_answer(raw: str) -> str:
    """Ответ на подтверждение: yes / no / all (дальше без вопросов) / stop / unknown."""
    answer = raw.strip().lower()
    if answer in ("", "y", "д", "да", "yes"):
        return "yes"
    if answer in ("n", "н", "нет", "no"):
        return "no"
    if answer in ("a", "в", "все", "всё", "all"):
        return "all"
    if answer in ("q", "с", "стоп", "quit", "выход"):
        return "stop"
    return "unknown"


class StopImport(Exception):
    """Пользователь остановил создание; прогресс уже сохранён в файле состояния."""


def resolve_project(epic_project: str, override: str | None, epic_field: str | None) -> str:
    """Проект для создаваемых задач: по умолчанию — проект эпика.

    Задачи в чужом проекте привязываются к эпику только полем Epic Link;
    запасной вариант через parent работает лишь внутри проекта эпика.
    """
    if not override or override == epic_project:
        return epic_project
    if not epic_field:
        raise JiraError(
            f"в инстансе нет поля Epic Link: задачи проекта {override} "
            f"не к чему привязать — эпик остаётся в {epic_project}")
    return override


def build_fields(summary: str, description: str, project_key: str, issue_type: str,
                 hours: float = 0, labels: list[str] | None = None,
                 parent: str | None = None, epic_field: str | None = None,
                 epic: str | None = None) -> dict:
    fields = {
        "project": {"key": project_key},
        "summary": summary,
        "description": description,
        "issuetype": {"name": issue_type},
    }
    if labels:
        fields["labels"] = labels
    if hours:
        fields["timetracking"] = {"originalEstimate": f"{hours:g}h"}
    if parent:
        fields["parent"] = {"key": parent}
    if epic and epic_field:
        fields[epic_field] = epic
    return fields


def label_for(component: str) -> str:
    return re.sub(r"[^0-9A-Za-zА-Яа-яЁё]+", "-", component).strip("-")


def create_issue_safely(jira: Jira, fields: dict) -> str:
    """Создаёт задачу; если в проекте выключен учёт времени — повторяет без оценки."""
    try:
        return jira.create_issue(fields)
    except JiraError as error:
        if "timetracking" in str(error) and "timetracking" in fields:
            fields = {k: v for k, v in fields.items() if k != "timetracking"}
            print("    учёт времени недоступен — задача создаётся без оценки", file=sys.stderr)
            return jira.create_issue(fields)
        raise


def run(args) -> int:
    if args.env:
        env_path = Path(args.env)
        if not env_path.exists():
            print(f"Файл переменных не найден: {env_path}", file=sys.stderr)
            return 2
        load_env_file(env_path, os.environ)

    plan_path = Path(args.file).resolve()
    stages = parse_plan(plan_path.read_text(encoding="utf-8"))
    try:
        stages = select_stages(stages, args.stage)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    all_tasks = [t for stage in stages for t in stage.subtasks]
    total_hours = sum(t.hours for t in all_tasks)

    print(f"План: {plan_path}")
    if args.stage:
        print(f"Только этапы: {', '.join(str(s.number) for s in stages)}")
    print(f"Этапов: {len(stages)}, подзадач: {len(all_tasks)}, оценка: {total_hours:g} ч")

    if args.dry_run:
        for stage in stages:
            print(f"\n{stage.summary}")
            for task in stage.subtasks:
                blockers = task.depends_on
                suffix = f"  ← ждёт: {', '.join(blockers)}" if blockers else ""
                print(f"  {task.summary}  [{task.hours:g}ч]{suffix}")
        print("\nПробный прогон: в Jira ничего не создано.")
        return 0

    url = args.url or os.environ.get("JIRA_URL")
    token = os.environ.get("JIRA_TOKEN")
    user = os.environ.get("JIRA_USER")
    if not url:
        print("Не задан адрес Jira: --url или JIRA_URL", file=sys.stderr)
        return 2
    if not token:
        print("Не задан JIRA_TOKEN (personal access token вашей учётки)", file=sys.stderr)
        return 2

    jira = Jira(url, token, user)
    me = jira.myself()
    print(f"Jira: {url}, учётка: {me.get('displayName')} ({me.get('name') or me.get('emailAddress')})")

    epic = jira.issue(args.epic)
    epic_project = epic["fields"]["project"]["key"]
    print(f"Эпик: {args.epic} — {epic['fields']['summary']} (проект {epic_project})")

    epic_field = jira.epic_link_field()
    project_key = resolve_project(epic_project, args.project, epic_field)
    if project_key != epic_project:
        print(f"Задачи создаются в проекте {project_key}; эпик остаётся в {epic_project}")

    task_type, subtask_type = pick_issue_types(jira.project(project_key), args.task_type, args.subtask_type)
    print(f"Типы задач: этап — «{task_type}», подзадача — «{subtask_type}»; "
          f"поле эпика: {epic_field or 'parent'}")

    state = State(Path(args.state))
    if state.data["epic"] and state.data["epic"] != args.epic:
        print(f"Файл состояния {args.state} относится к эпику {state.data['epic']}. "
              f"Укажите другой --state или удалите файл.", file=sys.stderr)
        return 2
    if state.data.get("project") and state.data["project"] != project_key:
        print(f"Файл состояния {args.state} относится к проекту {state.data['project']}. "
              f"Укажите другой --state или удалите файл.", file=sys.stderr)
        return 2
    state.data["epic"] = args.epic
    state.data["project"] = project_key
    state.save()

    ask_each = args.confirm

    def confirmed(kind: str, summary: str) -> bool:
        nonlocal ask_each
        if not ask_each:
            return True
        while True:
            answer = parse_answer(input(f"Создать {kind} «{summary}»? [Y/n/a/q] "))
            if answer == "yes":
                return True
            if answer == "no":
                return False
            if answer == "all":
                ask_each = False
                return True
            if answer == "stop":
                raise StopImport
            print("  ответы: y — создать, n — пропустить, a — дальше без вопросов, q — остановиться")

    print("\nСоздание этапов")
    for stage in stages:
        if state.key_of(stage.key):
            print(f"  = {stage.key}: {state.key_of(stage.key)} (уже создан)")
            continue
        if not confirmed("задачу этапа", stage.summary):
            print(f"  - пропущен: {stage.summary}")
            continue
        fields = build_fields(
            summary=stage.summary,
            description=render_stage_description(stage),
            project_key=project_key,
            issue_type=task_type,
            labels=[label_for(PLAN_PREFIX)],
            epic_field=epic_field,
            epic=args.epic,
        )
        if not epic_field:
            fields["parent"] = {"key": args.epic}
        key = create_issue_safely(jira, fields)
        state.remember(stage.key, key)
        print(f"  + {key}: {stage.summary}")

    print("\nСоздание подзадач")
    for stage in stages:
        parent_key = state.key_of(stage.key)
        for task in stage.subtasks:
            if state.key_of(task.number):
                print(f"  = {task.number}: {state.key_of(task.number)} (уже создана)")
                continue
            if parent_key is None:
                print(f"  - {task.number}: задача этапа не создана, подзадача пропущена")
                continue
            if not confirmed("подзадачу", task.summary):
                print(f"  - пропущена: {task.summary}")
                continue
            fields = build_fields(
                summary=task.summary,
                description=render_description(task),
                project_key=project_key,
                issue_type=subtask_type,
                hours=task.hours,
                labels=[label_for(c) for c in task.components],
                parent=parent_key,
            )
            key = create_issue_safely(jira, fields)
            state.remember(task.number, key)
            print(f"  + {key}: {task.summary} [{task.hours:g}ч]")

    print("\nСвязи «блокирует»")
    for stage in stages:
        for task in stage.subtasks:
            blocked_key = state.key_of(task.number)
            if not blocked_key:
                continue   # подзадача пропущена — связывать нечего
            for blocker in task.depends_on:
                blocker_number = (f"stage-{blocker.split()[1]}"
                                  if blocker.startswith("этап ") else blocker)
                blocker_key = state.key_of(blocker_number)
                if not blocker_key:
                    print(f"  ! {task.number}: не найдена задача для «{blocker}»", file=sys.stderr)
                    continue
                if state.linked(blocker_key, blocked_key):
                    continue
                jira.link(blocker_key, blocked_key)
                state.remember_link(blocker_key, blocked_key)
                print(f"  + {blocker_key} блокирует {blocked_key}  ({blocker} → {task.number})")

    print(f"\nГотово. Соответствие номеров и ключей: {args.state}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Создаёт в Jira задачи этапов и подзадачи из 02-plan.md",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--epic", required=True, help="ключ эпика, например IT-1234")
    parser.add_argument("--project", help="ключ проекта для задач, например ORSP "
                        "(по умолчанию — проект эпика; для чужого проекта нужно поле Epic Link)")
    parser.add_argument("--env", help="файл с переменными окружения (JIRA_URL, JIRA_TOKEN, JIRA_USER); "
                        "уже заданные в окружении переменные файл не перекрывает")
    parser.add_argument("--url", help="адрес Jira (по умолчанию из JIRA_URL)")
    parser.add_argument("--file", default=str(Path(__file__).resolve().parent.parent / "02-plan.md"),
                        help="путь к плану")
    parser.add_argument("--dry-run", action="store_true", help="показать план создания, ничего не менять")
    parser.add_argument("--stage", type=int, action="append",
                        help="создать только этот этап с его подзадачами; можно повторять: "
                             "--stage 1 --stage 2 (по умолчанию — весь план)")
    parser.add_argument("--confirm", action="store_true",
                        help="спрашивать подтверждение перед созданием каждой задачи")
    parser.add_argument("--state", default=str(Path(__file__).resolve().parent / ".jira-import-state.json"),
                        help="файл соответствия номеров и ключей задач")
    parser.add_argument("--task-type", help="тип задачи для этапа (по умолчанию Task/Задача)")
    parser.add_argument("--subtask-type", help="тип подзадачи (по умолчанию Sub-task/Подзадача)")
    args = parser.parse_args()

    try:
        return run(args)
    except StopImport:
        print(f"\nОстановлено. Созданное записано в {args.state}; "
              "повторный запуск продолжит с этого места.")
        return 0
    except JiraError as error:
        print(f"\nОшибка Jira: {error}", file=sys.stderr)
        return 1
    except FileNotFoundError as error:
        print(f"\nФайл не найден: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

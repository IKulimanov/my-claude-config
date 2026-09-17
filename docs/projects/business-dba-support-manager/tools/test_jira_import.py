"""Тесты парсера плана. Сеть не используется: проверяется только разбор 02-plan.md."""

import tempfile
import unittest
from pathlib import Path

from jira_import import (
    JiraError,
    Stage,
    load_env_file,
    parse_answer,
    parse_plan,
    render_description,
    render_stage_description,
    resolve_project,
    select_stages,
)

PLAN = Path(__file__).resolve().parent.parent / "02-plan.md"

# этапы, у которых есть подзадача «Анализ»: там, где нужно архитектурное решение (ADR)
STAGES_WITH_ANALYSIS = [3, 4, 8]


class ParsePlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stages = parse_plan(PLAN.read_text(encoding="utf-8"))
        cls.by_number = {s.number: s for s in cls.stages}
        cls.subtasks = {t.number: t for s in cls.stages for t in s.subtasks}

    def test_разобраны_все_этапы(self):
        self.assertEqual([s.number for s in self.stages], list(range(1, 10)))
        self.assertEqual(self.by_number[1].title, "Основание — контекст «конфигурация»")
        self.assertTrue(self.by_number[1].why.startswith("Система конфигурируется флоу"))
        self.assertIn("Валидные версии флоу", self.by_number[1].result)

    def test_разобраны_все_подзадачи(self):
        self.assertEqual(len(self.subtasks), 45)

    def test_поля_подзадачи(self):
        task = self.subtasks["1.1"]
        self.assertEqual(task.components, ["Core"])
        self.assertEqual(task.title, "Каркас: БД системы, миграции и приложение Core")
        self.assertEqual(task.hours, 6)
        self.assertFalse(task.timeboxed)
        self.assertIn("развернуть БД системы", task.what)
        self.assertEqual(len(task.criteria), 6)
        self.assertEqual(task.depends_on, [])

    def test_несколько_компонентов(self):
        self.assertEqual(self.subtasks["8.4"].components, ["Core", "Executor"])
        self.assertEqual(self.subtasks["3.1"].components, ["Core", "Executor"])

    def test_зависимости_от_подзадач(self):
        self.assertEqual(self.subtasks["3.5"].depends_on, ["2.3", "3.2"])
        self.assertEqual(self.subtasks["5.3"].depends_on, ["3.4", "5.2"])
        self.assertEqual(self.subtasks["4.2"].depends_on, ["4.1", "2.4", "2.5", "1.3"])

    def test_зависимости_от_этапов(self):
        self.assertEqual(self.subtasks["8.3"].depends_on, ["8.1", "этап 3"])
        self.assertEqual(
            self.subtasks["9.6"].depends_on,
            ["этап 1", "этап 2", "этап 3", "этап 4", "этап 5", "этап 6", "этап 8",
             "9.1", "9.2", "9.3", "9.4", "9.5"],
        )

    def test_таймбокс_анализа(self):
        task = self.subtasks["3.1"]
        self.assertEqual(task.hours, 7)
        self.assertTrue(task.timeboxed)

    def test_закрытые_вопросы_подзадачи(self):
        # все вопросы этапа 7 закрыты решениями заказчика
        task = self.subtasks["7.1"]
        self.assertEqual(task.open_questions, [])

    def test_анализ_только_там_где_нужен_adr(self):
        with_analysis = sorted(
            s.number for s in self.stages
            if any(t.title.startswith("Анализ") for t in s.subtasks)
        )
        self.assertEqual(with_analysis, STAGES_WITH_ANALYSIS)
        self.assertIn("ADR-002", self.subtasks["3.1"].what)
        self.assertIn("ADR-001", self.subtasks["3.1"].what)

    def test_этап_без_вопросов_не_имеет_анализа(self):
        self.assertEqual(self.by_number[9].open_questions, [])
        self.assertFalse(any(t.title.startswith("Анализ") for t in self.by_number[9].subtasks))

    def test_вопросы_подзадач_видны_в_этапе(self):
        # правило: у каждого вопроса подзадачи есть свой пункт в сводке этапа,
        # адресованный её номером; формулировка в сводке может быть короче
        for stage in self.stages:
            for task in stage.subtasks:
                if not task.open_questions:
                    continue
                в_сводке = [q for q in stage.open_questions if q.startswith(f"{task.number} —")]
                self.assertGreaterEqual(
                    len(в_сводке), len(task.open_questions),
                    f"в сводке этапа {stage.number} не хватает вопросов подзадачи {task.number}",
                )

    def test_описание_этапа_содержит_вопросы(self):
        text = render_stage_description(self.by_number[4])
        self.assertIn("h3. Открытые вопросы", text)
        self.assertIn("4.1 — ADR-006", text)
        self.assertIn("h3. Состав", text)

    def test_описание_этапа_без_вопросов(self):
        self.assertNotIn("Открытые вопросы", render_stage_description(self.by_number[9]))

    def test_описание_подзадачи(self):
        text = render_description(self.subtasks["7.1"])
        self.assertIn("h3. Что сделать", text)
        self.assertIn("h3. Критерии приёмки", text)
        self.assertIn("* Дано: задача ждёт дольше порога.", text)
        self.assertNotIn("h3. Открытые вопросы", text)
        # незакрытый вопрос остался у 1.1 — состав модулей проекта
        с_вопросом = render_description(self.subtasks["1.1"])
        self.assertIn("h3. Открытые вопросы", с_вопросом)
        self.assertIn("* Состав модулей проекта", с_вопросом)

    def test_описание_начинается_с_заглавной(self):
        # в плане текст идёт после «Что сделать:» со строчной буквы
        self.assertTrue(self.subtasks["7.1"].what.startswith("регламентные процессы"))
        text = render_description(self.subtasks["7.1"])
        self.assertIn("h3. Что сделать\nРегламентные процессы", text)

    def test_сумма_оценок(self):
        self.assertEqual(sum(t.hours for t in self.subtasks.values()), 275)


class ResolveProjectTest(unittest.TestCase):
    def test_по_умолчанию_проект_эпика(self):
        self.assertEqual(resolve_project("IT", None, "customfield_10001"), "IT")

    def test_переопределение_другим_проектом(self):
        self.assertEqual(resolve_project("IT", "ORSP", "customfield_10001"), "ORSP")

    def test_чужой_проект_без_epic_link_ошибка(self):
        # без поля Epic Link задача этапа привязывается через parent,
        # а parent работает только внутри проекта эпика
        with self.assertRaises(JiraError):
            resolve_project("IT", "ORSP", None)

    def test_совпадающий_проект_без_epic_link_допустим(self):
        self.assertEqual(resolve_project("IT", "IT", None), "IT")


class SelectStagesTest(unittest.TestCase):
    def setUp(self):
        self.stages = [Stage(number=n, title=f"Этап {n}") for n in (1, 2, 3)]

    def test_без_фильтра_все_этапы(self):
        self.assertEqual(select_stages(self.stages, None), self.stages)

    def test_только_указанные(self):
        self.assertEqual([s.number for s in select_stages(self.stages, [1, 3])], [1, 3])

    def test_несуществующий_этап_ошибка(self):
        with self.assertRaises(ValueError):
            select_stages(self.stages, [1, 7])


class ParseAnswerTest(unittest.TestCase):
    def test_согласие(self):
        for raw in ("", "y", "Y", "д", "да", "yes"):
            self.assertEqual(parse_answer(raw), "yes", raw)

    def test_пропуск(self):
        for raw in ("n", "N", "н", "нет", "no"):
            self.assertEqual(parse_answer(raw), "no", raw)

    def test_все_без_вопросов(self):
        for raw in ("a", "в", "все", "всё", "all"):
            self.assertEqual(parse_answer(raw), "all", raw)

    def test_остановка(self):
        for raw in ("q", "quit", "стоп", "выход"):
            self.assertEqual(parse_answer(raw), "stop", raw)

    def test_непонятный_ответ(self):
        self.assertEqual(parse_answer("может быть"), "unknown")


class LoadEnvFileTest(unittest.TestCase):
    def _load(self, text: str, environ: dict | None = None) -> dict:
        environ = {} if environ is None else environ
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / ".env"
            path.write_text(text, encoding="utf-8")
            load_env_file(path, environ)
        return environ

    def test_пары_ключ_значение(self):
        env = self._load("JIRA_URL=https://jira.local\nJIRA_TOKEN=abc\n")
        self.assertEqual(env, {"JIRA_URL": "https://jira.local", "JIRA_TOKEN": "abc"})

    def test_комментарии_и_пустые_строки(self):
        env = self._load("# личный токен\n\nJIRA_TOKEN=abc\n")
        self.assertEqual(env, {"JIRA_TOKEN": "abc"})

    def test_кавычки_и_export(self):
        env = self._load('export JIRA_URL="https://jira.local"\n' + "JIRA_USER='ivan'\n")
        self.assertEqual(env, {"JIRA_URL": "https://jira.local", "JIRA_USER": "ivan"})

    def test_не_перекрывает_заданное_окружение(self):
        env = self._load("JIRA_TOKEN=из_файла", {"JIRA_TOKEN": "из_окружения"})
        self.assertEqual(env["JIRA_TOKEN"], "из_окружения")


if __name__ == "__main__":
    unittest.main()

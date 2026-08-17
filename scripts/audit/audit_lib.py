"""Общая логика аудита использования Claude Code: классификация промтов и вспомогательные функции.

Классификатор — правила по ключевым словам (RU/EN). Он грубый по определению; отчёт обязан
показывать долю «не классифицировано» и не выдавать оценки за факты. Категории и порядок
приоритета описаны в TASK_RULES.
"""

from __future__ import annotations

import datetime as dt
import re
from zoneinfo import ZoneInfo

TZ_LOCAL = ZoneInfo("Asia/Bishkek")  # UTC+6, без перехода на летнее время

# Окно аудита по умолчанию: последние 9 ISO-недель (Пн–Вс) включая текущую. Переопределяется
# из extract.py (--start/--end/--weeks) через set_window(); report_phase1 берёт окно из meta.json.
AUDIT_START = dt.datetime(2026, 6, 15, tzinfo=dt.timezone.utc)
AUDIT_END = dt.datetime(2026, 8, 17, tzinfo=dt.timezone.utc)  # исключительно


def default_window(weeks: int = 9, today: dt.date | None = None) -> tuple[dt.datetime, dt.datetime]:
    """[понедельник (weeks-1) недель назад; следующий понедельник) в UTC."""
    today = today or dt.datetime.now(dt.timezone.utc).date()
    monday = today - dt.timedelta(days=today.weekday())
    start = monday - dt.timedelta(weeks=weeks - 1)
    end = monday + dt.timedelta(days=7)
    return (dt.datetime.combine(start, dt.time(), tzinfo=dt.timezone.utc),
            dt.datetime.combine(end, dt.time(), tzinfo=dt.timezone.utc))


def set_window(start: dt.datetime, end: dt.datetime) -> None:
    global AUDIT_START, AUDIT_END
    AUDIT_START, AUDIT_END = start, end


def parse_ts(s: str) -> dt.datetime:
    """ISO-8601 из логов ('2026-05-17T18:40:38Z' или с миллисекундами)."""
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return dt.datetime.fromisoformat(s)


def ms_to_dt(ms: int) -> dt.datetime:
    return dt.datetime.fromtimestamp(ms / 1000, tz=dt.timezone.utc)


def iso_week(d: dt.datetime) -> str:
    y, w, _ = d.astimezone(TZ_LOCAL).isocalendar()
    return f"{y}-W{w:02d}"


def local(d: dt.datetime) -> dt.datetime:
    return d.astimezone(TZ_LOCAL)


def in_window(d: dt.datetime) -> bool:
    return AUDIT_START <= d < AUDIT_END


def project_short(path_or_name: str) -> str:
    """Короткое имя проекта из cwd или из имени директории projects/."""
    if not path_or_name:
        return "?"
    p = path_or_name
    if p.startswith("-Users-ivankulimanov-"):
        p = p[len("-Users-ivankulimanov-"):]
        if p.startswith("docs-lifeOS"):
            return "lifeOS"
        for pref in ("dev-work-java-", "dev-work-js-", "dev-personal-", "dev-work-", "dev-"):
            if p.startswith(pref):
                return p[len(pref):].lower()
        return p.lower()
    if "/docs/lifeOS" in p:
        return "lifeOS"
    return p.rstrip("/").split("/")[-1].lower()


def project_group(short: str, cwd: str = "") -> str:
    """work / personal / meta (конфиг Claude) / pkm (личная система заметок)."""
    if short in ("my-claude-config", "lifeos-config"):
        return "meta"
    if short.startswith("lifeOS") or "/docs/" in cwd:
        return "pkm"
    if "/dev/work/" in cwd:
        return "work"
    if "/dev/personal/" in cwd:
        return "personal"
    return "other"


# ---------- Классификация «вид взаимодействия» (не тип задачи) ----------

_CONTINUE = re.compile(
    r"^\s*((да|ну|ок|окей|хорошо|отлично|супер)[,.!\s]*)?"
    r"(да|ок|окей|ok|okay|yes|y|go|го|давай( ещё| еще| дальше)?|дальше|продолжай|продолжи|продолжим|поехали|делай|"
    r"готово|принято|согласен|подтверждаю|approve|apply|применяй|запускай|выполняй|начинай|"
    r"вариант\s*\d|\d(\s*[,и]\s*\d)*|[123]\)|1\.|хорошо|отлично|супер|спасибо|thanks|thx|"
    r"что (осталось|дальше|ещё|еще)|какой (следующий |будет )?(шаг|этап)[^?]{0,20}|на ч[её]м (мы )?остановились|статус|где мы|"
    r"вс[её] готово[^?]{0,30}|есть (ещё|еще) (шаги|что-то)[^?]{0,20})\W*$",
    re.I,
)
_LANG_FIX = re.compile(r"^.{0,25}(на русском|по-русски|на русский|in english).{0,25}$", re.I)
_CORRECTION = re.compile(
    r"(не так|неверно|неправильно|не работает|не сработал|опять|снова|всё ещё|все еще|все ещё|"
    r"откати|верни как|я же (просил|говорил|писал)|я просил|не надо|не нужно было|не то|"
    r"зачем ты|почему ты|ты не |ты забыл|ты сломал|ты удалил|плохо|фигня|бред|ерунд|"
    r"неправильн|ошибся|ошибка в твоём|это не то|нет[,.!]|wrong|still (not|fails|broken)|"
    r"doesn'?t work|revert|undo|не компилир|тесты (падают|упали|не проходят)|падает|"
    r"сломал|поломал|исправь (это|то|свою|ошибк)|переделай|не помогло|не сохранил|пропустил|"
    r"нет,|нет\.|нет —)",
    re.I,
)

INTERACTION_KINDS = ("new-task", "correction", "answer", "continue")


def interaction_kind(text: str, prev_assistant_asks: bool = False) -> str:
    """Вид реплики пользователя внутри сессии.

    - continue: короткое подтверждение/«дальше»;
    - correction: сигнал переделки/недовольства результатом;
    - answer: короткий ответ на вопрос агента (предыдущее сообщение агента заканчивалось «?»);
    - new-task: всё остальное (новая постановка).
    """
    t = text.strip()
    if t.startswith("/") or t.startswith("<command-message>"):
        return "new-task"
    if _CONTINUE.match(t):
        return "continue"
    if _LANG_FIX.match(t):
        return "correction"
    if _CORRECTION.search(t) and len(t) < 600:
        return "correction"
    if prev_assistant_asks and len(t) < 300:
        return "answer"
    return "new-task"


# ---------- Классификация «тип задачи» ----------

# Порядок = приоритет. Первое совпадение выигрывает.
TASK_RULES: list[tuple[str, re.Pattern]] = [
    ("review", re.compile(r"(^/review|^/review-mr|^/convention-check|\bревью\b|\breview\b|merge request|"
                          r"\bmr\b|пул.?реквест|pull request|код.?ревью|проверь (код|изменения|pr|mr))", re.I)),
    ("test", re.compile(r"(^/test\b|напиши тест|покрой тест|добавь тест|юнит.?тест|unit.?test|тест(ы|ов|ами)? (на|для)|"
                        r"testcontainers|тестов не хватает|write tests?)", re.I)),
    ("sonar-fix", re.compile(r"(sonarqube|sonarlint|\bsonar\b.{0,20}(замечани|issue|говорит|ругается|пишет)|^fix this)", re.I)),
    ("debug", re.compile(r"(^/debug|^/fix|\bбаг\b|\bbug\b|ошибк|падает|упал|не работает|не запускается|исключени|"
                         r"exception|stack.?trace|npe\b|nullpointer|почини|исправь|fix\b|failing|fails|"
                         r"не проходит|не проходят|разберись почему|найди причину|почему (не|падает)|500|"
                         r"error|traceback|сломал)", re.I)),
    ("planning-arch", re.compile(r"(^/plan|^/arch|^/task\b|^/feature|архитектур|спроектируй|проектирован|дизайн (систем|модул|решени)|"
                                 r"составь план|план (реализации|внедрени|работ)|предложи (вариант|подход|решени)|"
                                 r"как лучше (сделать|организовать|спроектировать|реализовать|построить)|какой подход|"
                                 r"техническ(ое|ий) (задани|решени)|\bтз\b|требовани|acceptance|критерии приемки|"
                                 r"roadmap|дорожн(ую|ая) карт|стратеги)", re.I)),
    ("sql", re.compile(r"(\bsql\b|\bselect\b|\bjoin\b|liquibase|flyway|миграци|changelog|changeset|таблиц|индекс|"
                       r"схем[уа] (бд|базы|данных)|clickhouse|postgres|oracle|\bjpa\b|entity|сущност|запрос к базе|"
                       r"хранимк|процедур|\bddl\b|\bdml\b)", re.I)),
    ("config-yaml", re.compile(r"(\byaml\b|\byml\b|helm|k8s|kubernetes|kubectl|docker|dockerfile|compose|gitlab.?ci|"
                               r"\.gitlab|pipeline|пайплайн|terraform|application\.(yml|properties)|"
                               r"\bconfig\b|конфиг|properties|deployment|ingress|values\.yaml|nginx|env\b|"
                               r"переменн(ые|ая) окружени|секрет|vault|launchd|plist|настрой (окружени|сборк))", re.I)),
    ("docs", re.compile(r"(документац|readme|javadoc|changelog|опиши (проект|модул|сервис|api|как)|описание (проекта|api|сервиса)|"
                        r"^/jira|jira|таск(у|и) в jira|составь (описание|инструкци)|инструкци|конспект|заметк|"
                        r"\bdocs?\b|документ|статью|презентац|отчёт|отчет|резюме|summary|адр\b|\badr\b|diagram|диаграмм|"
                        r"комментари(и|ев) к|opsgenie|confluence|wiki)", re.I)),
    ("refactor", re.compile(r"(рефактор|refactor|переимен|rename|вынеси|выдели|упрости|simplif|оптимизир|optimi[sz]|"
                            r"cleanup|почисти|приведи в порядок|избавься|убери дубл|дублирован|переструктур|"
                            r"перенеси|раздели|объедини|унифицир|консолидир|разбей (класс|файл|метод)|"
                            r"legacy|тех.?долг|technical debt|deprecated|sonar|magic number|code smell|качеств[оа] кода)", re.I)),
    ("explain-code", re.compile(r"(^/explain|^/onboard|объясни|поясни|расскажи|как (устроен|работает|реализован|это работает)|"
                                r"что делает|что здесь|разберись (в|с|как)|изучи (проект|код|репозитор|модул|сервис)|"
                                r"проанализируй (проект|код|репозитор|модул|сервис|структур)|анализ (проекта|кода)|"
                                r"проведи анализ|explain|walk me through|где (находится|лежит|используется)|"
                                r"найди (где|все места|использовани)|покажи (где|как)|в чём разница|в чем разница|"
                                r"понять|разобраться)", re.I)),
    ("research", re.compile(r"(исследуй|исследовани|ресёрч|ресерч|research|сравни|сравнени|comparison|варианты (решени|библиот|инструмент)|"
                            r"предложи (вариант|имя|имена|назван|username|альтернатив|несколько)|альтернатив|"
                            r"какие есть (варианты|библиотек|инструмент|подход)|что (лучше|выбрать|использовать)|"
                            r"best.?practi|лучшие практики|подбери|порекомендуй|посоветуй|рекомендаци|"
                            r"обзор|найди (информаци|в интернете|статьи|источник)|поищи|загугли|web.?search|"
                            r"мнение|оцени (подход|идею|решение)|критик|плюсы и минусы|trade.?off)", re.I)),
    ("boilerplate", re.compile(r"(boilerplate|шаблон|скаффолд|scaffold|каркас|заготовк|по (примеру|аналогии|образцу)|"
                               r"аналогично (как|с)|такой же как|скопируй|сгенерируй|generate|\bdto\b|mapper|маппер|"
                               r"getter|setter|builder|конструктор|enum|стаб|stub|mock|заглушк|фикстур|fixture)", re.I)),
    ("git-ops", re.compile(r"(закоммит|коммит|commit|push|запуш|\bветк|branch|rebase|merge\b|мердж|cherry.?pick|"
                           r"\bgit\b|стеш|stash|тег|tag\b|релиз|release|версию подними|bump)", re.I)),
    ("new-code", re.compile(r"(реализуй|реализ|добавь|добав|сделай|напиши|написать|создай|созда|implement|"
                            r"\badd\b|create|build|внедри|интегрируй|подключи|поддержк|support|endpoint|ручк|"
                            r"эндпоинт|контроллер|controller|сервис|service|метод|method|функци|function|фич|feature|"
                            r"компонент|component|страниц|page|форм|кнопк|button|обработчик|handler|listener|"
                            r"consumer|producer|kafka|scheduler|джоб|job|крон|cron|валидаци|validation|"
                            r"логирован|logging|метрик|metric|кэш|cache|retry|ретра|таймаут|timeout)", re.I)),
    ("google-replace", re.compile(r"(^(как|что|где|какой|какая|какие|можно ли|есть ли|почему|чем|сколько|подскажи|напомни|"
                                  r"how|what|why|which|is there|can i)\b.{0,160}\?\s*$)", re.I | re.S)),
]

TASK_CATEGORIES = [name for name, _ in TASK_RULES] + ["other"]
_RULE_BY_NAME = dict(TASK_RULES)


_SHORT_QUESTION = re.compile(
    r"^\s*(а |и |ну )?(как|что|где|какой|какая|какие|каким|можно ли|есть ли|почему|чем|сколько|подскажи|напомни|"
    r"зачем|откуда|куда|кто|когда|нужно ли|стоит ли|правильно ли|не (нужно|стоит|лучше) ли|"
    r"how|what|why|which|is there|can i|should i)\b", re.I)


def classify_task(text: str, project_grp: str = "") -> str:
    t = text.strip()
    if project_grp == "meta":
        return "config-tuning"
    if project_grp == "pkm":
        return "pkm-notes"
    sc = slash_command(t)
    if len(t) < 25 and not sc:
        return "other"
    head = t[:1500]
    if not sc and len(t) < 200 and _SHORT_QUESTION.match(t):
        # короткий вопрос без постановки задачи — «вместо гугла» (при этом «как лучше спроектировать» уходит в planning)
        if not _RULE_BY_NAME['planning-arch'].search(head):
            return "google-replace"
    for name, rx in TASK_RULES:
        if rx.search(head):
            return name
    return "other"


# ---------- Делегирование, разрушающее навык ----------

SKILL_RISK_RULES: list[tuple[str, re.Pattern]] = [
    ("schema-design", re.compile(r"(спроектируй|продумай|предложи|разработай|создай|опиши)[^.\n]{0,60}(схем|таблиц|модель данных|entity|сущност|структур[уа] (бд|базы|данных|таблиц))|"
                                 r"(какие|какую|каких)[^.\n]{0,30}(поля|таблиц|индекс)|"
                                 r"(схем[уа]|модель) (бд|базы данных|данных)[^.\n]{0,40}(спроектир|придума|предлож|нужн)|"
                                 r"(напиши|создай|сделай)[^.\n]{0,40}(liquibase|flyway|миграци)", re.I)),
    ("requirements", re.compile(r"(сформулируй|напиши|составь|подготовь|опиши|сделай)[^.\n]{0,50}(тз|техническое задание|требовани|acceptance|критерии|"
                                r"постановк|описание задачи|user story|задачу в jira|jira|таск)|^/jira", re.I)),
    ("analysis-first", re.compile(r"(проведи (дополнительный |полный |детальный )?анализ|проанализируй|сделай анализ|analy[sz]e)", re.I)),
    ("unfamiliar-code", re.compile(r"(^/onboard|^/explain|изучи (проект|код|репозитор|модул|сервис)|разберись (в|с|как)|как (устроен|работает|реализован)|"
                                   r"объясни (как|что|зачем|почему)|что делает|где (находится|лежит|используется|обрабатывается)|"
                                   r"найди (где|все места|использовани)|помоги (мне )?понять|помоги разобраться)", re.I)),
    ("architecture-decision", re.compile(r"(^/arch|^/plan|архитектур|спроектируй|как лучше (сделать|организовать|спроектировать|реализовать|построить)|"
                                         r"какой подход|предложи (вариант|подход|решени|архитектур)|паттерн|дизайн (систем|модул|решени)|"
                                         r"варианты (реализации|решения)|trade.?off|плюсы и минусы)", re.I)),
    ("debug-root-cause", re.compile(r"(^/debug|разберись почему|найди причину|почему (не|падает|возника|происходит)|в чём (причина|проблема)|"
                                    r"в чем (причина|проблема)|stack.?trace|traceback|exception|исключени|не работает[^.\n]{0,40}(почему|разберись))", re.I)),
    ("sql-writing", re.compile(r"(напиши|составь|сделай|сформируй)[^.\n]{0,30}(sql|запрос|select|выборк)|sql.?запрос", re.I)),
    ("google-replace", re.compile(r"(^(как|что такое|где|какой|какая|какие|можно ли|есть ли|чем отличается|сколько|подскажи|напомни|"
                                  r"how (do|to|can)|what is|which)\b.{0,160}\?\s*$)", re.I | re.S)),
]

SKILL_RISK_CATEGORIES = [name for name, _ in SKILL_RISK_RULES]


def classify_skill_risk(text: str) -> list[str]:
    head = text.strip()[:1500]
    return [name for name, rx in SKILL_RISK_RULES if rx.search(head)]


# ---------- Метрика rule 08: есть ли в постановке своя гипотеза/вариант ----------

_HYPOTHESIS = re.compile(
    r"(гипотез|думаю,? что|мне кажется,? (что|причина|дело)|подозреваю|скорее всего|предполагаю|"
    r"мой вариант|я бы (сделал|предложил|пошёл|пошел)|моя (идея|версия)|причина (в|—|-) |дело в том|"
    r"может (быть )?(проблема|дело|причина|это|из-за|потому)|возможно,? (что|это|дело|причина|из-за)|наверное|похоже,? что|видимо|"
    r"предлагаю (сделать|так|вариант|использовать)|я думаю|кажется,? (что|это|дело|причина|проблема)|"
    r"i think|my guess|probably because|hypothesis)", re.I)


def has_hypothesis(text: str) -> bool:
    return bool(_HYPOTHESIS.search(text[:1500]))


# ---------- Прочее ----------

_SLASH = re.compile(r"^\s*/([a-z][a-z0-9-]*)", re.I)
_CMD_MSG = re.compile(r"<command-name>/([a-z0-9-]+)</command-name>", re.I)
_CMD_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)


def slash_command(text: str) -> str | None:
    m = _CMD_MSG.search(text)
    if m:
        return m.group(1).lower()
    m = _SLASH.match(text)
    return m.group(1).lower() if m else None


def command_args(text: str) -> str:
    m = _CMD_ARGS.search(text)
    return m.group(1).strip() if m else ""


def cyrillic_share(text: str) -> float:
    letters = [c for c in text if c.isalpha()]
    if not letters:
        return 0.0
    cyr = sum(1 for c in letters if "Ѐ" <= c <= "ӿ")
    return cyr / len(letters)


def hour_bucket(d: dt.datetime) -> str:
    h = local(d).hour
    if 6 <= h < 10:
        return "утро 06–10"
    if 10 <= h < 14:
        return "день 10–14"
    if 14 <= h < 18:
        return "день 14–18"
    if 18 <= h < 22:
        return "вечер 18–22"
    return "ночь 22–06"


def percentile(values, p: float):
    if not values:
        return None
    s = sorted(values)
    k = (len(s) - 1) * p
    f = int(k)
    c = min(f + 1, len(s) - 1)
    return s[f] + (s[c] - s[f]) * (k - f)

#!/usr/bin/env python3
"""Считает метрики фазы 1 из <out>/data/*.json и пишет <out>/data/metrics.json + <out>/data/tables.md.

Отчёт 01-usage-audit.md пишется руками на основе tables.md (числа — только отсюда).
Запуск: python3 scripts/audit/report_phase1.py [--out docs/audit-2026-08]
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(__file__))
from audit_lib import (  # noqa: E402
    SKILL_RISK_CATEGORIES,
    TASK_CATEGORIES,
    TZ_LOCAL,
    parse_ts,
    percentile,
)

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _installed(sub: str, pattern: str) -> list[str]:
    import glob as _g
    names = []
    for f in sorted(_g.glob(os.path.join(REPO, sub, pattern))):
        n = os.path.basename(f)
        names.append(os.path.basename(os.path.dirname(f)) if n == "SKILL.md" else n[:-3])
    return names


INSTALLED_COMMANDS = _installed("commands", "*.md")
INSTALLED_AGENTS = _installed("agents", "*.md")
INSTALLED_SKILLS = _installed("skills", "*/SKILL.md")
BUILTIN_COMMANDS = {"compact", "context", "model", "output-style", "memory", "doctor", "mcp", "login", "users",
                    "clear", "help", "config", "cost", "status", "init", "permissions", "hooks", "rate-limit-options",
                    "resume", "exit", "quit", "add-dir", "agents", "skills", "plugin", "vim", "terminal-setup",
                    "release-notes", "bug", "pr-comments", "install-github-app", "rewind", "usage", "stats",
                    "statusline", "keybindings", "chrome", "desktop", "ide", "export", "logout", "theme", "voice"}

W = []  # weeks in window (filled in main)


def wk_table(rows_by_week: dict, cols: list[str], title: str) -> str:
    out = [f"**{title}**", "", "| Неделя | " + " | ".join(cols) + " |", "|---|" + "---:|" * len(cols)]
    for w in W:
        r = rows_by_week.get(w, {})
        out.append(f"| {w} | " + " | ".join(str(r.get(c, 0)) for c in cols) + " |")
    return "\n".join(out) + "\n"


def fmt_k(n) -> str:
    n = n or 0
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1000:
        return f"{n/1000:.0f}k"
    return str(n)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="каталог аудита (по умолчанию docs/audit-<ГГГГ-ММ> текущего месяца)")
    args = ap.parse_args()
    out = args.out or f"docs/audit-{dt.datetime.now(dt.timezone.utc):%Y-%m}"
    d = os.path.join(out, "data")
    P = json.load(open(os.path.join(d, "prompts.json")))
    TOK = json.load(open(os.path.join(d, "tokens.json")))["deltas"]
    TOOLS = json.load(open(os.path.join(d, "tools.json")))
    LOGS = json.load(open(os.path.join(d, "hook_logs.json")))
    TR = json.load(open(os.path.join(d, "transcripts.json")))
    META = json.load(open(os.path.join(d, "meta.json")))

    PW = [r for r in P if r["in_window"]]
    global W
    W[:] = sorted({r["week"] for r in PW})
    M: dict = {"weeks": W, "meta": META}
    T: list[str] = []  # markdown fragments

    # ------------------------------------------------------------------ 1. объём
    by_week = collections.defaultdict(lambda: collections.Counter())
    sess_week = collections.defaultdict(set)
    days_week = collections.defaultdict(set)
    for r in PW:
        by_week[r["week"]]["prompts"] += 1
        sess_week[r["week"]].add(r["session"])
        days_week[r["week"]].add(r["ts_local"][:10])
    tok_week = collections.defaultdict(lambda: collections.Counter())
    for t in TOK:
        if t["in_window"]:
            tok_week[t["week"]]["out"] += t["output_tokens"]
            tok_week[t["week"]]["in"] += t["input_tokens"]
            tok_week[t["week"]]["cache_read"] += t["cache_read"]
            tok_week[t["week"]]["cache_write"] += t["cache_write"]
            tok_week[t["week"]]["turns"] += t["turns"]
    tools_week = collections.Counter(c["week"] for c in TOOLS["calls"] if c["in_window"])
    fails_week = collections.Counter(c["week"] for c in TOOLS["fails"] if c["in_window"])
    sub_week = collections.Counter(s["week"] for s in LOGS["subagents"] if s["in_window"] and s.get("event") == "SubagentStop")
    vol = {}
    for w in W:
        vol[w] = {
            "prompts": by_week[w]["prompts"], "sessions": len(sess_week[w]), "active_days": len(days_week[w]),
            "tokens_out": tok_week[w]["out"], "tokens_in": tok_week[w]["in"],
            "cache_read": tok_week[w]["cache_read"], "cache_write": tok_week[w]["cache_write"],
            "turns": tok_week[w]["turns"], "tool_calls": tools_week[w], "tool_fails": fails_week[w],
            "subagent_stops": sub_week[w],
        }
    M["volume_by_week"] = vol
    T.append(wk_table({w: {**v, "tokens_out": fmt_k(v["tokens_out"]), "cache_read": fmt_k(v["cache_read"]),
                           "cache_write": fmt_k(v["cache_write"]), "tokens_in": fmt_k(v["tokens_in"])} for w, v in vol.items()},
                      ["prompts", "sessions", "active_days", "turns", "tokens_out", "tokens_in", "cache_read", "cache_write",
                       "tool_calls", "tool_fails", "subagent_stops"], "Объём по неделям (окно аудита)"))
    tot = {k: sum(v[k] for v in vol.values()) for k in ("prompts", "tokens_out", "tokens_in", "cache_read", "cache_write", "turns", "tool_calls", "tool_fails", "subagent_stops")}
    tot["sessions"] = len({r["session"] for r in PW})
    tot["active_days"] = len({r["ts_local"][:10] for r in PW})
    _ws = dt.datetime.fromisoformat(META["window_start"]).date()
    _we = dt.datetime.fromisoformat(META["window_end_excl"]).date()
    tot["calendar_days"] = min((_we - _ws).days, (dt.datetime.now(dt.timezone.utc).date() - _ws).days + 1)
    M["totals"] = tot
    T.append("Итого за окно: " + ", ".join(f"{k}={fmt_k(v) if 'token' in k or 'cache' in k else v}" for k, v in tot.items()) + "\n")

    # baseline: предыдущее окно той же длины (до 2026-05-17 только CLI, потом хуки)
    _len = (_we - _ws).days
    _bs, _be = (_ws - dt.timedelta(days=_len)).isoformat(), _ws.isoformat()
    base = [r for r in P if _bs <= r["ts"][:10] < _be]
    M["baseline_prev"] = {"from": _bs, "to_excl": _be, "prompts": len(base), "sessions": len({r["session"] for r in base}),
                          "note": "до 2026-05-17 только CLI (history.jsonl), далее CLI+Desktop"}
    T.append(f"Baseline предыдущее окно ({_bs}..{_be}): prompts={len(base)}, sessions={len({r['session'] for r in base})} (до 2026-05-17 только CLI)\n")

    # по группам и проектам
    grp = collections.Counter(r["group"] for r in PW)
    grp_sess = collections.defaultdict(set)
    for r in PW:
        grp_sess[r["group"]].add(r["session"])
    proj = collections.Counter(r["project"] for r in PW)
    proj_grp = {r["project"]: r["group"] for r in PW}
    tok_proj = collections.Counter()
    for t in TOK:
        if t["in_window"]:
            tok_proj[t["project"]] += t["output_tokens"]
    tok_grp = collections.Counter()
    for t in TOK:
        if t["in_window"]:
            tok_grp[t["group"]] += t["output_tokens"]
    M["by_group"] = {g: {"prompts": grp[g], "sessions": len(grp_sess[g]), "tokens_out": tok_grp[g]} for g in grp}
    tgw = collections.defaultdict(collections.Counter)
    pgw = collections.defaultdict(collections.Counter)
    for t in TOK:
        if t["in_window"]:
            tgw[t["week"]][t["group"]] += t["output_tokens"]
    for r in PW:
        pgw[r["week"]][r["group"]] += 1
    M["tokens_by_week_group"] = {w: dict(tgw[w]) for w in W}
    M["prompts_by_week_group"] = {w: dict(pgw[w]) for w in W}
    T.append(wk_table({w: {g: fmt_k(tgw[w].get(g, 0)) for g in ("work", "personal", "pkm", "meta")} for w in W}, ["work", "personal", "pkm", "meta"], "tokens_out по неделям и группам"))
    T.append(wk_table({w: {g: pgw[w].get(g, 0) for g in ("work", "personal", "pkm", "meta")} for w in W}, ["work", "personal", "pkm", "meta"], "prompts по неделям и группам"))
    M["by_project"] = [{"project": p, "group": proj_grp[p], "prompts": c, "tokens_out": tok_proj.get(p, 0)} for p, c in proj.most_common()]
    T.append("**По группам проектов**\n\n| Группа | prompts | % | sessions | tokens_out |\n|---|---:|---:|---:|---:|\n" +
             "\n".join(f"| {g} | {grp[g]} | {grp[g]/len(PW)*100:.0f}% | {len(grp_sess[g])} | {fmt_k(tok_grp[g])} |" for g in sorted(grp, key=lambda g: -grp[g])) + "\n")
    T.append("**Топ проектов**\n\n| Проект | группа | prompts | tokens_out |\n|---|---|---:|---:|\n" +
             "\n".join(f"| {p} | {proj_grp[p]} | {c} | {fmt_k(tok_proj.get(p,0))} |" for p, c in proj.most_common(15)) + "\n")

    # ------------------------------------------------------------------ 2. типы задач
    NT = [r for r in PW if r["kind"] == "new-task"]
    kinds = collections.Counter(r["kind"] for r in PW)
    M["kinds"] = dict(kinds)
    tasks = collections.Counter(r["task"] for r in NT)
    tasks_work = collections.Counter(r["task"] for r in NT if r["group"] == "work")
    tasks_pers = collections.Counter(r["task"] for r in NT if r["group"] == "personal")
    M["tasks"] = {"all": dict(tasks), "work": dict(tasks_work), "personal": dict(tasks_pers), "n_new_task": len(NT)}
    order = sorted(tasks, key=lambda k: -tasks[k])
    T.append(f"**Вид реплик (окно):** {dict(kinds)}; new-task={len(NT)}\n")
    T.append("**Типы задач (только new-task)**\n\n| Категория | все | % | work | personal |\n|---|---:|---:|---:|---:|\n" +
             "\n".join(f"| {k} | {tasks[k]} | {tasks[k]/len(NT)*100:.0f}% | {tasks_work.get(k,0)} | {tasks_pers.get(k,0)} |" for k in order) + "\n")
    # weekly task mix (work only, top categories)
    tw = collections.defaultdict(collections.Counter)
    for r in NT:
        tw[r["week"]][r["task"]] += 1
    M["tasks_by_week"] = {w: dict(tw[w]) for w in W}
    top_cats = [k for k in order if k not in ("other", "pkm-notes")][:8]
    T.append(wk_table({w: {c: tw[w].get(c, 0) for c in top_cats} for w in W}, top_cats, "Типы задач по неделям (new-task)"))
    # samples per category for the report (heads)
    samples = {}
    for k in order:
        xs = [r for r in NT if r["task"] == k]
        samples[k] = [{"ts": r["ts_local"][:16], "project": r["project"], "head": r["text"][:160].replace("\n", " ")} for r in xs[:: max(1, len(xs)//6)][:6]]
    M["task_samples"] = samples

    # ------------------------------------------------------------------ 3. итерации: уровень сессии
    # Явного сигнала «результат принят» в логах нет. Считаем: промтов на сессию, коррекций на сессию,
    # «застревания» = сессии с ≥3 коррекциями или ≥20 промтами.
    TS = [s for s in TR["sessions"] if s["in_window"]]
    sess_rows = collections.defaultdict(list)
    for r in PW:
        sess_rows[r["session"]].append(r)
    sess_stats = []
    for sid, rs in sess_rows.items():
        rs.sort(key=lambda r: r["ts"])
        n = len(rs)
        corr = sum(1 for r in rs if r["kind"] == "correction")
        # активное время по промтам: сумма пауз < 30 мин между соседними промтами
        act = 0.0
        for a, b in zip(rs, rs[1:]):
            g = (parse_ts(b["ts"]) - parse_ts(a["ts"])).total_seconds()
            if 0 <= g < 1800:
                act += g
        tasks_in = collections.Counter(r["task"] for r in rs if r["kind"] == "new-task")
        sess_stats.append({"session": sid, "project": rs[0]["project"], "group": rs[0]["group"], "prompts": n,
                           "corrections": corr, "active_min": round(act / 60), "start_local": rs[0]["ts_local"][:16],
                           "week": rs[0]["week"], "main_task": tasks_in.most_common(1)[0][0] if tasks_in else None,
                           "head": rs[0]["text"][:160].replace("\n", " "), "slash_first": rs[0]["slash"]})
    ps = [x["prompts"] for x in sess_stats]
    M["sessions_hooks"] = {
        "n": len(sess_stats), "prompts_median": statistics.median(ps), "prompts_p90": percentile(ps, 0.9), "prompts_max": max(ps),
        "single_prompt": sum(1 for x in ps if x == 1), "single_prompt_pct": round(sum(1 for x in ps if x == 1) / len(ps) * 100, 1),
        "le3": sum(1 for x in ps if x <= 3), "ge10": sum(1 for x in ps if x >= 10), "ge20": sum(1 for x in ps if x >= 20),
        "with_correction": sum(1 for x in sess_stats if x["corrections"] > 0),
        "with_correction_pct": round(sum(1 for x in sess_stats if x["corrections"] > 0) / len(sess_stats) * 100, 1),
        "ge3_corrections": sum(1 for x in sess_stats if x["corrections"] >= 3),
        "hist_prompts": dict(sorted(collections.Counter(min(x, 20) for x in ps).items())),
        "active_min_median": statistics.median(x["active_min"] for x in sess_stats),
        "active_min_p90": percentile([x["active_min"] for x in sess_stats], 0.9),
        "active_min_total": sum(x["active_min"] for x in sess_stats),
    }
    T.append("**Сессии (hooks, все 212):** " + json.dumps(M["sessions_hooks"], ensure_ascii=False) + "\n")
    by_grp = collections.defaultdict(list)
    for x in sess_stats:
        by_grp[x["group"]].append(x)
    M["sessions_by_group"] = {g: {"n": len(v), "prompts_median": statistics.median(x["prompts"] for x in v),
                                  "prompts_mean": round(statistics.mean(x["prompts"] for x in v), 1),
                                  "with_correction_pct": round(sum(1 for x in v if x["corrections"] > 0) / len(v) * 100),
                                  "active_min_median": statistics.median(x["active_min"] for x in v)} for g, v in by_grp.items()}
    T.append("**Сессии по группам:** " + json.dumps(M["sessions_by_group"], ensure_ascii=False) + "\n")
    by_task_s = collections.defaultdict(list)
    for x in sess_stats:
        by_task_s[x["main_task"] or "?"].append(x)
    rows = [{"task": k, "sessions": len(v), "prompts_mean": round(statistics.mean(x["prompts"] for x in v), 1),
             "corr_sessions_pct": round(sum(1 for x in v if x["corrections"] > 0) / len(v) * 100),
             "active_min_median": statistics.median(x["active_min"] for x in v)}
            for k, v in sorted(by_task_s.items(), key=lambda kv: -len(kv[1]))]
    M["sessions_by_task"] = rows
    T.append("**Сессии по основному типу задачи**\n\n| Тип | сессий | ср. промтов | % с коррекцией | медиана акт. мин |\n|---|---:|---:|---:|---:|\n" +
             "\n".join(f"| {r['task']} | {r['sessions']} | {r['prompts_mean']} | {r['corr_sessions_pct']} | {r['active_min_median']} |" for r in rows) + "\n")
    stuck = sorted([x for x in sess_stats if x["corrections"] >= 3 or x["prompts"] >= 20], key=lambda x: (-x["corrections"], -x["prompts"]))
    M["stuck_sessions"] = stuck
    T.append("**Застревания (сессии с ≥3 коррекциями или ≥20 промтами)**\n\n| Старт | проект | промтов | корр. | акт. мин | тип | первая постановка |\n|---|---|---:|---:|---:|---|---|\n" +
             "\n".join(f"| {x['start_local']} | {x['project']} | {x['prompts']} | {x['corrections']} | {x['active_min']} | {x['main_task']} | {x['head'][:100].replace('|','/')} |" for x in stuck) + "\n")
    # транскрипты: пары «постановка → следующая реплика» — сколько промтов идёт подряд без коррекции
    EP = [e for s in TS for e in s["episodes"]]
    M["episodes_tr"] = {"n": len(EP), "with_correction_pct": round(sum(1 for e in EP if e["corrections"] > 0) / len(EP) * 100, 1) if EP else None,
                        "note": "эпизод = new-task + следующие continue/answer/correction до следующей постановки; в транскриптах 101 сессия"}
    T.append("**Эпизоды в транскриптах:** " + json.dumps(M["episodes_tr"], ensure_ascii=False) + "\n")

    # коррекции по неделям/проектам из prompts (более широкая выборка)
    corr_week = {w: {"corrections": sum(1 for r in PW if r["week"] == w and r["kind"] == "correction"),
                     "prompts": by_week[w]["prompts"]} for w in W}
    for w in W:
        corr_week[w]["share_pct"] = round(corr_week[w]["corrections"] / max(1, corr_week[w]["prompts"]) * 100, 1)
    M["corrections_by_week"] = corr_week
    T.append(wk_table(corr_week, ["prompts", "corrections", "share_pct"], "Коррекции по неделям (все промты, hooks+history)"))
    corr_proj = collections.Counter(r["project"] for r in PW if r["kind"] == "correction")
    M["corrections_by_project"] = [{"project": p, "corrections": c, "prompts": proj[p], "share_pct": round(c / proj[p] * 100, 1)} for p, c in corr_proj.most_common(10)]
    T.append("**Коррекции по проектам**\n\n| Проект | коррекций | промтов | % |\n|---|---:|---:|---:|\n" +
             "\n".join(f"| {r['project']} | {r['corrections']} | {r['prompts']} | {r['share_pct']} |" for r in M["corrections_by_project"]) + "\n")
    corr_examples = [{"ts": r["ts_local"][:16], "project": r["project"], "head": r["text"][:180].replace("\n", " ")} for r in PW if r["kind"] == "correction"]
    M["correction_examples"] = corr_examples[:: max(1, len(corr_examples)//20)][:20]

    # ------------------------------------------------------------------ 4. принятие без правок (прокси)
    manual = [r for r in PW if any(k in r["text"].lower() for k in ("я сам", "сам поправ", "сам исправ", "руками", "вручную", "я поправил", "я исправил", "я переделал", "дальше я сам", "напишу я сам", "я сделал"))]
    reflect = [r for r in PW if r["slash"] == "reflect"]
    reflect_ever = [r for r in P if r["slash"] == "reflect"]
    single_shot_sessions = [s for s in TS if s["n_human_prompts"] == 1]
    M["acceptance_proxies"] = {
        "manual_edit_mentions": len(manual),
        "manual_examples": [{"ts": r["ts_local"][:16], "project": r["project"], "head": r["text"][:160].replace("\n", " ")} for r in manual[:12]],
        "reflect_calls_window": len(reflect), "reflect_calls_ever": len(reflect_ever),
        "sessions_single_prompt": len(single_shot_sessions), "sessions_total_tr": len(TS),
        "interrupted_sessions": sum(1 for s in TS if s["interrupted"] > 0), "interrupts_total": sum(s["interrupted"] for s in TS),
    }
    T.append("**Прокси принятия без правок:** " + json.dumps({k: v for k, v in M["acceptance_proxies"].items() if k != "manual_examples"}, ensure_ascii=False) + "\n")
    T.append("Примеры «сам/руками»:\n" + "\n".join(f"- {m['ts']} {m['project']}: {m['head']}" for m in M["acceptance_proxies"]["manual_examples"]) + "\n")

    # ------------------------------------------------------------------ 5. инструменты / агенты / skills / команды
    calls_w = [c for c in TOOLS["calls"] if c["in_window"]]
    tool_counts = collections.Counter(c["tool"] for c in calls_w)
    tool_counts_all = collections.Counter(c["tool"] for c in TOOLS["calls"])
    fails_tool = collections.Counter(c["tool"] for c in TOOLS["fails"] if c["in_window"])
    agent_types = collections.Counter(c.get("subagent_type", "?") for c in calls_w if c["tool"] == "Agent")
    agent_types_all = collections.Counter(c.get("subagent_type", "?") for c in TOOLS["calls"] if c["tool"] == "Agent")
    skill_tool = collections.Counter(c.get("skill", "?") for c in calls_w if c["tool"] == "Skill")
    skill_tool_all = collections.Counter(c.get("skill", "?") for c in TOOLS["calls"] if c["tool"] == "Skill")
    skill_main = collections.Counter()
    skill_sub = collections.Counter()
    for s in TS:
        skill_main.update(s["skill_loads_main"])
        skill_sub.update(s["skill_loads_sub"])
    slash = collections.Counter(r["slash"] for r in PW if r["slash"])
    slash_all = collections.Counter(r["slash"] for r in P if r["slash"])
    bash_calls = [c for c in calls_w if c["tool"] == "Bash"]
    edits = [c for c in calls_w if c["tool"] in ("Edit", "Write")]
    M["tools"] = {
        "counts": dict(tool_counts.most_common()), "counts_all_time": dict(tool_counts_all.most_common()),
        "fails_by_tool": dict(fails_tool.most_common()),
        "agents": dict(agent_types.most_common()), "agents_all_time": dict(agent_types_all.most_common()),
        "skill_tool": dict(skill_tool.most_common()), "skill_tool_all_time": dict(skill_tool_all.most_common()),
        "skill_loads_main_tr": dict(skill_main.most_common()), "skill_loads_sub_tr": dict(skill_sub.most_common()),
        "slash": dict(slash.most_common()), "slash_all_time": dict(slash_all.most_common()),
        "bash_test_runs": sum(1 for c in bash_calls if c.get("is_test_run")),
        "bash_git": sum(1 for c in bash_calls if c.get("is_git")),
        "edits_total": len(edits), "edits_test_files": sum(1 for c in edits if c.get("is_test_file")),
        "dead_commands": [c for c in INSTALLED_COMMANDS if slash.get(c, 0) == 0],
        "dead_commands_ever": [c for c in INSTALLED_COMMANDS if slash_all.get(c, 0) == 0],
        "dead_agents": [a for a in INSTALLED_AGENTS if agent_types.get(a, 0) == 0],
        "dead_agents_ever": [a for a in INSTALLED_AGENTS if agent_types_all.get(a, 0) == 0],
        "skills_never_loaded_tr": [s for s in INSTALLED_SKILLS if skill_main.get(s, 0) + skill_sub.get(s, 0) == 0],
        "skills_never_skill_tool_ever": [s for s in INSTALLED_SKILLS if skill_tool_all.get(s, 0) == 0],
    }
    T.append("**Инструменты (окно):** " + json.dumps(dict(tool_counts.most_common(20)), ensure_ascii=False) + "\n")
    T.append("**Ошибки инструментов по типу (окно):** " + json.dumps(dict(fails_tool.most_common(10))) + "\n")
    T.append("**Субагенты (Agent subagent_type, окно / всё время):** " + json.dumps(dict(agent_types.most_common())) + " / " + json.dumps(dict(agent_types_all.most_common())) + "\n")
    T.append("**Skill-инструмент (окно / всё время):** " + json.dumps(dict(skill_tool.most_common())) + " / " + json.dumps(dict(skill_tool_all.most_common())) + "\n")
    T.append("**Загрузки skills в транскриптах (главная сессия / субагенты):** " + json.dumps(dict(skill_main)) + " / " + json.dumps(dict(skill_sub)) + "\n")
    T.append("**Slash-команды (окно):** " + json.dumps(dict(slash.most_common()), ensure_ascii=False) + "\n")
    T.append("**Slash-команды (всё время):** " + json.dumps(dict(slash_all.most_common()), ensure_ascii=False) + "\n")
    T.append(f"Мёртвые команды в окне: {M['tools']['dead_commands']}; никогда: {M['tools']['dead_commands_ever']}\n")
    T.append(f"Мёртвые агенты в окне: {M['tools']['dead_agents']}; никогда: {M['tools']['dead_agents_ever']}\n")
    T.append(f"Skills без единой загрузки в транскриптах окна: {M['tools']['skills_never_loaded_tr']}\n")
    T.append(f"Bash: test runs={M['tools']['bash_test_runs']}, git={M['tools']['bash_git']}; Edit/Write={len(edits)}, из них тест-файлы={M['tools']['edits_test_files']}\n")

    # транскрипты: plan mode, ask user, компакты, ошибки, модели
    M["transcript_stats"] = {
        "sessions": len(TS),
        "plan_exits": sum(s["plan_exits"] for s in TS), "sessions_with_plan": sum(1 for s in TS if s["plan_exits"] > 0),
        "ask_user": sum(s["ask_user"] for s in TS), "sessions_with_ask": sum(1 for s in TS if s["ask_user"] > 0),
        "compactions": sum(s["compactions"] for s in TS),
        "tool_errors": sum(s["tool_errors"] for s in TS),
        "tool_uses": sum(s["n_tool_uses"] for s in TS),
        "models": dict(sum((collections.Counter(s["models"]) for s in TS), collections.Counter()).most_common()),
        "tokens_out": sum(s["tokens"].get("output", 0) for s in TS),
        "tokens_cache_read": sum(s["tokens"].get("cache_read", 0) for s in TS),
        "subagents_by_type": dict(sum((collections.Counter(s["subagents"]) for s in TS), collections.Counter()).most_common()),
    }
    T.append("**Транскрипты (окно):** " + json.dumps(M["transcript_stats"], ensure_ascii=False) + "\n")

    # ------------------------------------------------------------------ 6. время
    hours = collections.Counter(r["hour_local"] for r in PW)
    M["hour_hist"] = {h: hours.get(h, 0) for h in range(24)}
    buckets = collections.Counter(r["hour_bucket"] for r in PW)
    M["hour_buckets"] = dict(buckets)
    wd = collections.Counter(r["weekday_local"] for r in PW)
    M["weekday_hist"] = {d: wd.get(d, 0) for d in range(1, 8)}
    late = sum(1 for r in PW if r["hour_local"] >= 22 or r["hour_local"] < 6)
    weekend = sum(1 for r in PW if r["weekday_local"] >= 6)
    M["time_flags"] = {"late_night_prompts": late, "late_share_pct": round(late / len(PW) * 100, 1),
                       "weekend_prompts": weekend, "weekend_share_pct": round(weekend / len(PW) * 100, 1)}
    T.append("**Часы (локальные, UTC+6):** " + json.dumps(M["hour_hist"]) + "\n")
    T.append("**Интервалы:** " + json.dumps(buckets, ensure_ascii=False) + f"; ночь/выходные: {M['time_flags']}\n")
    T.append("**Дни недели (1=Пн):** " + json.dumps(M["weekday_hist"]) + "\n")
    # активные дни по неделям и по дням
    days = collections.Counter(r["ts_local"][:10] for r in PW)
    M["prompts_by_day"] = dict(sorted(days.items()))
    top_days = days.most_common(8)
    M["top_days"] = top_days
    T.append("**Самые плотные дни:** " + json.dumps(top_days) + "\n")
    # длительность сессий (транскрипты) и по хук-логам (SessionStart..SessionEnd)
    dur = [s["duration_min"] for s in TS if s["duration_min"] > 0]
    act = [s["active_min"] for s in TS]
    M["session_duration_tr"] = {"n": len(dur), "span_median_min": statistics.median(dur) if dur else None,
                                "span_p90_min": round(percentile(dur, 0.9)), "span_max_min": max(dur) if dur else None,
                                "active_median_min": statistics.median(act), "active_p90_min": round(percentile(act, 0.9)),
                                "active_max_min": max(act), "active_over_120": sum(1 for x in act if x > 120),
                                "active_over_240": sum(1 for x in act if x > 240)}
    prompts_per_sess = [s["n_human_prompts"] for s in TS]
    M["prompts_per_session_tr"] = {"median": statistics.median(prompts_per_sess), "p90": percentile(prompts_per_sess, 0.9),
                                   "max": max(prompts_per_sess), "hist": dict(sorted(collections.Counter(min(x, 20) for x in prompts_per_sess).items()))}
    # по hooks: промтов на сессию (все 212 сессий)
    pps = collections.Counter(r["session"] for r in PW)
    M["prompts_per_session_hooks"] = {"n_sessions": len(pps), "median": statistics.median(pps.values()), "p90": percentile(list(pps.values()), 0.9), "max": max(pps.values()),
                                      "single_prompt_sessions": sum(1 for v in pps.values() if v == 1)}
    # длительность по hooks: первый-последний промт сессии
    sess_span = {}
    for r in PW:
        s = sess_span.setdefault(r["session"], [r["ts"], r["ts"]])
        s[0] = min(s[0], r["ts"])
        s[1] = max(s[1], r["ts"])
    spans = [(parse_ts(b) - parse_ts(a)).total_seconds() / 60 for a, b in sess_span.values()]
    spans_pos = [x for x in spans if x > 0]
    M["session_span_hooks"] = {"n": len(spans), "median_min": round(statistics.median(spans_pos), 1) if spans_pos else None,
                               "p90_min": round(percentile(spans_pos, 0.9), 1), "max_min": round(max(spans_pos), 1),
                               "over_120": sum(1 for x in spans if x > 120), "over_240": sum(1 for x in spans if x > 240)}
    longest = sorted(((v[1], v[0], k) for k, v in sess_span.items()), key=lambda x: -(parse_ts(x[0]) - parse_ts(x[1])).total_seconds())[:8]
    M["longest_sessions"] = [{"session": k[:8], "start_local": parse_ts(a).astimezone(TZ_LOCAL).strftime("%Y-%m-%d %H:%M"),
                              "span_min": round((parse_ts(b) - parse_ts(a)).total_seconds() / 60), "prompts": pps[k],
                              "project": next(r["project"] for r in PW if r["session"] == k)} for b, a, k in longest]
    T.append("**Длительность сессий (транскрипты):** " + json.dumps(M["session_duration_tr"]) + "\n")
    T.append("**Промтов на сессию (транскрипты):** " + json.dumps(M["prompts_per_session_tr"]) + "\n")
    T.append("**Промтов на сессию (hooks, все сессии):** " + json.dumps(M["prompts_per_session_hooks"]) + "\n")
    T.append("**Размах сессии по hooks (первый→последний промт):** " + json.dumps(M["session_span_hooks"]) + "\n")
    T.append("**Самые длинные сессии:** " + json.dumps(M["longest_sessions"], ensure_ascii=False) + "\n")
    # gap after assistant (время реакции пользователя) — из транскриптов
    gaps = [t["gap_after_assistant_s"] for t in TR["turns"] if t["in_window"] and t["gap_after_assistant_s"] is not None and t["gap_after_assistant_s"] < 3600 * 6]
    M["reaction_gap_s"] = {"n": len(gaps), "median": statistics.median(gaps) if gaps else None, "p25": percentile(gaps, 0.25), "p75": percentile(gaps, 0.75),
                           "under_30s": round(sum(1 for g in gaps if g < 30) / len(gaps), 3) if gaps else None,
                           "under_60s": round(sum(1 for g in gaps if g < 60) / len(gaps), 3) if gaps else None}
    # реакция на длинные ответы: gap по виду реплики
    gk = collections.defaultdict(list)
    for t in TR["turns"]:
        if t["in_window"] and t["gap_after_assistant_s"] is not None and t["gap_after_assistant_s"] < 3600 * 6:
            gk[t["kind"]].append(t["gap_after_assistant_s"])
    M["reaction_gap_by_kind"] = {k: {"n": len(v), "median": statistics.median(v)} for k, v in gk.items()}
    T.append("**Пауза пользователя после ответа агента, сек (транскрипты):** " + json.dumps(M["reaction_gap_s"]) + " по видам: " + json.dumps(M["reaction_gap_by_kind"]) + "\n")

    # ------------------------------------------------------------------ 7. делегирование, разрушающее навык
    NTW = [r for r in NT if r["group"] in ("work", "personal", "other")]
    sr = collections.Counter()
    sr_week = collections.defaultdict(collections.Counter)
    for r in NTW:
        for k in r["skill_risk"]:
            sr[k] += 1
            sr_week[r["week"]][k] += 1
    any_risk = sum(1 for r in NTW if r["skill_risk"])
    M["skill_risk"] = {"n_new_task_work_personal": len(NTW), "any_risk": any_risk, "any_risk_pct": round(any_risk / len(NTW) * 100, 1),
                       "by_category": {k: sr.get(k, 0) for k in SKILL_RISK_CATEGORIES},
                       "by_week": {w: {k: sr_week[w].get(k, 0) for k in SKILL_RISK_CATEGORIES} for w in W}}
    ex = collections.defaultdict(list)
    for r in NTW:
        for k in r["skill_risk"]:
            ex[k].append({"ts": r["ts_local"][:16], "project": r["project"], "head": r["text"][:200].replace("\n", " ")})
    M["skill_risk_examples"] = {k: v[:: max(1, len(v)//8)][:8] for k, v in ex.items()}
    T.append(f"**Делегирование с риском для навыка (new-task, work+personal, n={len(NTW)}):** any={any_risk} ({M['skill_risk']['any_risk_pct']}%), " + json.dumps(M["skill_risk"]["by_category"]) + "\n")
    T.append(wk_table(M["skill_risk"]["by_week"], SKILL_RISK_CATEGORIES, "Риск-делегирование по неделям"))
    for k, v in M["skill_risk_examples"].items():
        T.append(f"Примеры {k}:\n" + "\n".join(f"- {e['ts']} {e['project']}: {e['head'][:170]}" for e in v) + "\n")
    # rule 08: доля постановок с собственной гипотезой среди отладки/проектирования (baseline для фазы 4)
    dbg = [r for r in NTW if r["task"] in ("debug", "sonar-fix") or "debug-root-cause" in r["skill_risk"]]
    dsg = [r for r in NTW if r["task"] == "planning-arch" or "architecture-decision" in r["skill_risk"]]
    M["hypothesis_share"] = {
        "debug": {"n": len(dbg), "with_hypothesis": sum(1 for r in dbg if r.get("has_hypothesis")),
                  "pct": round(sum(1 for r in dbg if r.get("has_hypothesis")) / len(dbg) * 100, 1) if dbg else None},
        "design": {"n": len(dsg), "with_hypothesis": sum(1 for r in dsg if r.get("has_hypothesis")),
                   "pct": round(sum(1 for r in dsg if r.get("has_hypothesis")) / len(dsg) * 100, 1) if dsg else None},
        "by_week": {w: {"debug_n": sum(1 for r in dbg if r["week"] == w), "debug_h": sum(1 for r in dbg if r["week"] == w and r.get("has_hypothesis")),
                        "design_n": sum(1 for r in dsg if r["week"] == w), "design_h": sum(1 for r in dsg if r["week"] == w and r.get("has_hypothesis"))} for w in W},
    }
    T.append("**Rule 08 baseline — постановки с собственной гипотезой/вариантом:** " + json.dumps({k: v for k, v in M["hypothesis_share"].items() if k != "by_week"}, ensure_ascii=False) + "\n")
    T.append(wk_table(M["hypothesis_share"]["by_week"], ["debug_n", "debug_h", "design_n", "design_h"], "Гипотеза в постановке по неделям"))

    # /task and /plan usage — «весь цикл агенту»
    heavy = [r for r in PW if r["slash"] in ("task", "feature", "plan")]
    M["heavy_orchestration"] = {"count": len(heavy), "task": slash.get("task", 0), "feature": slash.get("feature", 0), "plan": slash.get("plan", 0),
                                "examples": [{"ts": r["ts_local"][:16], "project": r["project"], "head": r["text"][:200].replace("\n", " ")} for r in heavy[:: max(1, len(heavy)//10)][:10]]}
    # промты-«роль-приманки» («как профессионал», «как эксперт»)
    role = [r for r in NT if any(k in r["text"].lower() for k in ("как профессионал", "как эксперт", "как senior", "как опытный", "как архитектор"))]
    M["role_prompts"] = {"count": len(role), "share_pct": round(len(role) / len(NT) * 100, 1)}
    # длина промта
    lens = [r["length"] for r in PW]
    M["prompt_length"] = {"median": statistics.median(lens), "mean": round(statistics.mean(lens)), "p90": percentile(lens, 0.9),
                          "share_under_60": round(sum(1 for x in lens if x < 60) / len(lens), 3),
                          "share_over_500": round(sum(1 for x in lens if x > 500) / len(lens), 3),
                          "cyr_share_mean": round(statistics.mean(r["cyr_share"] for r in PW), 3),
                          "with_file_ref": sum(1 for r in PW if r["has_file_ref"]), "with_paste": sum(1 for r in PW if r["has_paste"])}
    T.append("**Длина промтов:** " + json.dumps(M["prompt_length"]) + f"; роль-приманки: {M['role_prompts']}; /task+/feature+/plan: {M['heavy_orchestration']['count']}\n")

    # blocks
    blocks = [b for b in LOGS["blocks"] if b["in_window"]]
    M["blocks"] = {"count": len(blocks), "kinds": dict(collections.Counter(b.get("kind") for b in blocks))}
    T.append("**Блокировки хуков (окно):** " + json.dumps(M["blocks"]) + "\n")

    # ------------------------------------------------------------------ write
    with open(os.path.join(d, "metrics.json"), "w", encoding="utf-8") as fh:
        json.dump(M, fh, ensure_ascii=False, indent=1, default=str)
    with open(os.path.join(d, "tables.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(T))
    print("\n".join(T))


if __name__ == "__main__":
    main()

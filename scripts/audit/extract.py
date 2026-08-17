#!/usr/bin/env python3
"""Извлечение данных для аудита использования Claude Code (фаза 1).

Источники (все локальные):
  ~/.claude/history.jsonl                — все промты пользователя с полным текстом (с 2026-03).
  ~/.claude/logs/{stops,tools,sessions,subagents,prompts,blocks}.jsonl — хуки (с 2026-05-17).
  ~/.claude/projects/<proj>/<session>.jsonl — транскрипты сессий (сохранены ~с 2026-06-27).

Выход: JSON-датасеты в <out>/data/. Отчёт строится отдельно (report_phase1.py).

Запуск: python3 scripts/audit/extract.py [--out docs/audit-2026-08]
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import audit_lib  # noqa: E402
from audit_lib import (  # noqa: E402
    TZ_LOCAL,
    classify_skill_risk,
    classify_task,
    has_hypothesis,
    command_args,
    cyrillic_share,
    hour_bucket,
    in_window,
    interaction_kind,
    iso_week,
    local,
    ms_to_dt,
    parse_ts,
    project_group,
    project_short,
    slash_command,
)

HOME = os.path.expanduser("~")
CLAUDE_DIR = os.path.join(HOME, ".claude")


def dump(path: str, obj) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=1, default=str)
    print(f"  wrote {path}")


# ---------------------------------------------------------------- history.jsonl

def _load_history() -> list[dict]:
    """history.jsonl — только CLI-сессии, зато полный текст промта."""
    rows = []
    path = os.path.join(CLAUDE_DIR, "history.jsonl")
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            rows.append({
                "ts": ms_to_dt(o["timestamp"]), "session": o.get("sessionId", ""),
                "text": o.get("display", "") or "", "project_path": o.get("project", "") or "",
                "has_paste": bool(o.get("pastedContents")),
            })
    return rows


_SYSTEM_PROMPT = re.compile(r"^\s*<(task-notification|local-command-stdout|local-command-caveat|system-reminder|command-name)")


def extract_prompts() -> list[dict]:
    """Единый список промтов пользователя.

    База — hooks/prompts.jsonl (CLI + Claude Desktop, но текст обрезан до 500 символов).
    Обогащение — history.jsonl (только CLI, полный текст): джойн по session + |Δts| ≤ 3 с.
    Внутри сессии считаем вид взаимодействия по порядку.
    """
    hist = _load_history()
    hist_by_sess = collections.defaultdict(list)
    for h in hist:
        hist_by_sess[h["session"]].append(h)
    used_hist = set()

    rows = []
    path = os.path.join(CLAUDE_DIR, "logs", "prompts.jsonl")
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = parse_ts(o["ts"])
            sess = o.get("session", "")
            text = o.get("head", "") or ""
            if _SYSTEM_PROMPT.match(text):
                continue  # служебные сообщения харнесса, не человек
            full = False
            best = None
            for h in hist_by_sess.get(sess, []):
                if id(h) in used_hist:
                    continue
                d = abs((h["ts"] - ts).total_seconds())
                if d <= 3 and (best is None or d < best[0]):
                    best = (d, h)
            if best:
                used_hist.add(id(best[1]))
                text = best[1]["text"]
                full = True
            cwd = o.get("cwd", "") or ""
            short = (o.get("project") or project_short(cwd)).lower()
            if "/docs/lifeOS" in cwd:
                short = "lifeOS"
            grp = project_group(short, cwd)
            rows.append({
                "ts": ts.isoformat(),
                "ts_local": local(ts).isoformat(),
                "week": iso_week(ts),
                "in_window": in_window(ts),
                "project": short,
                "project_path": cwd,
                "group": grp,
                "session": sess,
                "text": text,
                "full_text": full,
                "length": o.get("length", len(text)),
                "has_paste": bool(best and best[1]["has_paste"]),
                "has_file_ref": bool(re.search(r"@/?[\w~./-]+", text)),
                "cyr_share": round(cyrillic_share(text), 3),
                "hour_local": local(ts).hour,
                "weekday_local": local(ts).isoweekday(),
                "hour_bucket": hour_bucket(ts),
                "slash": slash_command(text),
            })
    # history-промты до начала хуков (2026-05-17) — добавляем как есть, чтобы был baseline
    first_hook = min(r["ts"] for r in rows)
    for h in hist:
        if h["ts"].isoformat() < first_hook:
            short = project_short(h["project_path"])
            grp = project_group(short, h["project_path"])
            rows.append({
                "ts": h["ts"].isoformat(), "ts_local": local(h["ts"]).isoformat(), "week": iso_week(h["ts"]),
                "in_window": in_window(h["ts"]), "project": short, "project_path": h["project_path"], "group": grp,
                "session": h["session"], "text": h["text"], "full_text": True, "length": len(h["text"]),
                "has_paste": h["has_paste"], "has_file_ref": bool(re.search(r"@/?[\w~./-]+", h["text"])),
                "cyr_share": round(cyrillic_share(h["text"]), 3), "hour_local": local(h["ts"]).hour,
                "weekday_local": local(h["ts"]).isoweekday(), "hour_bucket": hour_bucket(h["ts"]),
                "slash": slash_command(h["text"]),
            })
    rows.sort(key=lambda r: r["ts"])
    # вид взаимодействия + тип задачи по сессиям
    by_sess = collections.defaultdict(list)
    for r in rows:
        by_sess[r["session"]].append(r)
    for sess_rows in by_sess.values():
        for i, r in enumerate(sess_rows):
            kind = interaction_kind(r["text"])
            if i == 0 and kind == "continue":
                kind = "new-task"  # первое сообщение — всегда постановка
            r["kind"] = kind
            r["idx_in_session"] = i
            r["task"] = classify_task(r["text"], r["group"]) if kind == "new-task" else None
            r["skill_risk"] = classify_skill_risk(r["text"]) if kind == "new-task" and r["group"] in ("work", "personal", "other") else []
            r["has_hypothesis"] = has_hypothesis(r["text"]) if kind == "new-task" else False
    return rows


def _proj(o: dict) -> tuple[str, str]:
    """(короткое имя проекта, группа) из строки хук-лога."""
    cwd = o.get("cwd", "") or ""
    short = (o.get("project") or project_short(cwd) or "?").lower()
    if "/docs/lifeOS" in cwd:
        short = "lifeOS"
    return short, project_group(short, cwd)


# ---------------------------------------------------------------- hooks: stops (tokens)

def extract_tokens() -> dict:
    """stops.jsonl кумулятивен в рамках сессии: считаем дельты между соседними стопами одной сессии."""
    path = os.path.join(CLAUDE_DIR, "logs", "stops.jsonl")
    last: dict[str, dict] = {}
    deltas = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            s = o["session"]
            prev = last.get(s)
            cur = {k: o.get(k, 0) or 0 for k in ("input_tokens", "output_tokens", "cache_read", "cache_write", "turns")}
            if prev is None:
                d = cur
            else:
                d = {k: cur[k] - prev[k] for k in cur}
                if any(v < 0 for v in d.values()):  # сброс счётчика (новая подсессия) — считаем как с нуля
                    d = cur
            last[s] = cur
            ts = parse_ts(o["ts"])
            short, grp = _proj(o)
            deltas.append({
                "ts": ts.isoformat(), "week": iso_week(ts), "in_window": in_window(ts),
                "session": s, "project": short, "group": grp, "cwd": o.get("cwd", ""),
                "models": o.get("models", []), **d,
            })
    return {"deltas": deltas}


# ---------------------------------------------------------------- hooks: tools

def extract_tools() -> dict:
    path = os.path.join(CLAUDE_DIR, "logs", "tools.jsonl")
    calls, fails = [], []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            ph = o.get("phase")
            if ph not in ("pre", "fail"):
                continue
            ts = parse_ts(o["ts"])
            short, grp = _proj(o)
            row = {
                "ts": ts.isoformat(), "week": iso_week(ts), "in_window": in_window(ts),
                "session": o.get("session"), "project": short, "group": grp, "tool": o.get("tool"),
                "agent": o.get("agent", ""),
            }
            inp = o.get("input") or {}
            if o.get("tool") == "Agent":
                row["subagent_type"] = inp.get("subagent_type", "?")
            if o.get("tool") == "Skill":
                row["skill"] = inp.get("skill") or inp.get("name") or "?"
            if o.get("tool") == "Bash":
                cmd = (inp.get("command") or "")[:200]
                row["cmd_head"] = cmd.split()[0] if cmd.split() else ""
                row["is_test_run"] = bool(re.search(r"(mvn|mvnw|gradle|gradlew|go test|npm (run )?test|pytest|vitest|jest|bash tests/|\btest\b)", cmd))
                row["is_git"] = cmd.lstrip().startswith("git ")
            if o.get("tool") in ("Edit", "Write", "Read"):
                fp = inp.get("file_path", "") or ""
                row["ext"] = os.path.splitext(fp)[1].lower()
                row["is_test_file"] = bool(re.search(r"(/test/|/tests/|_test\.|Test\.java|\.spec\.|\.test\.)", fp))
            (fails if ph == "fail" else calls).append(row)
    return {"calls": calls, "fails": fails}


# ---------------------------------------------------------------- hooks: sessions / subagents / blocks

def extract_simple_logs() -> dict:
    out = {}
    for name in ("sessions", "subagents", "blocks", "prompts"):
        path = os.path.join(CLAUDE_DIR, "logs", f"{name}.jsonl")
        rows = []
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                for line in fh:
                    try:
                        o = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    ts = parse_ts(o["ts"])
                    o["week"] = iso_week(ts)
                    o["in_window"] = in_window(ts)
                    rows.append(o)
        out[name] = rows
    return out


# ---------------------------------------------------------------- transcripts

_SKILL_BASE = re.compile(r"Base directory for this skill: ([^\s\"\\]+)")
_SKIP_USER = re.compile(r"^\s*<(task-notification|local-command-stdout|local-command-caveat|system-reminder)")


def _human_text(o: dict) -> str | None:
    """Текст реплики человека или None, если это tool_result / служебка."""
    if o.get("isMeta") or o.get("isCompactSummary"):
        return None
    c = o["message"].get("content")
    if isinstance(c, str):
        text = c
    elif isinstance(c, list):
        texts = [p.get("text", "") for p in c if p.get("type") == "text"]
        if not texts:
            return None
        text = "\n".join(texts)
    else:
        return None
    if _SKIP_USER.match(text):
        return None
    if text.startswith("<command-name>") and "<command-message>" in text and "<command-args>" not in text:
        return None  # чистые локальные команды (/model, /clear ...)
    if text.startswith("This session is being continued from a previous conversation"):
        return None
    if "[Request interrupted by user" in text and len(text) < 80:
        return None
    return text


def extract_transcripts() -> dict:
    base = os.path.join(CLAUDE_DIR, "projects")
    sessions, turns = [], []
    for proj_dir in sorted(os.listdir(base)):
        pdir = os.path.join(base, proj_dir)
        if not os.path.isdir(pdir):
            continue
        for f in sorted(glob.glob(os.path.join(pdir, "*.jsonl"))):
            sid = os.path.basename(f)[:-6]
            msgs = []
            with open(f, encoding="utf-8") as fh:
                for line in fh:
                    try:
                        o = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if o.get("type") in ("user", "assistant") and o.get("timestamp"):
                        msgs.append(o)
            if not msgs:
                continue
            short = project_short(proj_dir)
            cwd = msgs[0].get("cwd", "")
            grp = project_group(short, cwd)
            usage_by_msg: dict[str, dict] = {}
            skill_loads_main = collections.Counter()
            skill_loads_sub = collections.Counter()
            for sf in glob.glob(os.path.join(pdir, sid, "subagents", "*.jsonl")):
                with open(sf, encoding="utf-8") as sfh:
                    for m in _SKILL_BASE.finditer(sfh.read()):
                        skill_loads_sub[m.group(1).rstrip("/").split("/")[-1]] += 1
            models = collections.Counter()
            tool_uses = collections.Counter()
            subagents = collections.Counter()
            skills = collections.Counter()
            tool_errors = 0
            n_asst = 0
            n_compact = 0
            interrupted = 0
            plan_exits = 0
            asks = 0
            first_ts = parse_ts(msgs[0]["timestamp"])
            last_ts = parse_ts(msgs[-1]["timestamp"])
            # активное время: сумма пауз между соседними сообщениями < 30 мин
            active_s = 0.0
            prev_ts = None
            for o in msgs:
                ts_ = parse_ts(o["timestamp"])
                if prev_ts is not None:
                    gap_ = (ts_ - prev_ts).total_seconds()
                    if 0 <= gap_ < 1800:
                        active_s += gap_
                prev_ts = ts_
            human = []  # (idx, ts, text, prev_asst_asks, prev_asst_ts)
            last_asst_text = ""
            last_asst_ts = None
            for o in msgs:
                ts = parse_ts(o["timestamp"])
                if o["type"] == "user" and o.get("isMeta"):
                    c0 = o["message"].get("content")
                    txt0 = c0 if isinstance(c0, str) else " ".join(p.get("text", "") for p in c0 if isinstance(p, dict))
                    for m in _SKILL_BASE.finditer(txt0):
                        skill_loads_main[m.group(1).rstrip("/").split("/")[-1]] += 1
                if o["type"] == "assistant":
                    m = o["message"]
                    n_asst += 1
                    mid = m.get("id") or o.get("requestId") or o["uuid"]
                    if "usage" in m:
                        usage_by_msg[mid] = m["usage"]
                    if m.get("model"):
                        models[m["model"]] += 1
                    for p in m.get("content", []) or []:
                        if p.get("type") == "tool_use":
                            name = p.get("name", "?")
                            tool_uses[name] += 1
                            inp = p.get("input") or {}
                            if name == "Agent":
                                subagents[inp.get("subagent_type", "?")] += 1
                            elif name == "Skill":
                                skills[inp.get("skill", "?")] += 1
                            elif name == "ExitPlanMode":
                                plan_exits += 1
                            elif name == "AskUserQuestion":
                                asks += 1
                        elif p.get("type") == "text":
                            last_asst_text = p.get("text", "")
                    last_asst_ts = ts
                else:
                    if o.get("isCompactSummary"):
                        n_compact += 1
                    c = o["message"].get("content")
                    if isinstance(c, list):
                        for p in c:
                            if p.get("type") == "tool_result" and p.get("is_error"):
                                tool_errors += 1
                            if p.get("type") == "text" and "[Request interrupted by user" in p.get("text", ""):
                                interrupted += 1
                    if isinstance(c, str) and "[Request interrupted by user" in c:
                        interrupted += 1
                    text = _human_text(o)
                    if text is None:
                        continue
                    prev_asks = last_asst_text.rstrip().endswith("?") or "AskUserQuestion" in last_asst_text
                    human.append((len(human), ts, text, prev_asks, last_asst_ts))
            usage_tot = collections.Counter()
            for u in usage_by_msg.values():
                usage_tot["input"] += u.get("input_tokens", 0) or 0
                usage_tot["output"] += u.get("output_tokens", 0) or 0
                usage_tot["cache_read"] += u.get("cache_read_input_tokens", 0) or 0
                usage_tot["cache_write"] += u.get("cache_creation_input_tokens", 0) or 0
            # реплики человека → виды и типы
            kinds = []
            for idx, ts, text, prev_asks, prev_asst_ts in human:
                kind = interaction_kind(text, prev_asks)
                if idx == 0 and kind != "new-task":
                    kind = "new-task"
                sc = slash_command(text)
                body = command_args(text) if text.startswith("<command-message>") else text
                task = classify_task((("/" + sc + " ") if sc else "") + body, grp) if kind == "new-task" else None
                gap = (ts - prev_asst_ts).total_seconds() if prev_asst_ts else None
                turns.append({
                    "session": sid, "project": short, "group": grp, "idx": idx,
                    "ts": ts.isoformat(), "week": iso_week(ts), "in_window": in_window(ts),
                    "hour_local": local(ts).hour, "weekday_local": local(ts).isoweekday(),
                    "kind": kind, "task": task, "slash": sc, "length": len(body),
                    "gap_after_assistant_s": round(gap) if gap is not None else None,
                    "head": body[:220].replace("\n", " "),
                    "skill_risk": classify_skill_risk(body) if kind == "new-task" and grp in ("work", "personal", "other") else [],
                })
                kinds.append(kind)
            # эпизоды: new-task, затем серия correction/answer/continue до следующего new-task
            episodes = []
            cur = None
            for t in turns[len(turns) - len(human):]:
                if t["kind"] == "new-task":
                    if cur:
                        episodes.append(cur)
                    cur = {"task": t["task"], "corrections": 0, "answers": 0, "continues": 0, "turns": 1,
                           "start_idx": t["idx"], "head": t["head"], "skill_risk": t["skill_risk"]}
                elif cur:
                    cur["turns"] += 1
                    cur[{"correction": "corrections", "answer": "answers", "continue": "continues"}[t["kind"]]] += 1
            if cur:
                episodes.append(cur)
            for e in episodes:
                e["session"] = sid
                e["project"] = short
                e["group"] = grp
                e["week"] = iso_week(first_ts)
                e["in_window"] = in_window(first_ts)
            sessions.append({
                "session": sid, "project": short, "group": grp, "cwd": cwd,
                "start": first_ts.isoformat(), "end": last_ts.isoformat(),
                "start_local": local(first_ts).isoformat(), "week": iso_week(first_ts), "in_window": in_window(first_ts),
                "duration_min": round((last_ts - first_ts).total_seconds() / 60, 1),
                "active_min": round(active_s / 60, 1),
                "n_lines": len(msgs), "n_assistant_msgs": n_asst, "n_human_prompts": len(human),
                "kinds": dict(collections.Counter(kinds)),
                "n_tool_uses": sum(tool_uses.values()), "tools": dict(tool_uses.most_common()),
                "subagents": dict(subagents), "skills": dict(skills),
                "skill_loads_main": dict(skill_loads_main), "skill_loads_sub": dict(skill_loads_sub),
                "tool_errors": tool_errors, "interrupted": interrupted, "compactions": n_compact,
                "plan_exits": plan_exits, "ask_user": asks,
                "models": dict(models), "tokens": dict(usage_tot),
                "episodes": episodes,
                "git_branch": msgs[0].get("gitBranch", ""),
                "version": msgs[0].get("version", ""),
            })
    return {"sessions": sessions, "turns": turns}


# ---------------------------------------------------------------- main

def main() -> None:
    ap = argparse.ArgumentParser(description="Извлечение данных аудита. По умолчанию окно = последние 9 ISO-недель, "
                                             "выход = docs/audit-<ГГГГ-ММ>/data/.")
    ap.add_argument("--out", default=None, help="каталог аудита (по умолчанию docs/audit-<ГГГГ-ММ> текущего месяца)")
    ap.add_argument("--start", default=None, help="начало окна, YYYY-MM-DD (UTC, включительно)")
    ap.add_argument("--end", default=None, help="конец окна, YYYY-MM-DD (UTC, исключительно)")
    ap.add_argument("--weeks", type=int, default=9, help="длина окна в ISO-неделях, если --start/--end не заданы")
    args = ap.parse_args()
    if args.start or args.end:
        s0 = dt.datetime.fromisoformat(args.start).replace(tzinfo=dt.timezone.utc) if args.start else audit_lib.default_window(args.weeks)[0]
        e0 = dt.datetime.fromisoformat(args.end).replace(tzinfo=dt.timezone.utc) if args.end else audit_lib.default_window(args.weeks)[1]
    else:
        s0, e0 = audit_lib.default_window(args.weeks)
    audit_lib.set_window(s0, e0)
    out = args.out or f"docs/audit-{dt.datetime.now(dt.timezone.utc):%Y-%m}"
    data_dir = os.path.join(out, "data")
    print(f"window: {s0.date()} .. {e0.date()} (excl), tz={TZ_LOCAL}, out={out}")

    print("prompts (hooks/prompts.jsonl + history.jsonl) ...")
    hist = extract_prompts()
    dump(os.path.join(data_dir, "prompts.json"), hist)
    print(f"  {len(hist)} prompts, in window: {sum(1 for r in hist if r['in_window'])}, "
          f"full text: {sum(1 for r in hist if r['full_text'])}")

    print("stops.jsonl ...")
    tok = extract_tokens()
    dump(os.path.join(data_dir, "tokens.json"), tok)

    print("tools.jsonl ...")
    tools = extract_tools()
    dump(os.path.join(data_dir, "tools.json"), tools)
    print(f"  {len(tools['calls'])} calls, {len(tools['fails'])} fails")

    print("sessions/subagents/blocks/prompts ...")
    simple = extract_simple_logs()
    dump(os.path.join(data_dir, "hook_logs.json"), simple)

    print("transcripts ...")
    tr = extract_transcripts()
    dump(os.path.join(data_dir, "transcripts.json"), tr)
    print(f"  {len(tr['sessions'])} sessions, {len(tr['turns'])} human turns")

    meta = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "window_start": audit_lib.AUDIT_START.isoformat(), "window_end_excl": audit_lib.AUDIT_END.isoformat(),
        "tz": str(TZ_LOCAL),
        "sources": {
            "prompts(merged)": {"prompts": len(hist), "first": hist[0]["ts"], "last": hist[-1]["ts"],
                                "in_window": sum(1 for r in hist if r["in_window"]),
                                "full_text_in_window": sum(1 for r in hist if r["in_window"] and r["full_text"])},
            "stops.jsonl": {"rows": len(tok["deltas"])},
            "tools.jsonl": {"calls": len(tools["calls"]), "fails": len(tools["fails"])},
            "transcripts": {"sessions": len(tr["sessions"]), "turns": len(tr["turns"]),
                            "first": min(s["start"] for s in tr["sessions"]),
                            "last": max(s["end"] for s in tr["sessions"])},
            **{k + ".jsonl": {"rows": len(v)} for k, v in simple.items()},
        },
    }
    dump(os.path.join(data_dir, "meta.json"), meta)


if __name__ == "__main__":
    main()

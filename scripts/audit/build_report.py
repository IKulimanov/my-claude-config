#!/usr/bin/env python3
"""Собирает docs/audit-2026-08/report.html из 01–06 md + data/metrics.json.

Один файл, vanilla JS, без внешних ресурсов (графики — inline SVG, рисуются JS из встроенных данных),
системные шрифты, тёмная тема. Запуск: python3 scripts/audit/build_report.py [--out docs/audit-2026-08]
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re

# ------------------------------------------------------------------ минимальный markdown → HTML

_INLINE = [
    (re.compile(r"`([^`]+)`"), lambda m: f"<code>{html.escape(m.group(1))}</code>"),
    (re.compile(r"\*\*(.+?)\*\*"), lambda m: f"<strong>{m.group(1)}</strong>"),
    (re.compile(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])"), lambda m: f"<em>{m.group(1)}</em>"),
    (re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)"), lambda m: f'<a href="{m.group(2)}" target="_blank" rel="noopener">{m.group(1)}</a>'),
    (re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)"), lambda m: f"<span class=\"path\">{m.group(1)}</span>"),
]


def inline(s: str) -> str:
    # защищаем code от остальных замен: сначала вырезаем, потом возвращаем
    codes: list[str] = []

    def keep(m):
        codes.append(f"<code>{html.escape(m.group(1))}</code>")
        return f"\x00{len(codes)-1}\x00"

    s = re.sub(r"`([^`]+)`", keep, s)
    s = html.escape(s, quote=False)
    for rx, fn in _INLINE[1:]:
        s = rx.sub(fn, s)
    s = re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], s)
    return s


def md_to_html(md: str) -> str:
    lines = md.split("\n")
    out: list[str] = []
    i = 0
    list_stack: list[str] = []  # 'ul'/'ol'

    def close_lists(depth=0):
        while len(list_stack) > depth:
            out.append(f"</{list_stack.pop()}>")

    para: list[str] = []

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(x.strip() for x in para)) + "</p>")
            para.clear()

    while i < len(lines):
        ln = lines[i]
        # fenced code
        m = re.match(r"^```(\w+)?\s*$", ln)
        if m:
            flush_para(); close_lists()
            lang = m.group(1) or ""
            buf = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i]); i += 1
            i += 1
            if lang == "diff":
                body = "\n".join(
                    f'<span class="{ "add" if l.startswith("+") else "del" if l.startswith("-") else "ctx" if l.startswith("@@") else "" }">{html.escape(l)}</span>'
                    for l in buf)
            else:
                body = html.escape("\n".join(buf))
            out.append(f'<pre class="code lang-{lang}"><code>{body}</code></pre>')
            continue
        # heading
        m = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if m:
            flush_para(); close_lists()
            lvl = len(m.group(1))
            text = m.group(2).strip()
            anchor = re.sub(r"[^\w\-]+", "-", text.lower()).strip("-")
            out.append(f'<h{lvl} id="{anchor}">{inline(text)}</h{lvl}>')
            i += 1; continue
        # table
        if ln.strip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{3,}", lines[i + 1]):
            flush_para(); close_lists()
            header = [c.strip() for c in ln.strip().strip("|").split("|")]
            align = [("right" if c.strip().endswith(":") and not c.strip().startswith(":") else "left") for c in lines[i + 1].strip().strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")]); i += 1
            out.append('<div class="tblwrap"><table><thead><tr>' + "".join(f"<th>{inline(h)}</th>" for h in header) + "</tr></thead><tbody>")
            for r in rows:
                cells = []
                for j, c in enumerate(r):
                    a = align[j] if j < len(align) else "left"
                    cells.append(f'<td class="{a}">{inline(c)}</td>')
                out.append("<tr>" + "".join(cells) + "</tr>")
            out.append("</tbody></table></div>")
            continue
        # blockquote
        if ln.startswith(">"):
            flush_para(); close_lists()
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i][1:].strip()); i += 1
            out.append("<blockquote>" + inline(" ".join(buf)) + "</blockquote>")
            continue
        # list item (с одним уровнем вложенности по отступу)
        m = re.match(r"^(\s*)([-*]|\d+[.)])\s+(.*)$", ln)
        if m:
            flush_para()
            indent = len(m.group(1).replace("\t", "    "))
            depth = 1 if indent < 2 else 2
            kind = "ol" if m.group(2)[0].isdigit() else "ul"
            # continuation lines (indented, not list markers)
            text = m.group(3)
            i += 1
            while i < len(lines) and lines[i].strip() and not re.match(r"^(\s*)([-*]|\d+[.)])\s+", lines[i]) and not lines[i].startswith("#") and not lines[i].startswith("```") and not lines[i].strip().startswith("|") and (lines[i].startswith("  ") or lines[i].startswith("\t")):
                text += " " + lines[i].strip(); i += 1
            while len(list_stack) > depth:
                out.append(f"</{list_stack.pop()}>")
            if len(list_stack) < depth:
                list_stack.append(kind); out.append(f"<{kind}>")
            elif list_stack[-1] != kind and depth == 1:
                out.append(f"</{list_stack.pop()}>"); list_stack.append(kind); out.append(f"<{kind}>")
            out.append(f"<li>{inline(text)}</li>")
            continue
        # hr
        if re.match(r"^\s*---+\s*$", ln):
            flush_para(); close_lists(); out.append("<hr>"); i += 1; continue
        # blank
        if not ln.strip():
            flush_para(); close_lists(); i += 1; continue
        # paragraph text
        if list_stack:
            close_lists()
        para.append(ln)
        i += 1
    flush_para(); close_lists()
    return "\n".join(out)


def badge_levels(h: str) -> str:
    return re.sub(r"<td class=\"left\">(E[1-4](?:/E[1-4])?(?:→E[1-4])?(?: \([^)]*\))?)</td>",
                  lambda m: f'<td class="left"><span class="badge {m.group(1)[:2].lower()}">{m.group(1)}</span></td>', h)


# ------------------------------------------------------------------ сборка

CSS = """
:root{--bg:#0f1115;--bg2:#161a22;--bg3:#1d2230;--fg:#e6e6e6;--muted:#9aa4b2;--acc:#7cc4ff;--acc2:#ffb86b;--ok:#6fdd8b;--bad:#ff7b7b;--line:#2a3140;
--c1:#7cc4ff;--c2:#ffb86b;--c3:#b48cff;--c4:#6fdd8b;--c5:#ff7b7b;--c6:#59d3c9;--c7:#f6e58d;--c8:#a0a0a0}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,"Noto Sans",sans-serif}
header{position:sticky;top:0;z-index:5;background:var(--bg2);border-bottom:1px solid var(--line);padding:10px 20px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
header h1{font-size:15px;margin:0 16px 0 0;color:var(--muted);font-weight:600}
nav button{background:transparent;color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:6px 12px;cursor:pointer;font:inherit}
nav button.active{background:var(--acc);color:#0b1620;border-color:var(--acc);font-weight:600}
main{max-width:1180px;margin:0 auto;padding:22px 20px 80px}
section.tab{display:none}section.tab.active{display:block}
h1,h2,h3,h4{line-height:1.25}h1{font-size:26px;margin:.4em 0}h2{font-size:21px;margin:1.6em 0 .6em;border-bottom:1px solid var(--line);padding-bottom:4px}
h3{font-size:17px;margin:1.3em 0 .5em;color:var(--acc)}h4{font-size:15px;color:var(--muted)}
p{margin:.6em 0}a{color:var(--acc)}code{background:var(--bg3);padding:1px 5px;border-radius:4px;font:13px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
pre.code{background:var(--bg3);border:1px solid var(--line);border-radius:8px;padding:12px 14px;overflow-x:auto;font:12.5px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
pre.code code{background:none;padding:0;font:inherit}
pre .add{color:var(--ok)}pre .del{color:var(--bad)}pre .ctx{color:var(--acc)}
.tblwrap{overflow-x:auto;margin:.8em 0}table{border-collapse:collapse;width:100%;font-size:13.5px}
th,td{border:1px solid var(--line);padding:6px 9px;vertical-align:top}th{background:var(--bg3);text-align:left}td.right{text-align:right;white-space:nowrap}
tbody tr:nth-child(odd){background:rgba(255,255,255,.02)}
blockquote{border-left:3px solid var(--acc2);margin:.8em 0;padding:4px 12px;color:var(--muted)}
ul,ol{padding-left:1.4em}li{margin:.25em 0}li ul,li ol{margin:.2em 0}
hr{border:0;border-top:1px solid var(--line);margin:1.5em 0}
.badge{display:inline-block;padding:1px 7px;border-radius:10px;font-size:12px;font-weight:600}
.badge.e1{background:#1f5f3a;color:#c8f7d6}.badge.e2{background:#5a4f1a;color:#fbeaa6}.badge.e3{background:#5f2f1f;color:#ffd6c8}.badge.e4{background:#3a3a3a;color:#ddd}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:14px 0 20px}
.card{background:var(--bg2);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.card .v{font-size:24px;font-weight:700;color:var(--acc)}.card .l{font-size:12.5px;color:var(--muted)}
.charts{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:16px;margin:10px 0 24px}
.chart{background:var(--bg2);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.chart h4{margin:0 0 6px;color:var(--fg)}.chart .note{font-size:12px;color:var(--muted);margin-top:4px}
svg text{fill:var(--muted);font-size:11px;font-family:inherit}svg .lbl{fill:var(--fg)}svg .grid{stroke:var(--line);stroke-width:1}
.legend{display:flex;flex-wrap:wrap;gap:10px;font-size:12px;color:var(--muted);margin-top:6px}.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:-1px}
.path{color:var(--acc2);font-family:ui-monospace,Menlo,monospace;font-size:13px}
.src{font-size:12.5px;color:var(--muted)}
details{margin:.6em 0}summary{cursor:pointer;color:var(--acc)}
@media (max-width:640px){.charts{grid-template-columns:1fr}main{padding:14px 12px}}
"""

JS = r"""
const D = window.__DATA__;
function el(t,a={},...c){const e=document.createElementNS('http://www.w3.org/2000/svg',t);for(const k in a)e.setAttribute(k,a[k]);c.forEach(x=>e.append(x));return e;}
function svgBox(w,h){const s=el('svg',{viewBox:`0 0 ${w} ${h}`,width:'100%',preserveAspectRatio:'xMinYMin meet'});return s;}
const COLORS=['#7cc4ff','#ffb86b','#b48cff','#6fdd8b','#ff7b7b','#59d3c9','#f6e58d','#a0a0a0'];
function fmt(n){if(n>=1e6)return (n/1e6).toFixed(1)+'M';if(n>=1e3)return Math.round(n/1e3)+'k';return String(n);}
// stacked/grouped bars by category on X
function stackedBars(container, cats, series, opts={}){
  const W=560,H=240,pl=48,pr=10,pt=14,pb=42;const s=svgBox(W,H);
  const totals=cats.map((_,i)=>series.reduce((a,sr)=>a+(sr.data[i]||0),0));
  const max=Math.max(1,...(opts.stack?totals:series.flatMap(sr=>sr.data)));
  const bw=(W-pl-pr)/cats.length;const y=v=>pt+(H-pt-pb)*(1-v/max);
  for(let g=0;g<=4;g++){const v=max*g/4;s.append(el('line',{x1:pl,x2:W-pr,y1:y(v),y2:y(v),class:'grid'}));s.append(el('text',{x:pl-6,y:y(v)+4,'text-anchor':'end'},opts.fmt?opts.fmt(v):fmt(Math.round(v))));}
  cats.forEach((c,i)=>{let acc=0;const n=series.length;series.forEach((sr,k)=>{const v=sr.data[i]||0;let x,w,y0,y1;
    if(opts.stack){x=pl+i*bw+bw*.15;w=bw*.7;y0=y(acc+v);y1=y(acc);acc+=v;}else{w=bw*.8/n;x=pl+i*bw+bw*.1+k*w;y0=y(v);y1=y(0);}
    const r=el('rect',{x,y:y0,width:Math.max(0,w),height:Math.max(0,y1-y0),fill:sr.color||COLORS[k%8],rx:1});r.append(el('title',{},`${c} — ${sr.name}: ${fmt(v)}`));s.append(r);});
    s.append(el('text',{x:pl+i*bw+bw/2,y:H-pb+14,'text-anchor':'middle'},opts.short?String(c).replace('2026-',''):String(c)));
    if(opts.stack&&opts.showTotal)s.append(el('text',{x:pl+i*bw+bw/2,y:y(totals[i])-3,'text-anchor':'middle',class:'lbl'},fmt(totals[i])));});
  container.append(s);
  if(series.length>1){const lg=document.createElement('div');lg.className='legend';series.forEach((sr,k)=>{lg.innerHTML+=`<span><i style="background:${sr.color||COLORS[k%8]}"></i>${sr.name}</span>`;});container.append(lg);}
}
function hbars(container, items, opts={}){
  const W=560,rowH=20,pl=opts.pl||170,pr=50,pt=6;const H=pt+items.length*rowH+8;const s=svgBox(W,H);
  const max=Math.max(1,...items.map(i=>i.v));
  items.forEach((it,i)=>{const yy=pt+i*rowH;const w=(W-pl-pr)*it.v/max;
    s.append(el('text',{x:pl-8,y:yy+14,'text-anchor':'end',class:'lbl'},it.k));
    const r=el('rect',{x:pl,y:yy+3,width:Math.max(0,w),height:rowH-7,fill:it.color||COLORS[0],rx:2});r.append(el('title',{},`${it.k}: ${it.v}`));s.append(r);
    s.append(el('text',{x:pl+w+5,y:yy+14},opts.fmt?opts.fmt(it.v):fmt(it.v)));});
  container.append(s);
}
function chart(id,title,note){const c=document.getElementById(id);const h=document.createElement('h4');h.textContent=title;c.append(h);const box=document.createElement('div');c.append(box);if(note){const n=document.createElement('div');n.className='note';n.textContent=note;c.append(n);}return box;}
document.addEventListener('DOMContentLoaded',()=>{
  // tabs
  const btns=[...document.querySelectorAll('nav button')],tabs=[...document.querySelectorAll('section.tab')];
  function show(id){btns.forEach(b=>b.classList.toggle('active',b.dataset.tab===id));tabs.forEach(t=>t.classList.toggle('active',t.id===id));history.replaceState(null,'','#'+id);window.scrollTo(0,0);}
  btns.forEach(b=>b.addEventListener('click',()=>show(b.dataset.tab)));
  show(location.hash&&document.getElementById(location.hash.slice(1))?location.hash.slice(1):'usage');
  const W=D.weeks;
  // 1 prompts by week/group
  let b=chart('c-prompts','Промты по неделям и группам проектов','hooks/prompts.jsonl + history.jsonl; work = ~/dev/work, personal = ~/dev/personal, pkm = lifeOS, meta = my-claude-config');
  const grps=['work','personal','pkm','meta'];
  stackedBars(b,W,grps.map((g,k)=>({name:g,data:W.map(w=>(D.prompts_by_week_group[w]||{})[g]||0),color:COLORS[k]})),{stack:true,short:true,showTotal:true});
  // 2 tokens
  b=chart('c-tokens','Output-токены по неделям и группам','stops.jsonl, дельты кумулятивных стопов; включает субагентов');
  stackedBars(b,W,grps.map((g,k)=>({name:g,data:W.map(w=>(D.tokens_by_week_group[w]||{})[g]||0),color:COLORS[k]})),{stack:true,short:true,showTotal:true});
  // 3 task types
  b=chart('c-tasks','Типы задач (new-task постановки, n='+D.tasks.n_new_task+')','Классификатор по ключевым словам, ~60% точность на мелких категориях; крупные пропорции устойчивы');
  const ta=Object.entries(D.tasks.all).sort((a,b)=>b[1]-a[1]);
  hbars(b,ta.map(([k,v],i)=>({k,v,color:k==='other'?'#555':k==='pkm-notes'?COLORS[2]:['new-code','boilerplate','refactor','sql','sonar-fix','config-yaml','git-ops','test'].includes(k)?COLORS[3]:['planning-arch','explain-code','google-replace','research','docs'].includes(k)?COLORS[1]:COLORS[0]})),{pl:120});
  const lg=document.createElement('div');lg.className='legend';lg.innerHTML=`<span><i style="background:${COLORS[3]}"></i>код</span><span><i style="background:${COLORS[1]}"></i>анализ / решение / вопрос</span><span><i style="background:${COLORS[0]}"></i>ревью, отладка, конфиг</span><span><i style="background:${COLORS[2]}"></i>pkm</span><span><i style="background:#555"></i>other</span>`;b.append(lg);
  // 4 hours
  b=chart('c-hours','Промты по часам суток (Asia/Bishkek)','Пики 10–13 и 15–17; ночь 22–06 = '+D.time_flags.late_share_pct+'%');
  const hrs=Object.keys(D.hour_hist).map(Number).sort((a,b)=>a-b);
  stackedBars(b,hrs,[{name:'промты',data:hrs.map(h=>D.hour_hist[h]),color:COLORS[0]}],{stack:true});
  // 5 weekday
  b=chart('c-wd','Промты по дням недели','Выходные = '+D.time_flags.weekend_share_pct+'% промтов, но именно там pkm/DIY-марафоны');
  const wdn=['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];stackedBars(b,wdn,[{name:'промты',data:[1,2,3,4,5,6,7].map(d=>D.weekday_hist[d]||0),color:COLORS[5]}],{stack:true});
  // 6 corrections
  b=chart('c-corr','Коррекции по неделям, % реплик','W26–W28: из 69 коррекций 30 — «напиши на русском» (эксперимент с языком чата); без них 3–9%/нед');
  stackedBars(b,W,[{name:'% коррекций',data:W.map(w=>D.corrections_by_week[w].share_pct),color:COLORS[4]}],{stack:true,short:true,fmt:v=>v.toFixed(0)+'%'});
  // 7 sessions histogram
  b=chart('c-sess','Промтов на сессию (212 сессий; 20 = 20+)','Медиана 3, p90 16; 24.5% сессий из одного промта');
  const hp=D.sessions_hooks.hist_prompts;const hk=Object.keys(hp).map(Number).sort((a,b)=>a-b);
  stackedBars(b,hk,[{name:'сессий',data:hk.map(k=>hp[k]),color:COLORS[2]}],{stack:true});
  // 8 subagents
  b=chart('c-agents','Субагенты (Agent tool, окно)','692 вызова в 127 из 212 сессий; migration-reviewer 2, test-writer 4, prompt-auditor 4');
  hbars(b,Object.entries(D.tools.agents).filter(([k])=>k!=='?').map(([k,v])=>({k,v,color:COLORS[1]})),{pl:140});
  // 9 skills loads
  b=chart('c-skills','Загрузки skills в транскриптах: главный агент vs субагенты','101 сессия транскриптов; главный агент 9 загрузок, субагенты 158');
  const sk={};for(const [k,v] of Object.entries(D.tools.skill_loads_main_tr))sk[k]=(sk[k]||0)+v;for(const [k,v] of Object.entries(D.tools.skill_loads_sub_tr))sk[k]=(sk[k]||0)+v;
  const skk=Object.keys(sk).sort((a,b)=>sk[b]-sk[a]);
  stackedBars(b,skk,[{name:'главный агент',data:skk.map(k=>D.tools.skill_loads_main_tr[k]||0),color:COLORS[0]},{name:'субагенты',data:skk.map(k=>D.tools.skill_loads_sub_tr[k]||0),color:COLORS[2]}],{stack:true});
  // 10 slash
  b=chart('c-slash','Slash-команды за окно','Мертвы за всё время: '+D.tools.dead_commands_ever.join(', '));
  hbars(b,Object.entries(D.tools.slash).map(([k,v])=>({k:'/'+k,v,color:COLORS[5]})),{pl:120});
  // 11 skill risk by week
  b=chart('c-risk','Риск-делегирование по неделям (постановки, work+personal)','analysis-first = «проведи анализ …»; architecture-decision; debug-root-cause; unfamiliar-code');
  const rk=['analysis-first','architecture-decision','debug-root-cause','unfamiliar-code'];
  stackedBars(b,W,rk.map((k,i)=>({name:k,data:W.map(w=>D.skill_risk.by_week[w][k]||0),color:COLORS[i]})),{stack:true,short:true,showTotal:true});
  // 12 hypothesis baseline
  b=chart('c-hyp','Baseline rule 08: постановки со своей гипотезой/вариантом','debug: '+D.hypothesis_share.debug.with_hypothesis+' из '+D.hypothesis_share.debug.n+'; design: '+D.hypothesis_share.design.with_hypothesis+' из '+D.hypothesis_share.design.n);
  stackedBars(b,W,[{name:'debug без гипотезы',data:W.map(w=>D.hypothesis_share.by_week[w].debug_n-D.hypothesis_share.by_week[w].debug_h),color:COLORS[4]},{name:'debug с гипотезой',data:W.map(w=>D.hypothesis_share.by_week[w].debug_h),color:COLORS[3]},{name:'design без варианта',data:W.map(w=>D.hypothesis_share.by_week[w].design_n-D.hypothesis_share.by_week[w].design_h),color:COLORS[1]},{name:'design с вариантом',data:W.map(w=>D.hypothesis_share.by_week[w].design_h),color:COLORS[5]}],{stack:true,short:true});
});
"""


def build(out_dir: str) -> str:
    md = {}
    for n in ("01-usage-audit", "02-sources", "03-research", "04-config-changes", "05-growth", "06-trajectory"):
        with open(os.path.join(out_dir, n + ".md"), encoding="utf-8") as fh:
            md[n] = fh.read()
    with open(os.path.join(out_dir, "data", "metrics.json"), encoding="utf-8") as fh:
        M = json.load(fh)
    keep = {k: M[k] for k in ("weeks", "totals", "volume_by_week", "prompts_by_week_group", "tokens_by_week_group",
                              "by_group", "tasks", "hour_hist", "weekday_hist", "time_flags", "corrections_by_week",
                              "sessions_hooks", "tools", "skill_risk", "hypothesis_share", "by_project")}
    keep["tools"] = {k: M["tools"][k] for k in ("agents", "slash", "dead_commands_ever", "skill_loads_main_tr", "skill_loads_sub_tr", "counts")}
    data_js = json.dumps(keep, ensure_ascii=False).replace("</", "<\\/")

    t = M["totals"]
    cards = [
        (str(t["prompts"]), "промтов за 9 недель"), (str(t["sessions"]), "сессий с промтом"),
        (f"{t['tokens_out']/1e6:.0f}M", "output-токенов"), (f"{t['active_days']}/{t['calendar_days']}", "активных дней"),
        (f"{M['sessions_hooks']['prompts_median']:.0f} / {M['sessions_hooks']['prompts_p90']:.0f}", "промтов на сессию (медиана / p90)"),
        (f"{M['kinds']['correction']}", "коррекций (7.9%)"),
        (f"{M['skill_risk']['any_risk_pct']}%", "постановок с риск-делегированием"),
        (f"{M['hypothesis_share']['debug']['with_hypothesis']}/{M['hypothesis_share']['debug']['n']}", "отладочных постановок с гипотезой"),
    ]
    cards_html = '<div class="cards">' + "".join(f'<div class="card"><div class="v">{v}</div><div class="l">{l}</div></div>' for v, l in cards) + "</div>"
    chart_ids = ["c-prompts", "c-tokens", "c-tasks", "c-risk", "c-hyp", "c-corr", "c-hours", "c-wd", "c-sess", "c-agents", "c-skills", "c-slash"]
    charts_html = '<div class="charts">' + "".join(f'<div class="chart" id="{c}"></div>' for c in chart_ids) + "</div>"

    note = ('<p class="src">Карточки и графики пересчитываются при сборке из логов (в т.ч. промты текущей сессии аудита попадают в '
            'проект my-claude-config), поэтому могут отличаться от текста фаз на несколько единиц. Текст фаз — снимок на момент написания.</p>')
    usage_html = cards_html + note + charts_html + "<h2>Полный текст аудита (фаза 1)</h2>" + md_to_html(md["01-usage-audit"])
    sources_html = md_to_html(md["02-sources"])
    research_html = badge_levels(md_to_html(md["03-research"]))
    research_html = ('<p class="src">Уровни: <span class="badge e1">E1</span> RCT / мета-анализ · <span class="badge e2">E2</span> квази-эксперимент / наблюдательное с контролем · '
                     '<span class="badge e3">E3</span> корреляция / самоотчёт · <span class="badge e4">E4</span> телеметрия / отчёт компании. Раздел B — слабые свидетельства.</p>' + research_html)
    config_html = md_to_html(md["04-config-changes"])
    extra = os.path.join(out_dir, "07-docs-and-process.md")
    if os.path.exists(extra):
        with open(extra, encoding="utf-8") as fh:
            config_html += "<hr>" + md_to_html(fh.read())
    growth_html = md_to_html(md["05-growth"])
    traj_html = md_to_html(md["06-trajectory"])

    tabs = [("usage", "Использование", usage_html), ("sources", "Источники", sources_html), ("research", "Ресёрч", research_html),
            ("config", "Конфигурация", config_html), ("growth", "Рост", growth_html), ("trajectory", "Траектория", traj_html)]
    nav = "".join(f'<button data-tab="{i}">{n}</button>' for i, n, _ in tabs)
    secs = "".join(f'<section class="tab" id="{i}">{h}</section>' for i, _, h in tabs)
    page = f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Аудит использования ИИ — август 2026</title>
<style>{CSS}</style></head>
<body><header><h1>Аудит ИИ-использования · 2026-06-15 → 2026-08-16</h1><nav>{nav}</nav></header>
<main>{secs}</main>
<script>window.__DATA__={data_js};</script>
<script>{JS}</script>
</body></html>"""
    path = os.path.join(out_dir, "report.html")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(page)
    return path


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="docs/audit-2026-08", help="каталог с 01–07*.md и data/metrics.json")
    a = ap.parse_args()
    p = build(a.out)
    print("wrote", p, os.path.getsize(p) // 1024, "KB")

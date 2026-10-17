# Session doc template — game memory lab

Copy this file per session into `D:\opencode\game-lab\reports\<game>_<session>.md`.

```markdown
# Session: <game or bench> — <mechanic being researched>
date: <date> | build: <game build number> | operator tools: <list>

## Hypothesis (falsifiable)
1. <The displayed HP is a float at Object+0xDC.>
2. Falsifier: <damaging the player does not change the candidate → discard.>

## Method
1. scan (<Cheat Engine | cheat-mcp scan_value/scan_aob | bench_memprobe>): candidates, filters used
2. narrowing: <actions in game and resulting deltas, times>
3. owner struct: <pointer scan / Il2CppDumper dump.cs names / ReClass>
4. writer: <CE "find what writes" | x64dbg bph | REA decompilation + address>
5. stable form: <module+RVA / pointer chain>

## Evidence (each row must cite a tool result)
| time | action | expected | observed | verdict |
| ---- | ------ | -------- | -------- | ------- |

## Verdict
- confirmed / refuted / unknown: <state>
- what survived restart: <base?>, <module+RVA?>
- writer function: <VA + decompiled snippet>
- open questions
```

Rules of use:
- every "confirmed" needs TWO independent instruments to agree (see re-veteran-mindset).
- absolute VAs are session-local; document module+RVA or a pointer chain.
- a value found once and never re-verified is a rumor, not an offset.

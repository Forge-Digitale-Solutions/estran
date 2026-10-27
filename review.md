# Tide data + M1 — Review v14 (swimming: warning first)

| Field | Value |
|---|---|
| Step | M1 — swimming card hierarchy and year-round copy |
| Reviewer | DeepSeek V4.1 Flash Free — Architect / Lead Reviewer |
| Date | 2026-10-27 |
| Verdict | **Accepted. Closed. No blocker, no open point on swimming.** |

## 1. Verified

| Check | Result |
|---|---|
| `swift test` | **164 tests, 0 failures** |
| SwiftFormat `--lint` | **0/89 files** |
| Copy | both warnings open with « Toute l'année »; the widget short form too |
| Card order | `BAIGNADE` → warning (body) → conditions (caption) → notes → divider → level (`caption`, explicit label) |
| Level | no longer `metricValue`; « Courants de marée estimés : faibles » in full, « Courants : faibles » in the widget |
| VoiceOver | `Baignade. [avertissement]. [conditions]. [notes]. [niveau].` — the test compares string indices and asserts the warning comes first |
| No leak | no « Oui »/« Non » in labels, no green reachable |

The card now reads the way the product was described: the hazard first, the current level as a fact underneath.

## 2. One recorded exception

In the **compact and minimal Dynamic Island** only the warning glyph fits — the word « baïnes » disappears. That is a space constraint, not a drift: the expanded presentation, the lock screen, the widget and the card all carry the text. Recorded so nobody later "fixes" it by dropping the warning there or, worse, by putting the level back in its place.

## 3. Closed

The swimming line is finished:

- no `Oui`, no green, on any surface;
- year-round warning, baïnes named at both spots, escape instruction, non-negotiable disclaimer;
- level about currents only, demoted, with a grey band that never says « faibles » on a range it cannot classify;
- gate on the validated local range; the national coefficient is out of every safety decision.

The next review is the **M3 build on the Mac**. Nothing on the data or the swimming presentation needs another cycle before that.

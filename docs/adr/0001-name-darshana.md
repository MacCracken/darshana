# ADR 0001 — Project name: `darshana`

**Status**: Accepted
**Date**: 2026-05-09
**Deciders**: project owner

## Context

A new shared library was needed to host TTY/raw-mode primitives once a second AGNOS first-party tool (chakshu) needed the same machinery cyim was already carrying privately as `cyim/src/tty.cyr`. The extraction was triggered by chakshu entering its M2 (Full TUI) milestone — see [chakshu/docs/development/roadmap.md](https://github.com/MacCracken/chakshu/blob/main/docs/development/roadmap.md) §M2 "Pre-M2 — TTY/termios lib extraction".

Per the AGNOS sovereign-stack naming convention, project names sit in the Sanskrit/agnostic-philosophy registry and are non-negotiable identity. The chakshu roadmap pre-staged two candidates from the observation/sense family — `darshana` (दर्शन) and `drishya` (दृश्य) — both fitting next to chakshu (चक्षु — *the eye*) and the planned `drishti-*` codecs (दृष्टि — *vision*).

Three candidates were on the table:

1. **`darshana`** (दर्शन) — *viewing / showing / sight*. The act/faculty. The six *darshanas* of Indian philosophy are "ways of seeing" — the discipline of presenting to the eye. Reads as "the viewing protocol."
2. **`drishya`** (दृश्य) — *visible / scene*. The noun: the artifact, the thing on screen.
3. **Other observation-family options** — `pradarshan` (प्रदर्शन — exhibition), `mukha` (मुख — face/surface), `pratima` (प्रतिमा — image/reflection).

## Decision

**Ship as `darshana`.**

Rationale:

1. **Discipline framing fits a primitives library.** darshana is the *act of presenting* — the protocol/discipline by which a tool shows itself to the eye. drishya is the *artifact* (what's on screen). A primitives library that owns termios/ANSI/cursor is closer to the discipline than the artifact — the consumer (chakshu/cyim) produces the artifact; the library provides the discipline.
2. **Philosophical resonance.** The six classical *darshanas* (Nyaya, Vaisheshika, Samkhya, Yoga, Mimamsa, Vedanta) are the recognized *systems of viewing reality* in Sanskrit thought — the "ways of seeing." A library named after this carries the connotation of a structured, principled approach to display, which fits an AGNOS sovereign-stack primitive.
3. **Sound and length.** Three syllables (`dar-sha-na`), ends on a vowel, easy to say. Slightly more grounded-sounding than the lighter `drishya` (two syllables, sharper).
4. **Family fit.** Slots cleanly with `chakshu` (the eye), `drishti-*` (vision), without overlapping their semantic ground. chakshu is the organ; drishti is the faculty; darshana is the act/discipline; drishya is the object — all distinct, all in the same family.

`drishya` was strong but lost on point 1 — for a *library*, the discipline framing reads more naturally than the artifact framing.

`pradarshan` / `mukha` / `pratima` were considered briefly and rejected: pradarshan ("exhibition") is too theatrical; mukha ("face") drifts toward "interface" / API connotations that aren't accurate (darshana is below the API layer); pratima ("image / reflection") leans static where TTY is dynamic.

## Consequences

- `cyrius.cyml [package].name = "darshana"`.
- README, CHANGELOG, CLAUDE.md, design docs all reference `darshana` as the project name.
- The dist module is `dist/darshana.cyr`, consumers `include "lib/darshana.cyr"` after `cyrius deps`.
- The shared-crates registry entry uses `darshana`.
- No fallback / trigger conditions tracked — the choice is clean.

## References

- README §What it is
- chakshu roadmap §M2 "Pre-M2 — TTY/termios lib extraction"
- Donor: [`cyim/src/tty.cyr`](https://github.com/MacCracken/cyim)

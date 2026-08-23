# Architecture Decision Records

Decisions about darshana — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-name-darshana.md) | The library is named `darshana` (दर्शन — *viewing/showing*), not `drishya` or another observation-family alternative | Accepted |
| [0002](0002-state-restore-posture.md) | darshana provides the state-restore *primitives*; the consumer owns the teardown guarantee. No library-installed atexit, no signal handlers, no `tty_guard(fp)` wrapper | Accepted (amended v0.7.0) |
| [0003](0003-v1-api-freeze.md) | The v1.0 API freeze — the 29 functions and 37 constants it covers, what it explicitly does not cover, and the post-1.0 semver policy | Accepted |

_This index was empty through v0.9.4 while two ADRs sat on disk; keep it current when adding one._

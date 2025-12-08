# SilentX Feature Constitution

## Core Principles (NON-NEGOTIABLE)

1. **User Consent & Least Privilege**: Any elevated action must use macOS-standard authorization UI; never cache passwords; run only the minimum privileged helper required.
2. **Deterministic Repro & Tests**: Each feature must ship with reproducible steps and automated tests for startup, error surfacing, and teardown; regressions must be caught in CI.
3. **Explicit Error Transparency**: User-facing errors must be actionable and human-readable; logs must include underlying stdout/stderr for debugging.
4. **Modular Engines**: Proxy engines (sudo process vs Network Extension) must remain swappable behind `ProxyEngine`; no UI or service may hardwire a single engine.

## Additional Constraints

- Security review is mandatory for any privileged helper or Network Extension change.
- Startup/teardown must leave the system network in a clean state (no stray TUN, no orphaned processes).
- Configuration validation must run before attempting privileged actions.

## Development Workflow

- Requirements → plan → tasks must align with the chosen privilege strategy (sudo-first unless explicitly changed).
- Blocking tasks must be completed before user-story work that depends on them; do not bypass Phase gates.
- Tests for critical flows (connect, disconnect, error surfacing) must be added alongside code changes.

## Governance

- This constitution supersedes prior templates; deviations require an explicit amendment with rationale.
- Version: 1.0.0 | Ratified: 2025-12-07 | Last Amended: 2025-12-07

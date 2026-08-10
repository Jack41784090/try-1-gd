# CONDOR — Copilot Workspace Instructions

Source of truth for project overview, architecture, conventions, key enums, and file organization is [AGENTS.md](../AGENTS.md) — read that first.

For detailed architecture of each subsystem, see file-specific instructions (auto-loaded when editing relevant files). For testing, interactive play, and animation workflows, use the `/condor-testing`, `/condor-play`, and `/condor-animation` skills.

## Customization Workflow

- Do not default to directly editing existing instruction files for every change.
- Choose customization type dynamically based on scope:
	- Add or update a skill (`.github/skills/<name>/SKILL.md`) for reusable multi-step workflows.
	- Create new directories under `.github/skills/` or `.github/instructions/` when introducing a new domain or workflow.
	- Edit an existing instruction file directly only when the rule belongs to that file's current scope.
- Prefer modular additions over growing a single monolithic instruction file.

## Architectural Docs Sync (Obsidian)

- When changing architecture, runtime flow, data contracts, or behavior in code, update the corresponding notes in `/home/ikec/Documents/schwarzwagen/CONDOR/Systems/` in the same task.
- Keep hub and navigation notes coherent when system boundaries or edges change: `Systems.md`, `Graph Seed.md`, and relevant `!index.md` notes.
- Subsystem mapping:
	- `src/strategy/**` -> `Systems/Core/`, `Systems/Activities/`, `Systems/AI/`, `Systems/Contact/`, `Systems/Runtime/`, `Systems/UI/`, `Systems/Data/Strategy Types.md`
	- `src/squad_battle/**` and combat bridge flow -> `Systems/Combat/`, `Systems/Data/Combat Types.md`, `Systems/Runtime/Combat Flow.md`
	- `src/economy/**` -> `Systems/Economy/`, `Systems/Runtime/Economy Tick 24h.md`
- Do not leave architectural docs stale after code changes.

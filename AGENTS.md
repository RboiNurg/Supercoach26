# AGENTS.md

## Purpose

This repo is an NRL SuperCoach decision and strategy tool built around a single Shiny app in `app.R`, refreshed league data under `data/supercoach_league_21064`, and operational scripts under `scripts/`.

The goal is not generic dashboards. The goal is reliable SuperCoach decision support:

- stronger weekly trade and captaincy decisions
- better head-to-head opponent reads
- better mid-term planning across the next few rounds
- explainable outputs tied back to SuperCoach scoring logic and league behaviour

## Working Style

Treat this repo like a live strategy product with brittle workflow edges.

- Inspect before editing.
- Prefer the smallest change consistent with the current pattern.
- Do not broad-refactor unless explicitly asked.
- Preserve deployed app behaviour outside the task scope.
- If a task touches planner or trade logic, verify state transitions, not just rendered tables.

## Repo Layout

- `app.R`
  Main Shiny app entry point. UI, server, helper functions, planner logic, trade tables, finance logic, and output rendering all currently live here.
- `scripts/`
  Refresh, export, alerting, storage reset, manifest writing, and smoke-check scripts.
- `data/supercoach_league_21064/`
  Bundled data snapshot consumed by the app and refresh pipeline.
- `docs/`
  Operational setup and development workflow docs.
- `README.md`
  High-level project overview.
- `supercoach_data_lookup_build_checklist.md`
  Checklist/spec notes. Use this when tasking planner or lookup-table changes.

## R / Shiny Conventions

- Prefer tidyverse style already used in the repo.
- Use `%>%`, not `|>`.
- Return tibbles where practical.
- Keep function names lowercase with underscores.
- Prefer explicit `select()`, `mutate()`, `summarise()`, `arrange()` chains.
- Do not introduce base-R alternatives when existing code uses dplyr/tidyr style.
- Keep reactive expressions thin when possible.
- Keep heavy data shaping outside `render*` blocks when practical.
- Preserve output IDs and input IDs unless the task explicitly requires a UI contract change.
- Preserve current reactive flow unless the task is specifically architectural.
- Avoid adding `library()` calls unless required.
- Add comments sparingly and only when they clarify non-obvious logic.

## Editing Guardrails

- Do not rename unrelated functions, outputs, or inputs.
- Do not opportunistically re-theme the app.
- Do not move data loading into global scope unless explicitly requested.
- Do not silently change planner rules, trade semantics, or reserve semantics without validating the downstream tables.
- Never assume a rendered table is correct if the state-machine path is illegal.

## Planner-Specific Rules

The rolling lockout planner is the most fragile part of the repo.

When changing planner logic:

- The final intended counting side is the fixed target unless the task explicitly changes selection logic.
- Bench order matters because reserve markers inherit by bench tile.
- Captain and VC markers inherit by tile when swaps occur.
- Once a player locks on field, that field state must be treated as frozen.
- Once a bench player locks with reserve on/off, that reserve state must be treated as frozen.
- A move schedule is only valid if it could be executed one action at a time in the real app.

Always test planner changes against the canonical smoke case:

- `Walsh, Reece -> Edwards, Dylan`

And explicitly look for:

- illegal reserve count drift
- reserve off/on applied to the wrong player
- a locked player being moved later
- captaincy inheriting onto the wrong player after a swap
- final reserve four not matching the intended objective

## Verification

Minimum verification for ordinary code changes:

1. Parse the app:
   - `Rscript -e 'invisible(parse(file="app.R")); cat("parse ok\\n")'`
2. Run the smoke-check script:
   - `Rscript scripts/smoke_check_app.R`

For planner changes also:

1. Republish or reload the deployed app.
2. Run the `Walsh -> Edwards` planner scenario.
3. Inspect:
   - `Suggested Captain / VC Combos`
   - `Bogus Starting Setup`
   - `Exact Move Schedule`
   - `Final Intended Counting Side`
4. Confirm the move schedule obeys lockout and inheritance rules.

## Good Task Prompt Shape

Use this structure when asking for code changes:

- `Goal:` what should be built or fixed
- `Context:` which files/functions/tabs matter
- `Constraints:` coding style, what not to touch
- `Output:` exact files to edit/create
- `Verification:` commands to run and what success looks like

Example:

```text
Goal:
Fix the planner reserve logic so reserve markers inherit by bench tile.

Context:
app.R only. Focus on planner state and move schedule generation.

Constraints:
Do not redesign the planner UI.
Do not change scoring weights.
Preserve current table column names.

Output:
Edit app.R.

Verification:
Rscript -e 'parse(file="app.R"); cat("parse ok\\n")'
Rscript scripts/smoke_check_app.R
Then run Walsh -> Edwards and confirm no illegal reserve drift.
```

## Preferred Collaboration Loop

For non-trivial work:

1. Inspect relevant files first.
2. Summarise the current pattern and the smallest likely change.
3. Implement.
4. Run verification.
5. Report:
   - what changed
   - what was verified
   - what still needs manual app validation

## What “Done” Means

A task is not done just because code was edited.

It is done when:

- the requested behaviour is implemented
- the app parses cleanly
- the relevant smoke checks pass
- any known residual risk is explicitly called out

---
title: "SuperCoach Table Validation Guide"
output: html_document
---

## Purpose

This report is a table-by-table guide.

For each saved `.rds` table it tells you:

- what the table is
- how we derived it
- what it is supposed to mean
- what source to compare it against
- how many rows it currently has
- a small sample of rows to inspect

The goal is to make spot-checking practical instead of forcing you to reverse-engineer the production Rmd.

## Setup



## Configuration



## Helpers



## Load Tables



## Run Snapshot


|field                         |value                    |
|:-----------------------------|:------------------------|
|current_round                 |6                        |
|effective_current_round_audit |6                        |
|next_round                    |7                        |
|settings_current_round        |5                        |
|settings_next_round           |6                        |
|round_inference_source        |nrl_fixture_completion   |
|round_closed_through_utc      |2026-04-06 09:05:00      |
|last_refresh_run_ts           |2026-04-08 00:16:20 AEST |

## Table Summary


```
## Error in `tribble()`:
## ! Data must be rectangular.
## • Found 11 columns.
## • Found 439 cells.
## ℹ 439 is not an integer multiple of 11.
```

```
## Error in mutate(., row_count = map_int(table_name, ~obj_row_count(objects[[.x]])), : object 'table_registry' not found
```

```
## Error in kable(table_summary, caption = "All saved tables at a glance"): object 'table_summary' not found
```

## How To Use This Report

1. Start with `game_rules_round_state`, `source_refresh_log`, and `competition_state_history`.
2. Then check the public-source tables:
   - `nrl_fixture_source_history`
   - `nrl_team_context_history`
   - `fixture_matchup_table`
   - `team_performance_context`
3. Then check mutable SuperCoach player tables:
   - `players_cf_latest`
   - `availability_risk_table`
   - `team_list_role_certainty`
4. Then check decision tables:
   - `master_player_round_latest`
   - `cash_generation_model`
   - `squad_round_enriched`
   - `structure_health_table`
   - `long_horizon_planning_table`

If one looks wrong, use the “Spot-check against” line in that section and compare a few rows manually.

## Table-by-Table Guide


```
## Error in split(table_registry, seq_len(nrow(table_registry))): object 'table_registry' not found
```

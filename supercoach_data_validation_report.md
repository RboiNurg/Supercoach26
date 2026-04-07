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
|current_round                 |5                        |
|effective_current_round_audit |6                        |
|next_round                    |6                        |
|settings_current_round        |NA                       |
|settings_next_round           |NA                       |
|round_inference_source        |NA                       |
|round_closed_through_utc      |2026-04-06 09:05:00      |
|last_refresh_run_ts           |2026-04-07 18:34:22 AEST |

## Table Summary


|table_name                       |category         |default_status | row_count|latest_run               | duplicate_key_groups|meaning                                                                                      |
|:--------------------------------|:----------------|:--------------|---------:|:------------------------|--------------------:|:--------------------------------------------------------------------------------------------|
|competition_state_history        |source log       |source_layer   |         8|2026-04-07 18:34:22 AEST |                    0|Historical record of what the competition settings endpoint said at each refresh.            |
|source_refresh_log               |source log       |source_layer   |         8|2026-04-07 18:34:22 AEST |                    0|Quick audit trail for what the pipeline refreshed on each run.                               |
|run_log                          |source log       |source_layer   |        10|2026-04-07 18:34:22 AEST |                    0|Operational log showing what changed and how much work the run did.                          |
|ladder_history                   |source log       |source_layer   |       264|2026-04-07 18:34:22 AEST |                    0|Historical SuperCoach league ladder snapshots.                                               |
|fixtures_history                 |source log       |source_layer   |       180|2026-04-07 18:34:22 AEST |                    0|Historical SuperCoach matchup schedule and current live scores.                              |
|team_round_stats_history         |source log       |source_layer   |       264|2026-04-07 18:34:22 AEST |                    0|Historical team-level points, price, change count, and boosts used.                          |
|team_players_snapshots           |source log       |source_layer   |      1560|2026-04-07 16:52:53 AEST |                    0|Historical record of who was in each squad snapshot.                                         |
|team_round_signatures            |source log       |source_layer   |        60|2026-04-07 16:52:53 AEST |                    0|Change-detection layer that decides whether a new roster snapshot is needed.                 |
|team_players_latest              |base latest view |source_layer   |      1560|2026-04-07 16:52:53 AEST |                    0|Current best-known roster for each SuperCoach team and round.                                |
|actual_trade_history             |source log       |source_layer   |         9|2026-04-07 16:52:53 AEST |                    0|Confirmed trade events where the source API exposes the trade pair.                          |
|inferred_changes                 |source log       |source_layer   |        60|NA                       |                    0|Best-effort inferred trade/change history for league opponents.                              |
|players_cf_history               |source log       |source_layer   |       558|2026-04-07 17:26:52 AEST |                    0|History of player availability, lock, and status changes.                                    |
|players_cf_latest                |base latest view |source_layer   |       558|2026-04-07 17:26:52 AEST |                    0|Current best-known player availability/lockout state.                                        |
|player_history_refresh_log       |source log       |source_layer   |      2096|2026-04-07 18:34:22 AEST |                    0|Audit trail for why a player's external price history was re-pulled.                         |
|player_price_history_2026        |source log       |source_layer   |     14170|NA                       |                    0|External price/score/minutes history keyed by player name.                                   |
|players_cf_2026                  |helper table     |source_layer   |       558|2026-04-07 17:26:52 AEST |                    0|Convenience copy of the current player catalog.                                              |
|player_id_lookup                 |helper table     |source_layer   |       558|NA                       |                    0|Helper lookup from player_id to name/team.                                                   |
|player_price_history_sc          |base latest view |source_layer   |     14196|NA                       |                    0|Canonical player score/minutes/price history keyed by player_id.                             |
|nrl_fixture_source_history       |source log       |source_layer   |      1054|2026-04-07 18:34:22 AEST |                    0|Historical official NRL fixture source used for matchup logic and round inference.           |
|nrl_team_context_history         |source log       |source_layer   |       255|2026-04-07 18:34:22 AEST |                    0|Historical official NRL ladder/context source for trend and ladder joins.                    |
|fixture_triggers                 |derived output   |partial        |         1|2026-04-07 18:34:22 AEST |                    0|Small trigger table showing the active round window and lockout timing.                      |
|game_rules_round_state           |derived output   |partial        |         1|2026-04-07 18:34:22 AEST |                    0|Current operating state of the game for the dashboard and GPT pack.                          |
|master_player_round_latest       |derived output   |partial        |       558|2026-04-07 17:26:52 AEST |                    0|Main current-player master table used for market and squad analysis.                         |
|player_scoring_component_history |derived output   |partial        |     14196|2026-04-07 18:34:22 AEST |                    0|History table of scoring-related rollups; most detailed components are still unavailable.    |
|team_list_role_certainty         |derived output   |partial        |      1560|2026-04-07 16:52:53 AEST |                    0|League roster selection and likely role view, not an official Tuesday/Friday team-list feed. |
|fixture_matchup_table            |derived output   |partial        |       459|2026-04-07 18:34:22 AEST |                    0|Real NRL matchup context for each club and round.                                            |
|team_performance_context         |derived output   |partial        |       459|2026-04-07 18:34:22 AEST |                    0|Real NRL team form/trend context by round.                                                   |
|cash_generation_model            |derived output   |partial        |       558|2026-04-07 17:26:52 AEST |                    0|Cash generation view used for trade timing and cash-cow decisions.                           |
|squad_round_enriched             |derived output   |partial        |      1560|2026-04-07 16:52:53 AEST |                    0|Main team-by-player analysis table for squad planning.                                       |
|opponent_behaviour_history       |derived output   |partial        |        60|NA                       |                    0|Fantasy-opponent behaviour table, not real NRL matchup data.                                 |
|league_ownership_movement        |derived output   |unavailable    |       558|2026-04-07 17:26:52 AEST |                    0|Placeholder table for ownership fields we have not sourced yet.                              |
|availability_risk_table          |derived output   |partial        |       558|2026-04-07 17:26:52 AEST |                    0|Current injury/suspension/lock risk snapshot.                                                |
|captaincy_vc_table               |derived output   |unavailable    |      1560|NA                       |                    0|Placeholder for captaincy fields we do not yet have.                                         |
|structure_health_table           |derived output   |partial        |        60|NA                       |                    0|High-level health summary for each league team.                                              |
|scenario_refresh_table           |derived output   |partial        |         1|2026-04-07 18:34:22 AEST |                    0|Tiny automation context table for refresh timing.                                            |
|long_horizon_planning_table      |derived output   |partial        |         1|2026-04-07 16:52:53 AEST |                    0|Top-line long-horizon planning summary for your team.                                        |
|checklist_coverage_status        |documentation    |documentation  |        16|NA                       |                    0|Coverage tracker for the whole project.                                                      |

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


## competition_state_history

- Category: source log
- Status: source_layer
- Grain: one row per refresh run
- Row count: 8
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: /settings
- Derived by: Append the raw competition state each time the refresh runs.
- What it means: Historical record of what the competition settings endpoint said at each refresh.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/settings (auth required)
- Spot-check note: Check current_round, next_round, lockout dates, and whether the raw settings lag the actual NRL schedule.



|run_ts              | current_round|competition_status |lockout_start             |
|:-------------------|-------------:|:------------------|:-------------------------|
|2026-04-07 17:26:52 |             5|active             |2026-04-09T19:50:00+10:00 |
|2026-04-07 17:28:49 |             5|active             |2026-04-09T19:50:00+10:00 |
|2026-04-07 17:55:16 |             5|active             |2026-04-09T19:50:00+10:00 |

## source_refresh_log

- Category: source log
- Status: source_layer
- Grain: one row per refresh run
- Row count: 8
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: refresh_supercoach_logs.R bookkeeping
- Derived by: Append one summary row per run after all source pulls complete.
- What it means: Quick audit trail for what the pipeline refreshed on each run.
- Spot-check against: No external page; compare to workflow/app refresh time
- Spot-check note: Check rounds_pulled, mutable_rounds, and player_history_refreshed_n after each run.



|run_ts              | current_round|mutable_rounds |rounds_pulled |nrl_fixture_rounds_pulled                                               |
|:-------------------|-------------:|:--------------|:-------------|:-----------------------------------------------------------------------|
|2026-04-07 17:26:52 |             5|4,5            |4,5           |NA                                                                      |
|2026-04-07 17:28:49 |             5|4,5            |4,5           |NA                                                                      |
|2026-04-07 17:55:16 |             5|4,5            |4,5           |1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27 |

## run_log

- Category: source log
- Status: source_layer
- Grain: one row per refresh run
- Row count: 10
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: refresh_supercoach_logs.R bookkeeping
- Derived by: Append performance and pull-volume metrics per run.
- What it means: Operational log showing what changed and how much work the run did.
- Spot-check against: No direct web page
- Spot-check note: Check whether player_history_refreshed_n or failed_team_rounds suddenly jump.



|run_ts              |first_run | current_round| changed_team_rounds| failed_team_rounds| player_history_refreshed_n|
|:-------------------|:---------|-------------:|-------------------:|------------------:|--------------------------:|
|2026-04-07 16:52:53 |TRUE      |             5|                  60|                  0|                         NA|
|2026-04-07 16:56:10 |FALSE     |             5|                   0|                  0|                         NA|
|2026-04-07 17:26:52 |FALSE     |             5|                   0|                  0|                        262|

## ladder_history

- Category: source log
- Status: source_layer
- Grain: one row per SuperCoach team per round per refresh
- Row count: 264
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: league ladderAndFixtures endpoint
- Derived by: Pull ladder rows for mutable rounds and append them.
- What it means: Historical SuperCoach league ladder snapshots.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/leagues/21064/ladderAndFixtures?round={round} (auth required)
- Spot-check note: Pick one round and compare ladder positions and team names against the live league view.



|run_ts              | round| user_team_id|team_name          |coach_name | position| round_points|
|:-------------------|-----:|------------:|:------------------|:----------|--------:|------------:|
|2026-04-07 16:52:53 |     1|         9517|Slewisbrah RLFC    |Lewis      |        1|         1332|
|2026-04-07 16:52:53 |     1|         7079|Crows              |sam        |        2|         1388|
|2026-04-07 16:52:53 |     1|        19016|Magnetic cucumbers |Daniel     |        3|         1383|

## fixtures_history

- Category: source log
- Status: source_layer
- Grain: one row per SuperCoach fixture per round per refresh
- Row count: 180
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: league ladderAndFixtures endpoint
- Derived by: Pull head-to-head fixtures for relevant rounds and append them.
- What it means: Historical SuperCoach matchup schedule and current live scores.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/leagues/21064/ladderAndFixtures?round={round} (auth required)
- Spot-check note: Compare your current matchup and scores against the league fixture screen.



|run_ts              | round| fixture|user_team1_name   | user_team1_points|user_team2_name | user_team2_points|
|:-------------------|-----:|-------:|:-----------------|-----------------:|:---------------|-----------------:|
|2026-04-07 16:52:53 |     1|       1|Jerky Turkeys     |              1268|Gordonites      |              1354|
|2026-04-07 16:52:53 |     1|       2|Lord of the Grims |              1375|WoodDucks       |              1214|
|2026-04-07 16:52:53 |     1|       3|Waterboys         |              1179|Crows           |              1388|

## team_round_stats_history

- Category: source log
- Status: source_layer
- Grain: one row per SuperCoach team per round per refresh
- Row count: 264
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: /userteams/{id}/statsPlayers
- Derived by: Pull roster summary stats for each team-round and append them.
- What it means: Historical team-level points, price, change count, and boosts used.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/userteams/{team_id}/statsPlayers?round={round} (auth required)
- Spot-check note: Compare total_changes, trade_boosts_used, and points for a known team/round.



|run_ts              | user_team_id| round| points|    price| total_changes| trade_boosts_used|
|:-------------------|------------:|-----:|------:|--------:|-------------:|-----------------:|
|2026-04-07 16:52:53 |         6896|     1|   1276| 11887100|            NA|                NA|
|2026-04-07 16:52:53 |         7079|     1|   1388| 11853000|            NA|                NA|
|2026-04-07 16:52:53 |         9517|     1|   1332| 11794200|            NA|                NA|

## team_players_snapshots

- Category: source log
- Status: source_layer
- Grain: many rows per team-round snapshot
- Row count: 1560
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: /userteams/{id}/statsPlayers
- Derived by: Store a full roster snapshot only when the team-round roster signature changes.
- What it means: Historical record of who was in each squad snapshot.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/userteams/{team_id}/statsPlayers?round={round} (auth required)
- Spot-check note: Check one team-round after a trade and confirm the snapshot only changes when the roster changes.



|run_ts              | user_team_id| round| player_id|position | position_sort|picked |
|:-------------------|------------:|-----:|---------:|:--------|-------------:|:------|
|2026-04-07 16:52:53 |         6896|     1|        40|HOK      |             1|NA     |
|2026-04-07 16:52:53 |         6896|     1|       159|HOK      |             1|TRUE   |
|2026-04-07 16:52:53 |         6896|     1|         7|FRF      |             2|NA     |

## team_round_signatures

- Category: source log
- Status: source_layer
- Grain: one row per changed team-round snapshot
- Row count: 60
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: team_players_snapshots
- Derived by: Hash each team-round roster so we only append changed snapshots.
- What it means: Change-detection layer that decides whether a new roster snapshot is needed.
- Spot-check against: No direct web page
- Spot-check note: If too many or too few roster snapshots are saved, inspect this table first.



|run_ts              | user_team_id| round|roster_signature                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|:-------------------|------------:|-----:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|2026-04-07 16:52:53 |         6896|     1|102::CTW::Wing/Centre::6::TRUE&#124;105::FRF::Front Row::2::FALSE&#124;131::CTW::Wing/Centre::6::FALSE&#124;144::FLB::Fullback::7::&#124;159::HOK::Hooker::1::TRUE&#124;194::FRF::Front Row::2::FALSE&#124;231::FRF::Front Row::2::TRUE&#124;245::CTW::Wing/Centre::6::FALSE&#124;261::2RF::2nd Row Forward::3::TRUE&#124;28::FLB::Fullback::7::TRUE&#124;325::5/8::5/8::5::FALSE&#124;35::CTW::Wing/Centre::6::&#124;361::2RF::2nd Row Forward::3::TRUE&#124;365::2RF::2nd Row Forward::3::&#124;374::FLX::Flex::8::TRUE&#124;393::HFB::Halfback::4::FALSE&#124;40::HOK::Hooker::1::&#124;416::2RF::2nd Row Forward::3::&#124;420::CTW::Wing/Centre::6::TRUE&#124;426::2RF::2nd Row Forward::3::TRUE&#124;441::CTW::Wing/Centre::6::TRUE&#124;451::5/8::5/8::5::TRUE&#124;481::HFB::Halfback::4::TRUE&#124;504::CTW::Wing/Centre::6::FALSE&#124;520::2RF::2nd Row Forward::3::FALSE&#124;7::FRF::Front Row::2::  |
|2026-04-07 16:52:53 |         7079|     1|130::2RF::2nd Row Forward::3::TRUE&#124;140::FRF::Front Row::2::FALSE&#124;158::FLB::Fullback::7::&#124;159::HOK::Hooker::1::TRUE&#124;167::2RF::2nd Row Forward::3::FALSE&#124;170::CTW::Wing/Centre::6::&#124;232::FLB::Fullback::7::TRUE&#124;245::CTW::Wing/Centre::6::TRUE&#124;321::HFB::Halfback::4::TRUE&#124;325::5/8::5/8::5::FALSE&#124;35::CTW::Wing/Centre::6::TRUE&#124;361::2RF::2nd Row Forward::3::TRUE&#124;365::FRF::Front Row::2::&#124;366::FRF::Front Row::2::TRUE&#124;393::HFB::Halfback::4::FALSE&#124;395::2RF::2nd Row Forward::3::FALSE&#124;420::CTW::Wing/Centre::6::TRUE&#124;426::2RF::2nd Row Forward::3::TRUE&#124;441::CTW::Wing/Centre::6::&#124;446::HOK::Hooker::1::FALSE&#124;451::5/8::5/8::5::TRUE&#124;475::FLX::Flex::8::&#124;504::CTW::Wing/Centre::6::FALSE&#124;520::2RF::2nd Row Forward::3::FALSE&#124;7::FRF::Front Row::2::TRUE&#124;92::CTW::Wing/Centre::6:: |
|2026-04-07 16:52:53 |         9517|     1|100::CTW::Wing/Centre::6::TRUE&#124;102::CTW::Wing/Centre::6::&#124;105::FRF::Front Row::2::FALSE&#124;131::CTW::Wing/Centre::6::FALSE&#124;140::2RF::2nd Row Forward::3::FALSE&#124;144::FLB::Fullback::7::&#124;158::FLB::Fullback::7::TRUE&#124;159::HOK::Hooker::1::TRUE&#124;194::FRF::Front Row::2::FALSE&#124;231::FRF::Front Row::2::TRUE&#124;261::2RF::2nd Row Forward::3::TRUE&#124;262::HOK::Hooker::1::&#124;325::5/8::5/8::5::FALSE&#124;35::FLX::Flex::8::TRUE&#124;361::2RF::2nd Row Forward::3::TRUE&#124;365::2RF::2nd Row Forward::3::&#124;374::CTW::Wing/Centre::6::TRUE&#124;393::HFB::Halfback::4::&#124;420::CTW::Wing/Centre::6::FALSE&#124;426::2RF::2nd Row Forward::3::TRUE&#124;441::CTW::Wing/Centre::6::TRUE&#124;451::5/8::5/8::5::TRUE&#124;481::HFB::Halfback::4::TRUE&#124;504::CTW::Wing/Centre::6::FALSE&#124;78::2RF::2nd Row Forward::3::FALSE&#124;7::FRF::Front Row::2:: |

## team_players_latest

- Category: base latest view
- Status: source_layer
- Grain: many rows per team-round latest roster
- Row count: 1560
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: team_players_snapshots + team_round_signatures
- Derived by: Take the latest saved snapshot for each team-round.
- What it means: Current best-known roster for each SuperCoach team and round.
- Spot-check against: Compare against the current team page in SuperCoach
- Spot-check note: Check one team and round you know well and confirm the selected 17/reserves look right.



|run_ts              | user_team_id| round| player_id|position |position_long | position_sort|
|:-------------------|------------:|-----:|---------:|:--------|:-------------|-------------:|
|2026-04-07 16:52:53 |         6896|     1|        40|HOK      |Hooker        |             1|
|2026-04-07 16:52:53 |         6896|     1|       159|HOK      |Hooker        |             1|
|2026-04-07 16:52:53 |         6896|     1|         7|FRF      |Front Row     |             2|

## actual_trade_history

- Category: source log
- Status: source_layer
- Grain: one row per actual trade event
- Row count: 9
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: /userteams/{id}/statsPlayers
- Derived by: Persist actual buy/sell pairs returned by the authenticated team endpoint.
- What it means: Confirmed trade events where the source API exposes the trade pair.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/userteams/{team_id}/statsPlayers?round={round} (auth required)
- Spot-check note: For your own team, compare a known trade week against what SuperCoach shows.



|run_ts              | round| user_team_id| buy_player_id| sell_player_id|trade_source |
|:-------------------|-----:|------------:|-------------:|--------------:|:------------|
|2026-04-07 16:52:53 |     2|        83682|           140|            134|actual_api   |
|2026-04-07 16:52:53 |     2|        83682|           160|             77|actual_api   |
|2026-04-07 16:52:53 |     2|        83682|           166|            222|actual_api   |

## inferred_changes

- Category: source log
- Status: source_layer
- Grain: one row per detected roster change event
- Row count: 60
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: team_players_snapshots
- Derived by: Compare consecutive roster snapshots to infer ins/outs when actual trades are not exposed.
- What it means: Best-effort inferred trade/change history for league opponents.
- Spot-check against: No direct public page; compare against opponent roster changes
- Spot-check note: Treat this as inferred, not ground truth. Spot-check known opponent trades.



|detected_run_ts     | user_team_id| round| players_out_n| players_in_n|
|:-------------------|------------:|-----:|-------------:|------------:|
|2026-04-07 16:52:53 |         6896|     1|             0|           26|
|2026-04-07 16:52:53 |         7079|     1|             0|           26|
|2026-04-07 16:52:53 |         9517|     1|             0|           26|

## players_cf_history

- Category: source log
- Status: source_layer
- Grain: one row per changed player status state
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: /players-cf
- Derived by: Append a new row only when a player's lock/status/injury state changes.
- What it means: History of player availability, lock, and status changes.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/players-cf (auth required)
- Spot-check note: Check injury text and locked flags for players you know changed recently.



|run_ts              | player_id|full_name         |team_abbrev |locked_flag |played_status |injury_suspension_status_text |
|:-------------------|---------:|:-----------------|:-----------|:-----------|:-------------|:-----------------------------|
|2026-04-07 17:26:52 |         1|Anderson, Grant   |BRO         |FALSE       |pre           |NA                            |
|2026-04-07 17:26:52 |         2|Arthars, Jesse    |BRO         |FALSE       |pre           |NA                            |
|2026-04-07 17:26:52 |         3|Bukowski, Cameron |BRO         |FALSE       |pre           |NA                            |

## players_cf_latest

- Category: base latest view
- Status: source_layer
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: players_cf_history
- Derived by: Take the latest status row per player.
- What it means: Current best-known player availability/lockout state.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/players-cf (auth required)
- Spot-check note: Spot-check a few injured or locked players against the live app/site.



| player_id|full_name         |team_abbrev |locked_flag |played_status |injury_suspension_status_text |
|---------:|:-----------------|:-----------|:-----------|:-------------|:-----------------------------|
|         1|Anderson, Grant   |BRO         |FALSE       |pre           |NA                            |
|         2|Arthars, Jesse    |BRO         |FALSE       |pre           |NA                            |
|         3|Bukowski, Cameron |BRO         |FALSE       |pre           |NA                            |

## player_history_refresh_log

- Category: source log
- Status: source_layer
- Grain: one row per player history refresh
- Row count: 2096
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: initialvalue.php + data-yearplot.php
- Derived by: Log which player histories were refreshed and why.
- What it means: Audit trail for why a player's external price history was re-pulled.
- Spot-check against: https://www.nrlsupercoachstats.com/initialvalue.php?year=2026
- Spot-check note: If a player's history looks stale, inspect this log to see whether they were refreshed.



|run_ts              |player_name      |refresh_reason        | current_price_external| latest_price_stored|
|:-------------------|:----------------|:---------------------|----------------------:|-------------------:|
|2026-04-07 17:26:52 |Alamoti, Paul    |current_price_changed |                 643000|              567800|
|2026-04-07 17:26:52 |Atkinson, Daniel |current_price_changed |                 235600|              315900|
|2026-04-07 17:26:52 |Averillo, Jake   |current_price_changed |                 579000|              686100|

## player_price_history_2026

- Category: source log
- Status: source_layer
- Grain: one row per external player per round
- Row count: 14170
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: data-yearplot.php
- Derived by: Rebuild external player round history for refreshed players and upsert by player+round.
- What it means: External price/score/minutes history keyed by player name.
- Spot-check against: https://www.nrlsupercoachstats.com/highcharts/data-yearplot.php?dropdown1={player_name}&YEAR=2026
- Spot-check note: Spot-check a known player like Nathan Cleary and compare rounds/price to NRL SuperCoach Stats.



|player_name     | round| score| mins|  price|
|:---------------|-----:|-----:|----:|------:|
|Addo-Carr, Josh |     1|     0|    0| 591200|
|Addo-Carr, Josh |     2|    21|   80| 591200|
|Addo-Carr, Josh |     3|    49|   80| 591200|

## players_cf_2026

- Category: helper table
- Status: source_layer
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: players_cf_latest
- Derived by: Copy the latest players-cf view for downstream joins.
- What it means: Convenience copy of the current player catalog.
- Spot-check against: https://www.supercoach.com.au/2026/api/nrl/classic/v1/players-cf (auth required)
- Spot-check note: Check row count matches players_cf_latest.



| player_id|full_name         |team_abbrev |active_flag |
|---------:|:-----------------|:-----------|:-----------|
|         1|Anderson, Grant   |BRO         |TRUE        |
|         2|Arthars, Jesse    |BRO         |TRUE        |
|         3|Bukowski, Cameron |BRO         |TRUE        |

## player_id_lookup

- Category: helper table
- Status: source_layer
- Grain: one row per player id
- Row count: 558
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: players_cf_latest
- Derived by: Reduce the current player catalog to the id/name/team lookup used elsewhere.
- What it means: Helper lookup from player_id to name/team.
- Spot-check against: No direct public page
- Spot-check note: Use this when you want to decode trade ids into names.



| player_id|full_name         |team_abbrev |
|---------:|:-----------------|:-----------|
|         1|Anderson, Grant   |BRO         |
|         2|Arthars, Jesse    |BRO         |
|         3|Bukowski, Cameron |BRO         |

## player_price_history_sc

- Category: base latest view
- Status: source_layer
- Grain: one row per SuperCoach player_id per round
- Row count: 14196
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: player_price_history_2026 + player_id crosswalk
- Derived by: Map external player-name histories onto current SuperCoach player ids.
- What it means: Canonical player score/minutes/price history keyed by player_id.
- Spot-check against: Compare against NRL SuperCoach Stats for a few players
- Spot-check note: This is the key history table feeding many downstream outputs.



| player_id|player_name     | round| score| mins|  price|
|---------:|:---------------|-----:|-----:|----:|------:|
|         1|Anderson, Grant |     1|     0|    0| 523400|
|         1|Anderson, Grant |     2|     0|    0| 523400|
|         1|Anderson, Grant |     3|    31|   80| 523400|

## nrl_fixture_source_history

- Category: source log
- Status: source_layer
- Grain: one row per NRL team per round per refresh
- Row count: 1054
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: official NRL draw page
- Derived by: Scrape official draw rows and append them with kickoff and match-state context.
- What it means: Historical official NRL fixture source used for matchup logic and round inference.
- Spot-check against: https://www.nrl.com/draw/?round={round}
- Spot-check note: Check opponent, venue, kickoff time, home/away, and bye rows against the official draw.



|run_ts              | round|team_abbrev |opponent_abbrev |match_state |kickoff_at_utc |venue             |
|:-------------------|-----:|:-----------|:---------------|:-----------|:--------------|:-----------------|
|2026-04-07 17:55:16 |     1|BRO         |PTH             |FullTime    |2026-03-06     |Suncorp Stadium   |
|2026-04-07 17:55:16 |     1|BUL         |STG             |FullTime    |2026-03-01     |Allegiant Stadium |
|2026-04-07 17:55:16 |     1|CBR         |MNL             |FullTime    |2026-03-07     |4 Pines Park      |

## nrl_team_context_history

- Category: source log
- Status: source_layer
- Grain: one row per NRL team per round per refresh
- Row count: 255
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: official NRL ladder page
- Derived by: Scrape official ladder/context rows and append them by round.
- What it means: Historical official NRL ladder/context source for trend and ladder joins.
- Spot-check against: https://www.nrl.com/ladder/?round={round}
- Spot-check note: Check ladder position, streak, form, next opponent against the official ladder page.



|run_ts              | round|team_abbrev | ladder_position|streak |form  |next_opponent_abbrev |
|:-------------------|-----:|:-----------|---------------:|:------|:-----|:--------------------|
|2026-04-07 17:55:16 |     1|MEL         |               1|3L     |2 - 3 |STG                  |
|2026-04-07 17:55:16 |     1|SHA         |               2|2W     |3 - 2 |PTH                  |
|2026-04-07 17:55:16 |     1|PTH         |               3|5W     |5 - 0 |SHA                  |

## fixture_triggers

- Category: derived output
- Status: partial
- Grain: one row per production run
- Row count: 1
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: settings + inferred round state
- Derived by: Package round/lockout trigger fields for automation and app use.
- What it means: Small trigger table showing the active round window and lockout timing.
- Spot-check against: Compare against /settings and the official NRL draw close of the last round
- Spot-check note: Check current_round, next_round, and lockout times after each refresh.



|run_ts              | current_round|lockout_start             |
|:-------------------|-------------:|:-------------------------|
|2026-04-07 18:34:22 |             5|2026-04-09T19:50:00+10:00 |

## game_rules_round_state

- Category: derived output
- Status: partial
- Grain: one row per production run
- Row count: 1
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: /settings + my team round stats + players_cf_latest
- Derived by: Take settings, effective round state, position rules, and my trade usage into one table.
- What it means: Current operating state of the game for the dashboard and GPT pack.
- Spot-check against: /settings, /players-cf, /userteams/{id}/statsPlayers
- Spot-check note: This is the first table to inspect when the app shows the wrong round.



|run_ts              | current_round| next_round| trades_remaining| boosts_remaining|
|:-------------------|-------------:|----------:|----------------:|----------------:|
|2026-04-07 18:34:22 |             5|          6|               37|                3|

Coverage note: Confirmed competition rules, lockout window, squad limits, bye rounds, and player lock state via list columns; Origin-specific rounds remain unavailable.


## master_player_round_latest

- Category: derived output
- Status: partial
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: players_cf_latest + initialvalue.php + player_price_history_sc
- Derived by: Join current player catalog to external price history rollups and history lists.
- What it means: Main current-player master table used for market and squad analysis.
- Spot-check against: /players-cf, initialvalue.php, data-yearplot.php
- Spot-check note: Check current_price, average_3_round, status, and team for a few known players.



| player_id|full_name         |team | current_price| current_season_average| average_3_round|status      |
|---------:|:-----------------|:----|-------------:|----------------------:|---------------:|:-----------|
|         1|Anderson, Grant   |BRO  |        523400|                  10.75|              NA|Yet to play |
|         2|Arthars, Jesse    |BRO  |        425900|                  14.00|        23.33333|Yet to play |
|         3|Bukowski, Cameron |BRO  |        201400|                   0.00|              NA|Yet to play |

Coverage note: Current price, status, team, DPP, history lists, and recent averages are confirmed; breakeven, ownership, role, goal-kicking, and return timeline remain unavailable.


## player_scoring_component_history

- Category: derived output
- Status: partial
- Grain: one row per player per round
- Row count: 14196
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: player_price_history_sc rollups
- Derived by: Convert score/minutes/price history into volatility, floor, ceiling, and ppm style metrics.
- What it means: History table of scoring-related rollups; most detailed components are still unavailable.
- Spot-check against: data-yearplot.php
- Spot-check note: Check total_score, minutes_played, volatility_score for a known player-round.



| player_id| round| total_score| minutes_played| volatility_score| floor_score_estimate| ceiling_score_estimate|
|---------:|-----:|-----------:|--------------:|----------------:|--------------------:|----------------------:|
|         1|     1|           0|              0|               NA|                   NA|                     NA|
|         1|     2|           0|              0|               NA|                   NA|                     NA|
|         1|     3|          31|             80|               NA|                   NA|                     NA|

Coverage note: Confirmed score, minutes, price-derived volatility, floor, ceiling, and PPM; base-stat components are unavailable from confirmed sources.


## team_list_role_certainty

- Category: derived output
- Status: partial
- Grain: one row per rostered player per team-round
- Row count: 1560
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: team_players_latest + player_price_history_sc
- Derived by: Take selected squad rows and attach a simple recent-minutes role certainty heuristic.
- What it means: League roster selection and likely role view, not an official Tuesday/Friday team-list feed.
- Spot-check against: /userteams/{id}/statsPlayers, data-yearplot.php
- Spot-check note: Use this as a roster/role hint only, not as ground-truth late mail.



| user_team_id| round| player_id|starting_or_bench |listed_position | likely_minutes|role_change_likelihood |
|------------:|-----:|---------:|:-----------------|:---------------|--------------:|:----------------------|
|         6896|     1|        40|selected          |HOK             |             NA|NA                     |
|         6896|     1|       159|selected          |HOK             |             NA|NA                     |
|         6896|     1|         7|selected          |FRF             |             NA|NA                     |

Coverage note: Confirmed squad selection order and recent minutes for league rosters; global NRL team lists, role threats, and late omission probabilities remain unavailable.


## fixture_matchup_table

- Category: derived output
- Status: partial
- Grain: one row per NRL team per round
- Row count: 459
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: nrl_fixture_source_history + nrl_team_context_history
- Derived by: Turn official draw plus ladder context into matchup ratings, rest/travel, and forward difficulty windows.
- What it means: Real NRL matchup context for each club and round.
- Spot-check against: https://www.nrl.com/draw/?round={round}, https://www.nrl.com/ladder/?round={round}
- Spot-check note: Check opponent, venue, home_away, days_rest, and bye_flag against the official draw first.



| round|team_abbrev |opponent |venue           |home_away | days_rest| matchup_rating_by_team|schedule_swing_indicator |
|-----:|:-----------|:--------|:---------------|:---------|---------:|----------------------:|:------------------------|
|     1|BRO         |PTH      |Suncorp Stadium |home      |        NA|                     NA|easier_short_term        |
|     2|BRO         |PAR      |Suncorp Stadium |home      |         6|                     26|stable                   |
|     3|BRO         |MEL      |AAMI Park       |away      |         8|                     14|stable                   |

Coverage note: Confirmed official NRL fixture, venue, bye, kickoff timing, home/away, days-rest, travel heuristic, and rolling matchup difficulty via draw and ladder pages; position-specific weakness and confirmed major outs remain unavailable.


## team_performance_context

- Category: derived output
- Status: partial
- Grain: one row per NRL team per round
- Row count: 459
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: nrl_fixture_source_history + nrl_team_context_history
- Derived by: Roll official scores into recent attacking/defensive trends and attach ladder context.
- What it means: Real NRL team form/trend context by round.
- Spot-check against: https://www.nrl.com/draw/?round={round}, https://www.nrl.com/ladder/?round={round}
- Spot-check note: Check points_scored/conceded and ladder_position against the official NRL pages.



|team_abbrev | round| points_scored| points_conceded| attacking_trend_last_3| defensive_trend_last_3|
|:-----------|-----:|-------------:|---------------:|----------------------:|----------------------:|
|BRO         |     1|             0|              26|                     NA|                     NA|
|BRO         |     2|            32|              40|                      0|                     26|
|BRO         |     3|            18|              14|                     16|                     33|

Coverage note: Confirmed official NRL scores, ladder position, streak, form, points differential, and rolling attacking/defensive trends via draw and ladder pages; tries, linebreaks, possession, and edge-split stats remain unavailable.


## cash_generation_model

- Category: derived output
- Status: partial
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: master_player inputs + initialvalue.php projections
- Derived by: Take current and projected external prices to classify cash cows and projected rises/falls.
- What it means: Cash generation view used for trade timing and cash-cow decisions.
- Spot-check against: initialvalue.php, data-yearplot.php
- Spot-check note: Check current_price and projected next price for a few players against NRL SuperCoach Stats.



| player_id|full_name         |team_abbrev | current_price| projected_price_rise_next_round|cash_cow_maturity_status |
|---------:|:-----------------|:-----------|-------------:|-------------------------------:|:------------------------|
|         1|Anderson, Grant   |BRO         |        523400|                        9429.318|rising                   |
|         2|Arthars, Jesse    |BRO         |        425900|                        8257.222|rising                   |
|         3|Bukowski, Cameron |BRO         |        201400|                           0.000|near_peak_or_peaked      |

Coverage note: Confirmed starting/current price, recent price movement, projected next price, and cash classification; breakeven trend and peak-cash timing remain unavailable.


## squad_round_enriched

- Category: derived output
- Status: partial
- Grain: one row per rostered player per team-round
- Row count: 1560
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: team_players_latest + player history + fixture_matchup_table + master_player
- Derived by: Attach acquisition, price, role, lock, matchup, and simple projection fields to each roster slot.
- What it means: Main team-by-player analysis table for squad planning.
- Spot-check against: /userteams/{id}/statsPlayers, /players-cf, data-yearplot.php
- Spot-check note: Check one of your players for acquisition_round, current_price, selected_this_week, and projected_score fields.



| user_team_id|team_name        | round|full_name       | current_price|selected_this_week | projected_score_next_3_weeks|
|------------:|:----------------|-----:|:---------------|-------------:|:------------------|----------------------------:|
|         6896|Spearmint Rhinos |     1|Hayward, Bailey |        343900|TRUE               |                           NA|
|         6896|Spearmint Rhinos |     1|Grant, Harry    |        606300|TRUE               |                           NA|
|         6896|Spearmint Rhinos |     1|Haas, Payne     |        852700|TRUE               |                           NA|

Coverage note: Confirmed acquisition timing, prices, lock state, selection slot, and simple projections; next-3-week value movement and bye utility remain approximate or unavailable.


## opponent_behaviour_history

- Category: derived output
- Status: partial
- Grain: one row per SuperCoach team per round
- Row count: 60
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: team_players_latest + inferred_changes + actual_trade_history + team_round_stats_history
- Derived by: Summarise league-opponent behaviour from snapshots, actual trades, and boost counts.
- What it means: Fantasy-opponent behaviour table, not real NRL matchup data.
- Spot-check against: /userteams/{id}/statsPlayers, ladderAndFixtures
- Spot-check note: This is about your SuperCoach opponent, not their NRL fixture.



| user_team_id|team_name        | round| inferred_trade_events| actual_trade_count| trade_boosts_used|behaviour_source                   |
|------------:|:----------------|-----:|---------------------:|------------------:|-----------------:|:----------------------------------|
|         6896|Spearmint Rhinos |     1|                     1|                 NA|                NA|snapshot_inference_plus_team_stats |
|         6896|Spearmint Rhinos |     2|                     1|                 NA|                 0|snapshot_inference_plus_team_stats |
|         6896|Spearmint Rhinos |     3|                     1|                 NA|                 1|snapshot_inference_plus_team_stats |

Coverage note: Confirmed full squad history, cumulative change counts, and boost usage by team-round; exact opponent ins/outs are only inferred from snapshots unless exposed for the authenticated team.


## league_ownership_movement

- Category: derived output
- Status: unavailable
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: placeholder only
- Derived by: Create an NA-filled placeholder because confirmed ownership sources were not found.
- What it means: Placeholder table for ownership fields we have not sourced yet.
- Spot-check against: Unavailable from confirmed sources
- Spot-check note: Expect this to be mostly NA until a confirmed ownership source is added.



| player_id|full_name         | ownership_percentage| ownership_movement|
|---------:|:-----------------|--------------------:|------------------:|
|         1|Anderson, Grant   |                   NA|                 NA|
|         2|Arthars, Jesse    |                   NA|                 NA|
|         3|Bukowski, Cameron |                   NA|                 NA|

Coverage note: Ownership percentage and movement were not present in the confirmed source set.


## availability_risk_table

- Category: derived output
- Status: partial
- Grain: one row per player
- Row count: 558
- Latest run timestamp: 2026-04-07 17:26:52 AEST
- Duplicate key groups: 0
- Built from: players_cf_latest
- Derived by: Translate current player availability fields into a simple risk-band table.
- What it means: Current injury/suspension/lock risk snapshot.
- Spot-check against: /players-cf
- Spot-check note: Check known injured players and make sure the risk_band and status text make sense.



| player_id|full_name         |team_abbrev |injury_suspension_status_text |locked_flag |risk_band |
|---------:|:-----------------|:-----------|:-----------------------------|:-----------|:---------|
|         1|Anderson, Grant   |BRO         |NA                            |FALSE       |low       |
|         2|Arthars, Jesse    |BRO         |NA                            |FALSE       |low       |
|         3|Bukowski, Cameron |BRO         |NA                            |FALSE       |low       |

Coverage note: Confirmed current active, injury/suspension, and lock indicators from /players-cf; expected return dates remain unavailable.


## captaincy_vc_table

- Category: derived output
- Status: unavailable
- Grain: one row per rostered player per team-round
- Row count: 1560
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: placeholder only
- Derived by: Create NA captain/vice-captain flags because confirmed source fields were not found.
- What it means: Placeholder for captaincy fields we do not yet have.
- Spot-check against: Unavailable from confirmed sources
- Spot-check note: Expect NA values for now.



| user_team_id| round| player_id|captain_flag |vice_captain_flag |captaincy_source                   |
|------------:|-----:|---------:|:------------|:-----------------|:----------------------------------|
|         6896|     1|         7|NA           |NA                |unavailable_from_confirmed_sources |
|         6896|     1|        28|NA           |NA                |unavailable_from_confirmed_sources |
|         6896|     1|        35|NA           |NA                |unavailable_from_confirmed_sources |

Coverage note: Captain and vice-captain selections were not present in the confirmed source set.


## structure_health_table

- Category: derived output
- Status: partial
- Grain: one row per SuperCoach team per round
- Row count: 60
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: squad_round_enriched
- Derived by: Summarise squad composition, locks, DPP count, and projected score at team-round level.
- What it means: High-level health summary for each league team.
- Spot-check against: /userteams/{id}/statsPlayers, /players-cf
- Spot-check note: Check players_in_squad, locked_players, and avg_projected_score_this_week for your own team first.



| user_team_id|team_name        | round| players_in_squad| locked_players| dpp_players| avg_projected_score_this_week|
|------------:|:----------------|-----:|----------------:|--------------:|-----------:|-----------------------------:|
|         6896|Spearmint Rhinos |     1|               26|              0|           5|                            NA|
|         6896|Spearmint Rhinos |     2|               26|              0|           5|                            NA|
|         6896|Spearmint Rhinos |     3|               26|              0|           5|                      63.10256|

Coverage note: Confirmed structural metrics from squad composition and lock state; fixture-linked bye and schedule context are now available for downstream joins.


## scenario_refresh_table

- Category: derived output
- Status: partial
- Grain: one row per production run
- Row count: 1
- Latest run timestamp: 2026-04-07 18:34:22 AEST
- Duplicate key groups: 0
- Built from: settings + inferred round state
- Derived by: Create a small refresh-trigger table used by scheduling logic.
- What it means: Tiny automation context table for refresh timing.
- Spot-check against: /settings
- Spot-check note: This is mostly for automation, not decision-making.



|run_ts              | current_round|competition_status |is_lockout |next_refresh_trigger      |refresh_reason             |
|:-------------------|-------------:|:------------------|:----------|:-------------------------|:--------------------------|
|2026-04-07 18:34:22 |             5|active             |FALSE      |2026-04-09T19:50:00+10:00 |competition_lockout_window |

Coverage note: Confirmed competition refresh trigger from /settings lockout window; official NRL draw now supplies per-round matchup refresh context.


## long_horizon_planning_table

- Category: derived output
- Status: partial
- Grain: one row for your team
- Row count: 1
- Latest run timestamp: 2026-04-07 16:52:53 AEST
- Duplicate key groups: 0
- Built from: squad_round_enriched + game_rules_round_state
- Derived by: Collapse your latest squad into a one-row planning summary for the next few weeks.
- What it means: Top-line long-horizon planning summary for your team.
- Spot-check against: /settings, /userteams/{id}/statsPlayers
- Spot-check note: Check current_squad_value, projected_score_next_3_weeks, trades_remaining, and boosts_remaining.



|team_name      | current_round| current_squad_value| projected_score_next_3_weeks| trades_remaining| boosts_remaining|
|:--------------|-------------:|-------------------:|----------------------------:|----------------:|----------------:|
|Grog Baguettes |             5|            13348200|                       1301.8|               37|                3|

Coverage note: Confirmed long-horizon summary uses current squad value, trades, boosts, and bye rounds; deeper future projection fields remain partial.


## checklist_coverage_status

- Category: documentation
- Status: documentation
- Grain: one row per checklist section
- Row count: 16
- Latest run timestamp: NA
- Duplicate key groups: 0
- Built from: production Rmd final summary
- Derived by: Write a summary of what checklist items are implemented, partial, or unavailable.
- What it means: Coverage tracker for the whole project.
- Spot-check against: Compare to supercoach_data_lookup_build_checklist.md
- Spot-check note: Use this to see which missing fields are expected rather than bugs.



|checklist_item                   |table_name                       |status  |source_endpoint                                      |
|:--------------------------------|:--------------------------------|:-------|:----------------------------------------------------|
|game_rules_round_state           |game_rules_round_state           |partial |/settings, /players-cf, /userteams/{id}/statsPlayers |
|master_player_table              |master_player_round_latest       |partial |/players-cf, initialvalue.php, data-yearplot.php     |
|player_scoring_component_history |player_scoring_component_history |partial |data-yearplot.php                                    |

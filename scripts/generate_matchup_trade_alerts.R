suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(tibble)
  library(purrr)
})

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
}

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))

path_game_rules <- file.path(data_dir, "game_rules_round_state.rds")
path_ladder_history <- file.path(data_dir, "ladder_history.rds")
path_fixtures_history <- file.path(data_dir, "fixtures_history.rds")
path_inferred_changes <- file.path(data_dir, "inferred_changes.rds")
path_actual_trade_history <- file.path(data_dir, "actual_trade_history.rds")
path_player_id_lookup <- file.path(data_dir, "player_id_lookup.rds")
path_alert_log <- file.path(data_dir, "matchup_trade_alert_log.rds")
path_pending_json <- file.path(data_dir, "pending_matchup_trade_alerts.json")

emit_output <- function(name, value) {
  value <- gsub("%", "%25", value, fixed = TRUE)
  value <- gsub("\r", "%0D", value, fixed = TRUE)
  value <- gsub("\n", "%0A", value, fixed = TRUE)
  cat(name, "=", value, "\n", sep = "")
}

empty_alert_log <- tibble(
  alert_key = character(),
  alert_type = character(),
  round = integer(),
  opponent_team_id = integer(),
  opponent_team_name = character(),
  opponent_coach = character(),
  alert_message = character(),
  detected_run_ts = as.POSIXct(character()),
  sent_at = as.POSIXct(character())
)

if (!all(file.exists(c(path_game_rules, path_ladder_history, path_fixtures_history, path_inferred_changes, path_actual_trade_history, path_player_id_lookup)))) {
  write_json(list(alerts = list()), path_pending_json, auto_unbox = TRUE, pretty = TRUE)
  emit_output("has_alerts", "false")
  emit_output("email_subject", "No matchup trade alerts")
  emit_output("email_body", "No matchup trade alerts were generated because required files were missing.")
  quit(save = "no", status = 0)
}

game_rules <- readRDS(path_game_rules)
ladder_history <- readRDS(path_ladder_history)
fixtures_history <- readRDS(path_fixtures_history)
inferred_changes <- readRDS(path_inferred_changes)
actual_trade_history <- readRDS(path_actual_trade_history)
player_id_lookup <- readRDS(path_player_id_lookup)
alert_log <- if (file.exists(path_alert_log)) readRDS(path_alert_log) else empty_alert_log

current_round <- game_rules$current_round[[1]]

latest_ladder_round <- ladder_history %>%
  filter(round == current_round) %>%
  group_by(user_team_id) %>%
  slice_max(run_ts, n = 1, with_ties = FALSE) %>%
  ungroup()

my_team_id <- latest_ladder_round %>%
  filter(is_me %in% TRUE) %>%
  pull(user_team_id) %>%
  first()

latest_fixtures_round <- fixtures_history %>%
  filter(round == current_round) %>%
  group_by(fixture_id) %>%
  slice_max(run_ts, n = 1, with_ties = FALSE) %>%
  ungroup()

my_fixture <- latest_fixtures_round %>%
  filter(user_team1_id == my_team_id | user_team2_id == my_team_id) %>%
  slice_head(n = 1)

if (nrow(my_fixture) == 0) {
  write_json(list(alerts = list()), path_pending_json, auto_unbox = TRUE, pretty = TRUE)
  emit_output("has_alerts", "false")
  emit_output("email_subject", paste("Round", current_round, "matchup alerts unavailable"))
  emit_output("email_body", "No current matchup was found in fixtures_history.")
  quit(save = "no", status = 0)
}

opponent_team_id <- if (my_fixture$user_team1_id[[1]] == my_team_id) my_fixture$user_team2_id[[1]] else my_fixture$user_team1_id[[1]]

opponent_meta <- latest_ladder_round %>%
  filter(user_team_id == opponent_team_id) %>%
  distinct(user_team_id, team_name, coach_name)

lookup_player_name <- function(id) {
  player_id_lookup %>%
    filter(player_id == !!id) %>%
    pull(full_name) %>%
    first() %>%
    `%||%`(paste0("player_id_", id))
}

actual_alerts <- actual_trade_history %>%
  filter(round == current_round, user_team_id == opponent_team_id) %>%
  transmute(
    alert_key = paste("actual", round, user_team_id, buy_player_id, sell_player_id, sep = "::"),
    alert_type = "actual",
    round,
    opponent_team_id = user_team_id,
    opponent_team_name = opponent_meta$team_name[[1]] %||% "Unknown opponent",
    opponent_coach = opponent_meta$coach_name[[1]] %||% "Unknown coach",
    alert_message = paste0(
      "Actual trade detected: bought ",
      map_chr(buy_player_id, lookup_player_name),
      ", sold ",
      map_chr(sell_player_id, lookup_player_name)
    ),
    detected_run_ts = Sys.time()
  )

inferred_alerts <- inferred_changes %>%
  filter(
    round == current_round,
    user_team_id == opponent_team_id,
    !is.na(from_run_ts),
    (players_in_n + players_out_n) > 0
  ) %>%
  transmute(
    alert_key = paste(
      "inferred",
      round,
      user_team_id,
      format(detected_run_ts, "%Y-%m-%d %H:%M:%S"),
      map_chr(players_in, ~ paste(sort(.x), collapse = "-")),
      map_chr(players_out, ~ paste(sort(.x), collapse = "-")),
      sep = "::"
    ),
    alert_type = "inferred",
    round,
    opponent_team_id = user_team_id,
    opponent_team_name = opponent_meta$team_name[[1]] %||% "Unknown opponent",
    opponent_coach = opponent_meta$coach_name[[1]] %||% "Unknown coach",
    alert_message = paste0(
      "Inferred squad change: in [",
      map_chr(players_in, ~ paste(map_chr(.x, lookup_player_name), collapse = ", ")),
      "], out [",
      map_chr(players_out, ~ paste(map_chr(.x, lookup_player_name), collapse = ", ")),
      "]"
    ),
    detected_run_ts
  )

alerts <- bind_rows(actual_alerts, inferred_alerts) %>%
  arrange(detected_run_ts, alert_type, alert_key)

pending_alerts <- alerts %>%
  anti_join(alert_log %>% select(alert_key), by = "alert_key")

write_json(
  list(
    generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    round = current_round,
    opponent_team_id = opponent_team_id,
    opponent_team_name = opponent_meta$team_name[[1]] %||% "Unknown opponent",
    opponent_coach = opponent_meta$coach_name[[1]] %||% "Unknown coach",
    alerts = split(pending_alerts, seq_len(nrow(pending_alerts)))
  ),
  path_pending_json,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

if (nrow(pending_alerts) == 0) {
  emit_output("has_alerts", "false")
  emit_output("email_subject", paste("Round", current_round, "matchup alert check"))
  emit_output("email_body", paste("No new matchup trade alerts for", opponent_meta$team_name[[1]] %||% "your opponent"))
  quit(save = "no", status = 0)
}

email_subject <- paste0(
  "SuperCoach alert: ",
  opponent_meta$team_name[[1]] %||% "Opponent",
  " made a move in Round ",
  current_round
)

email_lines <- c(
  paste0("Opponent: ", opponent_meta$team_name[[1]] %||% "Unknown opponent"),
  paste0("Coach: ", opponent_meta$coach_name[[1]] %||% "Unknown coach"),
  paste0("Round: ", current_round),
  "",
  pending_alerts$alert_message
)

emit_output("has_alerts", "true")
emit_output("email_subject", email_subject)
emit_output("email_body", paste(email_lines, collapse = "\n"))

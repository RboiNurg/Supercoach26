suppressWarnings({
  league_id <- Sys.getenv("SC_LEAGUE_ID", "21064")
  data_dir <- file.path("data", paste0("supercoach_league_", league_id))
  required_files <- c(
    "game_rules_round_state.rds",
    "ladder_history.rds",
    "fixtures_history.rds",
    "source_refresh_log.rds",
    "squad_round_enriched.rds",
    "master_player_round_latest.rds",
    "league_trade_log.rds"
  )

  missing_files <- required_files[!file.exists(file.path(data_dir, required_files))]
  if (length(missing_files)) {
    stop(
      paste(
        "Smoke check failed. Missing required bundle files:",
        paste(missing_files, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(parse(file = "app.R"))

  game_rules <- readRDS(file.path(data_dir, "game_rules_round_state.rds"))
  ladder_history <- readRDS(file.path(data_dir, "ladder_history.rds"))
  fixtures_history <- readRDS(file.path(data_dir, "fixtures_history.rds"))
  squad_round_enriched <- readRDS(file.path(data_dir, "squad_round_enriched.rds"))
  league_trade_log <- readRDS(file.path(data_dir, "league_trade_log.rds"))

  round_values <- suppressWarnings(as.integer(game_rules$round))
  round_values <- round_values[is.finite(round_values)]
  current_round <- if (length(round_values)) max(round_values) else NA_integer_

  cat("smoke_check_app: ok\n")
  cat("league_id:", league_id, "\n")
  cat("current_round:", current_round, "\n")
  cat("ladder_rows:", nrow(ladder_history), "\n")
  cat("fixtures_rows:", nrow(fixtures_history), "\n")
  cat("squad_rows:", nrow(squad_round_enriched), "\n")
  cat("trade_log_rows:", nrow(league_trade_log), "\n")
})

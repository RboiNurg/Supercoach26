suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
}

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
bundled_data_dir <- file.path("data", paste0("supercoach_league_", league_id))
runtime_root <- Sys.getenv(
  "SC_APP_RUNTIME_ROOT",
  file.path(tempdir(), "supercoach-dashboard-cache")
)
data_dir <- file.path(runtime_root, paste0("supercoach_league_", league_id))
build_prompt_script <- "scripts/build_gpt_prompt_pack.R"
app_state <- new.env(parent = emptyenv())

key_bundle_files <- c(
  "game_rules_round_state.rds",
  "ladder_history.rds",
  "fixtures_history.rds",
  "source_refresh_log.rds",
  "squad_round_enriched.rds"
)

data_dir_is_populated <- function(path) {
  if (!dir.exists(path)) {
    return(FALSE)
  }

  existing_key_files <- file.exists(file.path(path, key_bundle_files))
  sum(existing_key_files, na.rm = TRUE) >= 3
}

seed_runtime_data_from_bundle <- function(overwrite = FALSE) {
  if (!dir.exists(bundled_data_dir) || !data_dir_is_populated(bundled_data_dir)) {
    return(FALSE)
  }

  if (overwrite && dir.exists(data_dir)) {
    unlink(data_dir, recursive = TRUE, force = TRUE)
  }

  dir.create(dirname(data_dir), recursive = TRUE, showWarnings = FALSE)

  copied <- file.copy(
    from = bundled_data_dir,
    to = dirname(data_dir),
    recursive = TRUE,
    overwrite = overwrite
  )

  any(copied) && data_dir_is_populated(data_dir)
}

initialize_runtime_data_dir <- function() {
  dir.create(runtime_root, recursive = TRUE, showWarnings = FALSE)

  if (data_dir_is_populated(data_dir)) {
    return(invisible(data_dir))
  }

  seeded <- seed_runtime_data_from_bundle(overwrite = TRUE)

  if (!seeded) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }

  invisible(data_dir)
}

initialize_runtime_data_dir()

read_required_rds <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  readRDS(path)
}

read_optional_rds <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  readRDS(path)
}

read_optional_text <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

read_optional_csv <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

reload_bundled_snapshot <- function() {
  initialize_runtime_data_dir()
  seed_runtime_data_from_bundle(overwrite = TRUE)
}

load_dashboard_data <- function() {
  initialize_runtime_data_dir()

  list(
    game_rules = read_required_rds(file.path(data_dir, "game_rules_round_state.rds")),
    ladder_history = read_required_rds(file.path(data_dir, "ladder_history.rds")),
    fixtures_history = read_required_rds(file.path(data_dir, "fixtures_history.rds")),
    structure_health = read_required_rds(file.path(data_dir, "structure_health_table.rds")),
    opponent_behaviour = read_required_rds(file.path(data_dir, "opponent_behaviour_history.rds")),
    fixture_matchup = read_required_rds(file.path(data_dir, "fixture_matchup_table.rds")),
    team_performance = read_required_rds(file.path(data_dir, "team_performance_context.rds")),
    nrl_fixture_source_history = read_required_rds(file.path(data_dir, "nrl_fixture_source_history.rds")),
    source_refresh_log = read_required_rds(file.path(data_dir, "source_refresh_log.rds")),
    team_round_stats_history = read_required_rds(file.path(data_dir, "team_round_stats_history.rds")),
    players_cf_latest = read_required_rds(file.path(data_dir, "players_cf_latest.rds")),
    team_players_latest = read_required_rds(file.path(data_dir, "team_players_latest.rds")),
    player_id_lookup = read_required_rds(file.path(data_dir, "player_id_lookup.rds")),
    player_price_history = read_required_rds(file.path(data_dir, "player_price_history_sc.rds")),
    actual_trade_history = read_required_rds(file.path(data_dir, "actual_trade_history.rds")),
    league_trade_log = read_optional_rds(file.path(data_dir, "league_trade_log.rds")),
    league_trade_round_summary = read_optional_rds(file.path(data_dir, "league_trade_round_summary.rds")),
    league_trade_team_summary = read_optional_rds(file.path(data_dir, "league_trade_team_summary.rds")),
    availability_risk = read_required_rds(file.path(data_dir, "availability_risk_table.rds")),
    squad_round_enriched = read_required_rds(file.path(data_dir, "squad_round_enriched.rds")),
    cash_generation = read_required_rds(file.path(data_dir, "cash_generation_model.rds")),
    master_player = read_required_rds(file.path(data_dir, "master_player_round_latest.rds")),
    checklist_coverage = read_required_rds(file.path(data_dir, "checklist_coverage_status.rds")),
    long_horizon = read_required_rds(file.path(data_dir, "long_horizon_planning_table.rds")),
    prompt_pack_meta = read_optional_text(file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack_meta.json")),
    prompt_pack_text = read_optional_text(file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack.md")),
    origin_watch = read_optional_csv(file.path(data_dir, "manual_inputs", "origin_watch.csv")),
    weekly_notes = read_optional_text(file.path(data_dir, "manual_inputs", "weekly_context_notes.md")),
    strategy_brief = read_optional_text(file.path(data_dir, "manual_inputs", "weekly_strategy_brief.md")),
    strategy_prompt = read_optional_text(file.path(data_dir, "manual_inputs", "strategy_prompt_instructions.md")),
    strategy_log = read_optional_csv(file.path(data_dir, "manual_inputs", "strategy_decision_log.csv"))
  )
}

latest_complete_ladder_round_value <- function(ladder_history, min_complete_teams = 8L) {
  if (is.null(ladder_history) || !nrow(ladder_history) || !"round" %in% names(ladder_history)) {
    return(NA_integer_)
  }

  ladder_history %>%
    group_by(round, user_team_id) %>%
    summarise(
      has_finance = any(!is.na(team_value_total_calc) & !is.na(cash_end_round_calc)),
      .groups = "drop"
    ) %>%
    group_by(round) %>%
    summarise(teams_with_finance = sum(has_finance, na.rm = TRUE), .groups = "drop") %>%
    filter(teams_with_finance >= min_complete_teams) %>%
    arrange(desc(round)) %>%
    slice_head(n = 1) %>%
    pull(round) %>%
    suppressWarnings(as.integer())
}

latest_team_finance <- function(ladder_history) {
  if (is.null(ladder_history) || !nrow(ladder_history)) {
    return(NULL)
  }

  ladder_history %>%
    filter(!is.na(team_value_total_calc) | !is.na(cash_end_round_calc) | !is.na(squad_value_calc)) %>%
    arrange(user_team_id, desc(round), desc(run_ts)) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      user_team_id,
      finance_round = round,
      finance_squad_value_calc = squad_value_calc,
      finance_cash_end_round_calc = cash_end_round_calc,
      finance_team_value_total_calc = team_value_total_calc
    )
}

live_team_finance <- function(team_players_latest, master_player, ladder_history) {
  latest_players <- latest_team_players_snapshot(team_players_latest)
  finance_base <- latest_team_finance(ladder_history)

  if (is.null(latest_players) || !nrow(latest_players) || is.null(master_player) || !nrow(master_player)) {
    return(finance_base)
  }

  latest_players %>%
    left_join(
      master_player %>%
        select(player_id, current_price),
      by = "player_id"
    ) %>%
    group_by(user_team_id, latest_round = round) %>%
    summarise(
      live_squad_value_calc = sum(current_price, na.rm = TRUE),
      live_missing_prices = sum(is.na(current_price)),
      .groups = "drop"
    ) %>%
    left_join(finance_base, by = "user_team_id") %>%
    mutate(
      live_cash_end_round_calc = finance_cash_end_round_calc,
      live_team_value_total_calc = live_squad_value_calc + coalesce(live_cash_end_round_calc, 0)
    )
}

latest_team_structure <- function(structure_health) {
  if (is.null(structure_health) || !nrow(structure_health)) {
    return(NULL)
  }

  structure_health %>%
    arrange(user_team_id, desc(!is.na(avg_projected_score_this_week)), desc(round)) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      user_team_id,
      structure_round = round,
      structure_projected_score = avg_projected_score_this_week,
      structure_locked_players = locked_players,
      structure_dpp_players = dpp_players
    )
}

latest_team_round_stats <- function(team_round_stats_history) {
  if (is.null(team_round_stats_history) || !nrow(team_round_stats_history)) {
    return(NULL)
  }

  team_round_stats_history %>%
    arrange(user_team_id, desc(round), desc(run_ts)) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      user_team_id,
      stats_round = round,
      stats_total_changes = total_changes,
      stats_trade_boosts_used = trade_boosts_used
    )
}

latest_round_by_team <- function(tbl, team_ids = NULL) {
  if (is.null(tbl) || !nrow(tbl) || !"user_team_id" %in% names(tbl) || !"round" %in% names(tbl)) {
    return(NULL)
  }

  working <- tbl
  if (!is.null(team_ids)) {
    working <- working %>% filter(user_team_id %in% team_ids)
  }

  working %>%
    group_by(user_team_id) %>%
    summarise(latest_round = max(round, na.rm = TRUE), .groups = "drop")
}

latest_team_players_snapshot <- function(team_players_latest, team_ids = NULL) {
  latest_rounds <- latest_round_by_team(team_players_latest, team_ids)
  if (is.null(latest_rounds) || !nrow(latest_rounds)) {
    return(NULL)
  }

  team_players_latest %>%
    inner_join(latest_rounds, by = "user_team_id") %>%
    filter(round == latest_round) %>%
    arrange(user_team_id, player_id, desc(run_ts)) %>%
    distinct(user_team_id, player_id, .keep_all = TRUE)
}

latest_team_squad_snapshot <- function(squad_round_enriched, team_ids = NULL) {
  latest_rounds <- latest_round_by_team(squad_round_enriched, team_ids)
  if (is.null(latest_rounds) || !nrow(latest_rounds)) {
    return(NULL)
  }

  squad_round_enriched %>%
    inner_join(latest_rounds, by = "user_team_id") %>%
    filter(round == latest_round) %>%
    arrange(user_team_id, player_id, desc(run_ts)) %>%
    distinct(user_team_id, player_id, .keep_all = TRUE)
}

normalise_name <- function(x) {
  cleaned <- tolower(trimws(gsub("[^a-z0-9]+", " ", x)))
  vapply(strsplit(cleaned, "\\s+"), function(parts) {
    paste(sort(parts[nzchar(parts)]), collapse = " ")
  }, character(1))
}

decode_html_entities <- function(x) {
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&#038;", "&", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&#8217;", "'", x, fixed = TRUE)
  x <- gsub("&#8211;", "-", x, fixed = TRUE)
  x
}

strip_html_text <- function(x) {
  x <- gsub("<br[^>]*>", " ", x, perl = TRUE)
  x <- gsub("<[^>]+>", " ", x, perl = TRUE)
  x <- decode_html_entities(x)
  trimws(gsub("\\s+", " ", x))
}

parse_expected_return_round <- function(x) {
  vapply(x, function(one_x) {
    matched <- regmatches(one_x, regexpr("round\\s+[0-9]+", tolower(one_x), perl = TRUE))
    if (!length(matched) || is.na(matched) || !nzchar(matched)) {
      return(NA_integer_)
    }
    suppressWarnings(as.integer(gsub("[^0-9]", "", matched)))
  }, integer(1))
}

fetch_zero_tackle_injuries <- function(
  player_id_lookup = NULL,
  current_round = NA_integer_,
  page_url = "https://www.zerotackle.com/nrl/injuries-suspensions/"
) {
  html <- tryCatch(
    paste(suppressWarnings(readLines(page_url, warn = FALSE, encoding = "UTF-8")), collapse = "\n"),
    error = function(e) ""
  )

  if (!nzchar(html)) {
    return(NULL)
  }

  row_matches <- gregexpr("(?s)<tr class='table-row-border'.*?</tr>", html, perl = TRUE)
  rows <- regmatches(html, row_matches)[[1]]

  if (!length(rows)) {
    return(NULL)
  }

  parsed_rows <- lapply(rows, function(row) {
    cells <- regmatches(row, gregexpr("(?s)<td[^>]*>.*?</td>", row, perl = TRUE))[[1]]
    if (length(cells) < 4) {
      return(NULL)
    }

    player_name <- strip_html_text(cells[[2]])
    reason <- strip_html_text(cells[[3]])
    expected_return <- strip_html_text(cells[[4]])

    if (!nzchar(player_name)) {
      return(NULL)
    }

    data.frame(
      player_name = player_name,
      zero_tackle_reason = reason,
      zero_tackle_expected_return = expected_return,
      stringsAsFactors = FALSE
    )
  })

  parsed <- bind_rows(parsed_rows)
  if (!nrow(parsed)) {
    return(NULL)
  }

  parsed <- parsed %>%
    distinct(player_name, .keep_all = TRUE) %>%
    mutate(
      name_key = normalise_name(player_name),
      zero_tackle_return_round = parse_expected_return_round(zero_tackle_expected_return),
      zero_tackle_risk_band = case_when(
        grepl("tbc|indef|season", tolower(zero_tackle_expected_return %||% "")) ~ "high",
        !is.na(zero_tackle_return_round) & !is.na(current_round) & zero_tackle_return_round >= current_round + 1L ~ "high",
        !is.na(zero_tackle_return_round) & !is.na(current_round) & zero_tackle_return_round == current_round ~ "medium",
        nzchar(zero_tackle_reason) ~ "medium",
        TRUE ~ NA_character_
      ),
      zero_tackle_status_text = trimws(paste(zero_tackle_reason, zero_tackle_expected_return, sep = " | "))
    )

  parsed$zero_tackle_status_text[parsed$zero_tackle_status_text == "|"] <- NA_character_

  if (!is.null(player_id_lookup) && nrow(player_id_lookup)) {
    parsed <- parsed %>%
      left_join(
        player_id_lookup %>%
          mutate(name_key = normalise_name(full_name)) %>%
          select(player_id, full_name, team_abbrev, name_key),
        by = "name_key"
      )
  }

  parsed
}

latest_projection_lookup <- function(squad_round_enriched, team_ids = NULL) {
  if (is.null(squad_round_enriched) || !nrow(squad_round_enriched)) {
    return(NULL)
  }

  working <- squad_round_enriched
  if (!is.null(team_ids)) {
    working <- working %>% filter(user_team_id %in% team_ids)
  }

  working %>%
    arrange(
      user_team_id,
      player_id,
      desc(!is.na(projected_score_next_3_weeks)),
      desc(round),
      desc(run_ts)
    ) %>%
    group_by(user_team_id, player_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      user_team_id,
      player_id,
      projection_round = round,
      projected_score_this_week_fallback = projected_score_this_week,
      projected_score_next_3_weeks_fallback = projected_score_next_3_weeks,
      projected_value_change_next_3_weeks_fallback = projected_value_change_next_3_weeks,
      sell_urgency_fallback = sell_urgency
    )
}

team_lookup_from_ladder <- function(ladder_history) {
  if (is.null(ladder_history) || !nrow(ladder_history)) {
    return(NULL)
  }

  ladder_history %>%
    arrange(user_team_id, desc(round), desc(run_ts)) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(user_team_id, team_name, coach_name, is_me)
}

pair_trade_rows <- function(players_out, players_in) {
  max_len <- max(length(players_out), length(players_in))
  if (max_len == 0) {
    return(NULL)
  }

  data.frame(
    trade_index = seq_len(max_len),
    sell_player_id = c(players_out, rep(NA_integer_, max_len - length(players_out))),
    buy_player_id = c(players_in, rep(NA_integer_, max_len - length(players_in))),
    stringsAsFactors = FALSE
  )
}

build_trade_log <- function(
  team_players_latest,
  player_id_lookup = NULL,
  player_price_history = NULL,
  ladder_history = NULL,
  actual_trade_history = NULL
) {
  if (is.null(team_players_latest) || !nrow(team_players_latest)) {
    return(NULL)
  }

  roster_by_round <- team_players_latest %>%
    distinct(user_team_id, round, player_id) %>%
    group_by(user_team_id, round) %>%
    summarise(player_ids = list(sort(unique(player_id))), .groups = "drop") %>%
    arrange(user_team_id, round) %>%
    group_by(user_team_id) %>%
    mutate(
      prev_round = lag(round),
      prev_player_ids = lag(player_ids)
    ) %>%
    ungroup()

  inferred_rounds <- roster_by_round %>%
    filter(!is.na(prev_round)) %>%
    rowwise() %>%
    mutate(
      players_in = list(setdiff(player_ids, prev_player_ids)),
      players_out = list(setdiff(prev_player_ids, player_ids)),
      round_change_count = max(length(players_in), length(players_out))
    ) %>%
    ungroup()

  inferred_rows <- bind_rows(lapply(seq_len(nrow(inferred_rounds)), function(idx) {
    row <- inferred_rounds[idx, ]
    pairs <- pair_trade_rows(row$players_out[[1]], row$players_in[[1]])
    if (is.null(pairs)) {
      return(NULL)
    }
    pairs$user_team_id <- row$user_team_id[[1]]
    pairs$round <- row$round[[1]]
    pairs$price_round <- max(1L, row$round[[1]] - 1L)
    pairs$trade_source <- "inferred_round_delta"
    pairs
  }))

  actual_rows <- NULL
  actual_rounds <- NULL
  if (!is.null(actual_trade_history) && nrow(actual_trade_history)) {
    actual_rows <- actual_trade_history %>%
      transmute(
        user_team_id,
        round,
        price_round = pmax(round - 1L, 1L),
        trade_source,
        sell_player_id,
        buy_player_id
      )
    actual_rounds <- actual_rows %>% distinct(user_team_id, round)
  }

  if (!is.null(actual_rounds) && nrow(actual_rounds) && !is.null(inferred_rows) && nrow(inferred_rows)) {
    inferred_rows <- inferred_rows %>%
      anti_join(actual_rounds, by = c("user_team_id", "round"))
  }

  trade_log <- bind_rows(actual_rows, inferred_rows)
  if (is.null(trade_log) || !nrow(trade_log)) {
    return(NULL)
  }

  if (!is.null(player_id_lookup) && nrow(player_id_lookup)) {
    trade_log <- trade_log %>%
      left_join(
        player_id_lookup %>%
          select(
            buy_player_id = player_id,
            buy_player_name = full_name,
            buy_team_abbrev = team_abbrev
          ),
        by = "buy_player_id"
      ) %>%
      left_join(
        player_id_lookup %>%
          select(
            sell_player_id = player_id,
            sell_player_name = full_name,
            sell_team_abbrev = team_abbrev
          ),
        by = "sell_player_id"
      )
  }

  if (!is.null(player_price_history) && nrow(player_price_history)) {
    trade_log <- trade_log %>%
      left_join(
        player_price_history %>%
          select(
            buy_player_id = player_id,
            price_round = round,
            buy_price = price
          ),
        by = c("buy_player_id", "price_round")
      ) %>%
      left_join(
        player_price_history %>%
          select(
            sell_player_id = player_id,
            price_round = round,
            sell_price = price
          ),
        by = c("sell_player_id", "price_round")
      )
  }

  if (!is.null(ladder_history) && nrow(ladder_history)) {
    trade_log <- trade_log %>%
      left_join(team_lookup_from_ladder(ladder_history), by = "user_team_id")
  }

  trade_log %>%
    arrange(round, user_team_id, trade_source)
}

trade_round_summary <- function(trade_log) {
  if (is.null(trade_log) || !nrow(trade_log)) {
    return(NULL)
  }

  trade_log %>%
    group_by(user_team_id, round) %>%
    summarise(
      detected_changes = n(),
      actual_moves = sum(trade_source == "actual_api", na.rm = TRUE),
      inferred_moves = sum(trade_source != "actual_api", na.rm = TRUE),
      .groups = "drop"
    )
}

trade_team_summary <- function(trade_log) {
  round_summary <- trade_round_summary(trade_log)
  if (is.null(round_summary) || !nrow(round_summary)) {
    return(NULL)
  }

  round_summary %>%
    group_by(user_team_id) %>%
    summarise(
      cumulative_detected_changes = sum(detected_changes, na.rm = TRUE),
      latest_trade_round = max(round, na.rm = TRUE),
      .groups = "drop"
    )
}

next_team_fixture_lookup <- function(
  nrl_fixture_source_history,
  fixture_matchup,
  now = Sys.time(),
  close_buffer_hours = 3
) {
  if (is.null(nrl_fixture_source_history) || !nrow(nrl_fixture_source_history)) {
    return(NULL)
  }

  now_utc <- as.POSIXct(now, tz = "UTC")

  future_fixtures <- nrl_fixture_source_history %>%
    arrange(desc(run_ts)) %>%
    group_by(fixture_key, team_abbrev) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    mutate(
      kickoff_at_utc = as.POSIXct(kickoff_at_utc, tz = "UTC"),
      match_state_norm = tolower(trimws(coalesce(match_state, ""))),
      fixture_closed = case_when(
        bye_flag %in% TRUE ~ FALSE,
        match_state_norm %in% c("fulltime", "full time", "post", "completed", "complete") ~ TRUE,
        !is.na(kickoff_at_utc) & now_utc >= kickoff_at_utc + close_buffer_hours * 60 * 60 ~ TRUE,
        TRUE ~ FALSE
      )
    ) %>%
    filter(!fixture_closed, !bye_flag %in% TRUE, !is.na(kickoff_at_utc)) %>%
    arrange(team_abbrev, kickoff_at_utc) %>%
    group_by(team_abbrev) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      team_abbrev,
      upcoming_round = round,
      next_opponent = opponent_abbrev,
      next_kickoff_utc = kickoff_at_utc
    )

  if (is.null(fixture_matchup) || !nrow(fixture_matchup)) {
    return(future_fixtures)
  }

  future_fixtures %>%
    left_join(
      fixture_matchup %>%
        arrange(desc(run_ts)) %>%
        group_by(team_abbrev, round) %>%
        slice_head(n = 1) %>%
        ungroup() %>%
        transmute(
          team_abbrev,
          upcoming_round = round,
          home_away,
          bye_flag,
          next_matchup_rating = matchup_rating_by_player,
          next_matchup_rating_team = matchup_rating_by_team,
          next_3_rounds_difficulty,
          schedule_swing_indicator
        ),
      by = c("team_abbrev", "upcoming_round")
    )
}

infer_effective_round_from_nrl <- function(
  game_rules,
  nrl_fixture_source_history,
  now = Sys.time(),
  season_rounds = 1:27,
  close_buffer_hours = 3
) {
  settings_current_round <- if (!is.null(game_rules) && nrow(game_rules) > 0 && "current_round" %in% names(game_rules)) {
    suppressWarnings(as.integer(game_rules$current_round[[1]]))
  } else {
    NA_integer_
  }
  settings_round_explicit <- if (!is.null(game_rules) && nrow(game_rules) > 0 && "settings_current_round" %in% names(game_rules)) {
    suppressWarnings(as.integer(game_rules$settings_current_round[[1]]))
  } else {
    settings_current_round
  }
  settings_next_round <- if (!is.null(game_rules) && nrow(game_rules) > 0 && "next_round" %in% names(game_rules)) {
    suppressWarnings(as.integer(game_rules$next_round[[1]]))
  } else {
    NA_integer_
  }

  if (is.null(nrl_fixture_source_history) || nrow(nrl_fixture_source_history) == 0) {
    return(list(
      current_round = settings_current_round,
      next_round = settings_next_round %||% (settings_current_round + 1L),
      settings_current_round = settings_round_explicit,
      round_inference_source = "settings_only",
      round_closed_through_utc = as.POSIXct(NA, tz = "UTC")
    ))
  }

  kickoff_col <- if ("kickoff_at_utc" %in% names(nrl_fixture_source_history)) "kickoff_at_utc" else if ("kickoff_utc" %in% names(nrl_fixture_source_history)) "kickoff_utc" else NULL
  state_col <- if ("match_state" %in% names(nrl_fixture_source_history)) "match_state" else if ("match_status" %in% names(nrl_fixture_source_history)) "match_status" else NULL
  fixture_tbl <- nrl_fixture_source_history

  if (!"fixture_key" %in% names(fixture_tbl)) {
    team_col <- if ("team_abbrev" %in% names(fixture_tbl)) fixture_tbl$team_abbrev else rep(NA_character_, nrow(fixture_tbl))
    opponent_col <- if ("opponent_abbrev" %in% names(fixture_tbl)) fixture_tbl$opponent_abbrev else rep(NA_character_, nrow(fixture_tbl))
    fixture_tbl$fixture_key <- paste(
      fixture_tbl$round,
      team_col,
      opponent_col,
      sep = "::"
    )
  }

  fixture_level <- fixture_tbl %>%
    filter(!bye_flag %in% TRUE, !is.na(round)) %>%
    mutate(
      kickoff_value = if (!is.null(kickoff_col)) as.POSIXct(.data[[kickoff_col]], tz = "UTC") else as.POSIXct(NA, tz = "UTC"),
      match_state_norm = if (!is.null(state_col)) tolower(trimws(as.character(.data[[state_col]]))) else NA_character_
    ) %>%
    group_by(round, fixture_key) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    mutate(
      close_cutoff_utc = kickoff_value + close_buffer_hours * 60 * 60,
      fixture_closed = case_when(
        match_state_norm %in% c("fulltime", "full time", "post", "completed", "complete") ~ TRUE,
        !is.na(close_cutoff_utc) & as.POSIXct(now, tz = "UTC") >= close_cutoff_utc ~ TRUE,
        TRUE ~ FALSE
      )
    )

  round_completion <- fixture_level %>%
    group_by(round) %>%
    summarise(
      fixtures_n = n(),
      closed_fixtures_n = sum(fixture_closed, na.rm = TRUE),
      round_closed = fixtures_n > 0 & closed_fixtures_n == fixtures_n,
      round_closed_through_utc = suppressWarnings(max(close_cutoff_utc, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(
      round_closed_through_utc = if_else(
        is.infinite(round_closed_through_utc),
        as.POSIXct(NA, tz = "UTC"),
        round_closed_through_utc
      )
    )

  latest_closed_round <- round_completion %>%
    filter(round_closed %in% TRUE) %>%
    arrange(desc(round)) %>%
    slice_head(n = 1)

  inferred_current_round <- if (nrow(latest_closed_round) == 0) {
    settings_current_round
  } else {
    min(max(season_rounds, na.rm = TRUE), latest_closed_round$round[[1]] + 1L)
  }

  effective_current_round <- max(settings_current_round, inferred_current_round, na.rm = TRUE)
  effective_next_round <- if (!is.na(settings_next_round) && effective_current_round == settings_current_round) {
    settings_next_round
  } else if (effective_current_round >= max(season_rounds, na.rm = TRUE)) {
    NA_integer_
  } else {
    effective_current_round + 1L
  }

  list(
    current_round = effective_current_round,
    next_round = effective_next_round,
    settings_current_round = settings_round_explicit,
    round_inference_source = if (effective_current_round > settings_round_explicit) "nrl_fixture_completion" else "settings",
    round_closed_through_utc = if (nrow(latest_closed_round) == 0) as.POSIXct(NA, tz = "UTC") else latest_closed_round$round_closed_through_utc[[1]]
  )
}

sanitize_price_signal <- function(
  projected_delta,
  current_price,
  last_change,
  recent_average = NA_real_,
  season_average = NA_real_
) {
  plausible_cap <- pmax(90000, pmin(140000, current_price * 0.12))
  raw_is_plausible <- !is.na(projected_delta) &
    !is.na(current_price) &
    !is.infinite(projected_delta) &
    abs(projected_delta) <= plausible_cap

  form_component <- pmin(pmax(coalesce(recent_average, season_average, 0) - coalesce(season_average, recent_average, 0), -30), 30) * 2500
  last_change_component <- pmin(pmax(coalesce(last_change, 0) * 0.7, -80000), 80000)
  heuristic_delta <- pmin(pmax(last_change_component + form_component, -90000), 90000)

  if_else(raw_is_plausible, projected_delta, heuristic_delta)
}

latest_round_at_or_before <- function(tbl, round_limit) {
  if (is.null(tbl) || !"round" %in% names(tbl) || nrow(tbl) == 0 || is.na(round_limit)) {
    return(NA_integer_)
  }

  rounds <- suppressWarnings(as.integer(tbl$round))
  rounds <- rounds[!is.na(rounds) & rounds <= round_limit]
  if (length(rounds) == 0) {
    return(NA_integer_)
  }
  max(rounds)
}

default_slot_template <- function() {
  data.frame(
    slot = c("HOK", "FRF1", "FRF2", "2RF1", "2RF2", "2RF3", "HFB", "5/8", "CTW1", "CTW2", "CTW3", "CTW4", "FLB", "FLX"),
    slot_base = c("HOK", "FRF", "FRF", "2RF", "2RF", "2RF", "HFB", "5/8", "CTW", "CTW", "CTW", "CTW", "FLB", "FLX"),
    stringsAsFactors = FALSE
  )
}

slot_template_from_game_rules <- function(game_rules) {
  if (is.null(game_rules) || !nrow(game_rules) || !"position_rules" %in% names(game_rules)) {
    return(default_slot_template())
  }

  rules <- game_rules$position_rules[[1]]
  if (is.null(rules) || !nrow(rules) || !all(c("position_id", "active_max_players") %in% names(rules))) {
    return(default_slot_template())
  }

  rules <- rules %>%
    filter(active_max_players > 0) %>%
    arrange(position_sort)

  expanded <- bind_rows(lapply(seq_len(nrow(rules)), function(i) {
    one_rule <- rules[i, ]
    n_slots <- suppressWarnings(as.integer(one_rule$active_max_players[[1]]))
    if (is.na(n_slots) || n_slots <= 0) {
      return(NULL)
    }

    data.frame(
      slot = if (n_slots == 1) one_rule$position_id[[1]] else paste0(one_rule$position_id[[1]], seq_len(n_slots)),
      slot_base = rep(one_rule$position_id[[1]], n_slots),
      stringsAsFactors = FALSE
    )
  }))

  if (is.null(expanded) || !nrow(expanded)) {
    default_slot_template()
  } else {
    expanded
  }
}

split_position_tokens <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    return(character())
  }

  raw_value <- as.character(x[[1]])
  raw_value <- gsub("5/8", "FIVEEIGHT", raw_value, fixed = TRUE)

  tokens <- trimws(unlist(strsplit(raw_value, "/", fixed = TRUE)))
  tokens <- tokens[nzchar(tokens)]
  if (!length(tokens)) {
    return(character())
  }

  tokens <- toupper(tokens)
  tokens[tokens %in% c("FIVEEIGHT", "FIVEEIGHTH")] <- "5/8"
  tokens[tokens %in% c("HOOKER")] <- "HOK"
  tokens[tokens %in% c("FRONT ROW", "FRONTROW")] <- "FRF"
  tokens[tokens %in% c("2ND ROW FORWARD", "SECOND ROW", "2ND ROW")] <- "2RF"
  tokens[tokens %in% c("HALFBACK", "HB")] <- "HFB"
  tokens[tokens %in% c("FIVE EIGHTH", "FIVE-EIGHTH", "5-8")] <- "5/8"
  tokens[tokens %in% c("WING/CENTRE", "WING", "CENTRE")] <- "CTW"
  tokens[tokens %in% c("FULLBACK", "FB")] <- "FLB"
  tokens[tokens %in% c("FLEX")] <- "FLX"
  unique(tokens)
}

planner_player_eligibility <- function(positions_string = NA_character_, fallback_position = NA_character_) {
  tokens <- unique(c(split_position_tokens(positions_string), split_position_tokens(fallback_position)))
  tokens[nzchar(tokens)]
}

planner_slot_eligible <- function(eligibility_tokens, slot_base) {
  if (slot_base == "FLX") {
    return(TRUE)
  }
  slot_base %in% eligibility_tokens
}

solve_best_lineup <- function(players, slots, value_col) {
  if (is.null(players) || !nrow(players) || is.null(slots) || !nrow(slots) || !value_col %in% names(players)) {
    return(NULL)
  }

  working <- players
  values <- suppressWarnings(as.numeric(working[[value_col]]))
  values[is.na(values)] <- -1e6
  working$planner_value <- values

  eligibility_map_full <- lapply(slots$slot_base, function(one_slot) {
    which(vapply(working$eligibility, planner_slot_eligible, logical(1), slot_base = one_slot))
  })

  if (any(lengths(eligibility_map_full) == 0)) {
    return(NULL)
  }

  candidate_limit_map <- c(HOK = 3L, FRF = 5L, `2RF` = 6L, HFB = 3L, `5/8` = 3L, CTW = 6L, FLB = 3L, FLX = 8L)
  top_overall_n <- min(nrow(working), nrow(slots) + 6L)
  candidate_rows <- order(working$planner_value, decreasing = TRUE)[seq_len(top_overall_n)]

  for (i in seq_along(eligibility_map_full)) {
    slot_base <- slots$slot_base[[i]]
    slot_limit <- candidate_limit_map[[slot_base]] %||% 4L
    candidate_rows <- unique(c(
      candidate_rows,
      head(
        eligibility_map_full[[i]][order(working$planner_value[eligibility_map_full[[i]]], decreasing = TRUE)],
        slot_limit
      )
    ))
  }

  candidate_rows <- sort(unique(candidate_rows))
  if (length(candidate_rows) < nrow(slots)) {
    candidate_rows <- seq_len(nrow(working))
  }

  reduced <- working[candidate_rows, , drop = FALSE]
  reduced$source_row <- candidate_rows

  row_lookup <- setNames(seq_along(candidate_rows), candidate_rows)
  eligibility_map <- lapply(eligibility_map_full, function(one_map) {
    mapped <- unname(row_lookup[as.character(intersect(one_map, candidate_rows))])
    mapped[!is.na(mapped)]
  })

  if (any(lengths(eligibility_map) == 0)) {
    reduced <- working
    reduced$source_row <- seq_len(nrow(working))
    eligibility_map <- eligibility_map_full
  }

  slot_order <- order(lengths(eligibility_map), ifelse(slots$slot_base == "FLX", 1L, 0L))
  best_score <- -Inf
  best_assignment <- rep(NA_integer_, nrow(slots))

  recurse <- function(depth, available_rows, assignment, current_score) {
    if (depth > length(slot_order)) {
      if (current_score > best_score) {
        best_score <<- current_score
        best_assignment <<- assignment
      }
      return(invisible(NULL))
    }

    remaining_slots <- length(slot_order) - depth + 1
    if (!length(available_rows) || length(available_rows) < remaining_slots) {
      return(invisible(NULL))
    }

    optimistic <- current_score + sum(sort(reduced$planner_value[available_rows], decreasing = TRUE)[seq_len(remaining_slots)])
    if (optimistic <= best_score) {
      return(invisible(NULL))
    }

    slot_idx <- slot_order[[depth]]
    candidates <- intersect(eligibility_map[[slot_idx]], available_rows)
    if (!length(candidates)) {
      return(invisible(NULL))
    }

    candidates <- candidates[order(working$planner_value[candidates], decreasing = TRUE)]

    for (candidate in candidates) {
      new_assignment <- assignment
      new_assignment[[slot_idx]] <- candidate
      recurse(
        depth + 1L,
        setdiff(available_rows, candidate),
        new_assignment,
        current_score + reduced$planner_value[[candidate]]
      )
    }
  }

  recurse(1L, seq_len(nrow(reduced)), rep(NA_integer_, nrow(slots)), 0)

  if (!is.finite(best_score) || any(is.na(best_assignment))) {
    return(NULL)
  }

  slots %>%
    mutate(
      player_row = best_assignment,
      source_row = reduced$source_row[player_row],
      player_id = reduced$player_id[player_row],
      player = reduced$player[player_row]
    )
}

choose_planner_reserves <- function(players, field_ids, final_ids, n_reserves = 4L) {
  if (is.null(players) || !nrow(players)) {
    return(integer())
  }

  bench <- players %>%
    filter(!player_id %in% field_ids) %>%
    mutate(
      final_target = player_id %in% final_ids,
      kickoff_rank = if_else(
        is.na(next_kickoff_utc),
        Inf,
        as.numeric(as.POSIXct(next_kickoff_utc, tz = "UTC"))
      )
    ) %>%
    arrange(desc(final_target), kickoff_rank, desc(real_score), desc(bogus_value))

  head(bench$player_id, n_reserves)
}

format_planner_time <- function(x, fallback = "Before first relevant lock") {
  if (is.null(x) || length(x) == 0) {
    return(fallback)
  }

  vapply(x, function(one_x) {
    if (is.na(one_x)) {
      return(fallback)
    }
    formatted <- format(as.POSIXct(one_x, tz = "UTC"), "%a %I:%M %p %Z", tz = "Australia/Sydney")
    sub(" 0", " ", formatted, fixed = TRUE)
  }, character(1))
}

format_player_label <- function(player_name, slot = NULL) {
  if (!is.null(slot) && nzchar(slot)) {
    paste0(player_name, " (", slot, ")")
  } else {
    player_name
  }
}

describe_reserve_transition <- function(old_ids, new_ids, player_lookup) {
  old_ids <- old_ids %||% integer()
  new_ids <- new_ids %||% integer()

  turned_on <- setdiff(new_ids, old_ids)
  turned_off <- setdiff(old_ids, new_ids)

  pieces <- c()
  if (length(turned_on)) {
    pieces <- c(
      pieces,
      paste0("Reserve ON: ", paste(player_lookup[as.character(turned_on)], collapse = ", "))
    )
  }
  if (length(turned_off)) {
    pieces <- c(
      pieces,
      paste0("Reserve OFF: ", paste(player_lookup[as.character(turned_off)], collapse = ", "))
    )
  }

  if (!length(pieces)) {
    "No reserve change"
  } else {
    paste(pieces, collapse = " | ")
  }
}

describe_slot_changes <- function(from_assign, to_assign, player_lookup) {
  if (is.null(from_assign) || is.null(to_assign) || !nrow(from_assign) || !nrow(to_assign)) {
    return("No lineup change")
  }

  lookup_name <- function(player_id, fallback = "bench") {
    if (is.na(player_id)) {
      return(fallback)
    }
    matched <- unname(player_lookup[as.character(player_id)])
    if (!length(matched) || is.na(matched) || !nzchar(matched)) {
      fallback
    } else {
      matched
    }
  }

  merged <- from_assign %>%
    select(slot, from_player_id = player_id) %>%
    full_join(
      to_assign %>% select(slot, to_player_id = player_id),
      by = "slot"
    ) %>%
    filter(from_player_id != to_player_id)

  if (!nrow(merged)) {
    return("No lineup change")
  }

  paste(
    apply(merged, 1, function(row) {
      from_name <- lookup_name(row[["from_player_id"]], "bench")
      to_name <- lookup_name(row[["to_player_id"]], "bench")
      paste0(row[["slot"]], ": ", from_name, " -> ", to_name)
    }),
    collapse = " | "
  )
}

prepare_planner_roster <- function(
  base_players,
  master_player,
  player_id_lookup,
  availability_risk,
  zero_tackle_tbl,
  next_fixture_lookup,
  team_performance,
  current_round,
  now = Sys.time()
) {
  if (is.null(base_players) || !nrow(base_players)) {
    return(NULL)
  }

  if (!"team_abbrev" %in% names(base_players)) {
    base_players$team_abbrev <- NA_character_
  }
  if (!"position" %in% names(base_players)) {
    base_players$position <- NA_character_
  }
  if (!"full_name" %in% names(base_players)) {
    base_players$full_name <- NA_character_
  }

  attack_lookup <- NULL
  if (!is.null(team_performance) && nrow(team_performance)) {
    attack_lookup <- team_performance %>%
      filter(!is.na(attacking_trend_last_3)) %>%
      arrange(desc(round), desc(run_ts)) %>%
      group_by(team_abbrev) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      transmute(team_abbrev, attacking_trend_last_3)
  }

  base_players %>%
    left_join(
      player_id_lookup %>%
        transmute(player_id, lookup_name = full_name, lookup_team_abbrev = team_abbrev),
      by = "player_id"
    ) %>%
    left_join(
      master_player %>%
        transmute(
          player_id,
          master_name = full_name,
          master_team_abbrev = team,
          positions_string = positions,
          current_price,
          breakeven,
          current_season_average,
          average_3_round,
          average_5_round,
          ownership_percentage,
          total_points,
          games_played,
          master_status = status,
          injury_detail,
          master_expected_return = expected_return,
          goal_kicking_status,
          starting_status,
          master_locked_flag = locked_flag,
          master_played_status = played_status,
          active_flag
        ),
      by = "player_id"
    ) %>%
    left_join(
      availability_risk %>%
        transmute(
          player_id,
          availability_risk_band = risk_band,
          injury_suspension_status_text,
          availability_expected_return = expected_return,
          availability_locked_flag = locked_flag,
          availability_played_status = played_status_display
        ),
      by = "player_id"
    ) %>%
    left_join(
      zero_tackle_tbl %>%
        transmute(
          player_id,
          zero_tackle_reason,
          zero_tackle_expected_return,
          zero_tackle_risk_band,
          zero_tackle_status_text
        ),
      by = "player_id"
    ) %>%
    mutate(
      player = coalesce(lookup_name, master_name, full_name),
      team_abbrev = coalesce(team_abbrev, lookup_team_abbrev, master_team_abbrev),
      current_position = coalesce(position, positions_string),
      positions_string = coalesce(positions_string, current_position)
    ) %>%
    left_join(next_fixture_lookup, by = "team_abbrev") %>%
    left_join(attack_lookup, by = "team_abbrev") %>%
    mutate(
      eligibility = lapply(seq_len(n()), function(i) planner_player_eligibility(positions_string[[i]], current_position[[i]])),
      next_kickoff_utc = as.POSIXct(next_kickoff_utc, tz = "UTC"),
      bye_this_round = !is.na(upcoming_round) & upcoming_round > current_round,
      risk_band = coalesce(zero_tackle_risk_band, availability_risk_band, "low"),
      injury_text = coalesce(zero_tackle_status_text, injury_suspension_status_text, injury_detail, master_status),
      expected_return = coalesce(zero_tackle_expected_return, availability_expected_return, master_expected_return),
      recent_average = coalesce(average_3_round, current_season_average, 0),
      matchup_rating = coalesce(next_matchup_rating, next_matchup_rating_team, 24),
      attack_trend = coalesce(attacking_trend_last_3, 0),
      goal_bonus = if_else(grepl("goal|kicker|primary", tolower(coalesce(goal_kicking_status, ""))), 4, 0),
      starting_bonus = if_else(grepl("start", tolower(coalesce(starting_status, ""))), 3, 0),
      risk_penalty = case_when(
        risk_band == "high" ~ 38,
        risk_band == "medium" ~ 18,
        TRUE ~ 0
      ),
      inactive_penalty = if_else(active_flag %in% FALSE, 18, 0),
      bye_penalty = if_else(bye_this_round, 12, 0),
      locked_now = !is.na(next_kickoff_utc) & as.POSIXct(now, tz = "UTC") >= next_kickoff_utc,
      real_score = recent_average +
        matchup_rating / 3 +
        pmax(attack_trend, 0) / 10 +
        goal_bonus +
        starting_bonus -
        risk_penalty -
        inactive_penalty -
        bye_penalty
    ) %>%
    mutate(
      player = coalesce(player, paste("Player", player_id)),
      team_abbrev = coalesce(team_abbrev, "UNK")
    )
}

theme_sc <- bs_theme(
  version = 5,
  bg = "#f4f1e8",
  fg = "#14231c",
  primary = "#0b6b3a",
  secondary = "#103f5c",
  success = "#198754",
  base_font = font_google("Manrope"),
  heading_font = font_google("Oswald")
)

metric_card <- function(title, output_id, subtitle = NULL) {
  card(
    class = "sc-card metric-card",
    div(
      class = "card-body",
      tags$div(class = "metric-label", title),
      tags$div(class = "metric-value", textOutput(output_id)),
      if (!is.null(subtitle)) tags$div(class = "metric-subtitle", subtitle)
    )
  )
}

explainer_details <- function(summary_text, ...) {
  tags$details(
    class = "sc-explainer",
    tags$summary(summary_text),
    div(class = "sc-explainer-body", ...)
  )
}

build_field_dictionary <- function() {
  tibble::tribble(
    ~table_name, ~field, ~definition,
    "League Table", "Pos", "Current head-to-head ladder position in your SuperCoach league.",
    "League Table", "Team", "SuperCoach team name.",
    "League Table", "Coach", "Coach display name from the league ladder feed.",
    "League Table", "Wins", "Head-to-head wins recorded in the league ladder.",
    "League Table", "Losses", "Head-to-head losses recorded in the league ladder.",
    "League Table", "Prev Round Pts", "Total SuperCoach points through the last completed round snapshot.",
    "League Table", "Current Round Pts", "Live points in the in-progress current round. This stays at 0 until games begin.",
    "League Table", "Total Pts (Live)", "Prev Round Pts plus Current Round Pts, so you can see a live-running season total.",
    "League Table", "Squad Value", "Current sum of rostered player prices only.",
    "League Table", "Cash", "Current bank balance.",
    "League Table", "Total Value", "Squad Value plus Cash.",
    "League Table", "Changes", "Latest detected trade/change count for that team, using actual API trades where available and inferred roster deltas otherwise.",
    "League Table", "Boosts Used", "Trade boosts used by that team so far.",
    "Fixture Runway Breakdown", "Side", "You or your current opponent.",
    "Fixture Runway Breakdown", "Round", "NRL round in the forward runway.",
    "Fixture Runway Breakdown", "Club", "NRL club represented in that side's latest known squad.",
    "Fixture Runway Breakdown", "Players From Club", "How many rostered players that side owns from the club.",
    "Fixture Runway Breakdown", "Opponent", "Next scheduled NRL opponent for that club in the official draw.",
    "Fixture Runway Breakdown", "Fixture Rating", "Stored next-three-round difficulty score for that club. Higher means a more favorable scoring environment in this app.",
    "Fixture Runway Breakdown", "Weighted Contribution", "Fixture Rating multiplied by Players From Club. These contributions roll up into the runway line.",
    "Fixture Runway Breakdown", "Short-Term Swing", "Whether the next two rounds look easier, harder, or stable relative to the broader five-round outlook.",
    "Fixture Runway Breakdown", "Bye", "Yes if that club is on a bye in that round window.",
    "Upcoming Fixture Market Watchlist", "player", "Player name.",
    "Upcoming Fixture Market Watchlist", "team", "NRL club abbreviation.",
    "Upcoming Fixture Market Watchlist", "next_opponent", "Next scheduled NRL opponent by date/time, not just a blind next round join.",
    "Upcoming Fixture Market Watchlist", "recent_average", "Recent scoring form, primarily from the 3-round average with season average fallback.",
    "Upcoming Fixture Market Watchlist", "matchup", "Immediate matchup rating from the fixture model. Higher means a friendlier setup.",
    "Upcoming Fixture Market Watchlist", "category", "Top-level label driven by injury status, price cycle, form, and fixture quality.",
    "Upcoming Fixture Market Watchlist", "price_signal", "Heuristic next-price-cycle move from recent form and price trend. Not an official breakeven.",
    "Upcoming Fixture Market Watchlist", "swing", "Short-term schedule swing: easier_short_term, harder_short_term, or stable.",
    "Upcoming Fixture Market Watchlist", "maturity", "Cash-cycle maturity status such as rising, flattening, or near_peak_or_peaked.",
    "Upcoming Fixture Market Watchlist", "why", "Plain-language explanation of the strongest factors driving the category.",
    "Market Watch Factor Breakdown", "Recent Avg", "Base form component feeding the watchlist score.",
    "Market Watch Factor Breakdown", "Matchup Component", "Immediate fixture contribution to the overall signal score.",
    "Market Watch Factor Breakdown", "Attack Component", "Contribution from the player's club attacking trend.",
    "Market Watch Factor Breakdown", "Price Component", "Contribution from the current price-cycle signal.",
    "Market Watch Factor Breakdown", "Bye Penalty", "Penalty applied if the club is on a bye.",
    "Market Watch Factor Breakdown", "Injury Penalty", "Penalty applied when the player is flagged in the injury feed.",
    "Market Watch Factor Breakdown", "Signal Score", "Combined watchlist score before ranking.",
    "Your Squad Leverage Watch", "Proj 3w", "Projected next-three-week score with fallback to the latest non-missing stored projection.",
    "Your Squad Leverage Watch", "Price Signal", "Heuristic next-price-cycle move.",
    "Your Squad Leverage Watch", "Matchup", "Immediate matchup rating for the player's club.",
    "Your Squad Leverage Watch", "Swing", "Short-term fixture swing label.",
    "Your Squad Leverage Watch", "Urgency", "High/medium/normal urgency blending injuries, price cooling, byes, and matchup quality.",
    "Your Squad Leverage Watch", "Why", "Short explanation of the dominant factor behind the row.",
    "Cash Generation Radar", "current_price", "Current player price.",
    "Cash Generation Radar", "category", "Cash-cycle label such as Cash cow upside, Peak risk, Cooling premium, or Injury hold.",
    "Cash Generation Radar", "next_signal", "Expected next price-cycle move.",
    "Cash Generation Radar", "total_cash", "Total cash generated since acquisition or starting point. Negative means value has already burned off.",
    "Cash Generation Radar", "maturity", "Current point in the player's cash-generation cycle.",
    "Cash Generation Radar", "why", "Short explanation of why the player landed in the category.",
    "Availability Watch", "Risk", "Risk band from saved availability plus Zero Tackle supplementation.",
    "Availability Watch", "Status", "Best available injury/suspension/bye status text.",
    "Availability Watch", "Return / Note", "Expected return round or explanatory note when available.",
    "Availability Watch", "Locked", "Whether the player is currently locked in SuperCoach.",
    "Availability Watch", "Proj 3w", "Projected next-three-week score.",
    "Opponent Fingerprint", "Avg Player Projection", "Average projected player score across the opponent's latest known squad. Not a whole-team projected total.",
    "Opponent Fingerprint", "Detected Changes", "Cumulative detected trade/change count from stored trade summaries.",
    "Opponent Fingerprint", "Latest Change Round", "Most recent round where a trade/change was detected.",
    "Opponent Fingerprint", "Boosts Used", "Trade boosts used so far.",
    "Trade Logs", "Source", "Actual API means confirmed from the authenticated endpoint. Inferred round delta means derived from roster changes between snapshots.",
    "Trade Logs", "Sell Price", "Approximated at the previous round's finalised player price.",
    "Trade Logs", "Buy Price", "Approximated at the previous round's finalised player price.",
    "Planner Starting Setup", "Placement", "Where the player should sit before the first lock: either a field slot or Bench.",
    "Planner Starting Setup", "Reserve ON", "Whether that player should carry one of the four active reserve highlights in the starting disguise.",
    "Planner Starting Setup", "Bogus Score", "Deception utility used to choose the initial fake lineup. Higher means a better disguise or placeholder.",
    "Planner Starting Setup", "Note", "Plain-language reason the player is starting on field or being hidden on the bench.",
    "Planner Move Schedule", "When", "Australia/Sydney time to make the move, usually ten minutes before the relevant kickoff.",
    "Planner Move Schedule", "Move", "Exact action to take in SuperCoach at that time.",
    "Planner Move Schedule", "Reserve Change", "Reserve toggles to make alongside the move so only four reserves stay highlighted.",
    "Planner Move Schedule", "Why", "Why that timing matters for rolling lockout or disguise.",
    "Planner Final Intended Counting Side", "Slot", "The final active position the player should occupy once the round is set correctly.",
    "Planner Final Intended Counting Side", "Real Score", "The score-maximising heuristic used to pick the real final side from your roster after trades.",
    "Planner Final Intended Counting Side", "Why", "Plain-language reason the planner wants that player counting in that slot.",
    "Strategy Log", "decision_window", "When the decision was made, for example pre-lockout, post-team-list, or late mail.",
    "Strategy Log", "strategy_mode", "The round-level posture such as cash build, head-to-head protect, aggression, pre-Origin prep, or bye prep.",
    "Strategy Log", "priority_1 / priority_2 / priority_3", "The top three moves or strategic aims for that week.",
    "Strategy Log", "opponent_read", "How you read the matchup or league behaviour that week.",
    "Strategy Log", "execution_status", "Whether the plan was planned, executed, partly executed, or missed.",
    "Strategy Log", "result_review", "Short review of how the prior strategy actually played out.",
    "Strategy Log", "next_week_carry_forward", "What should still matter next week.",
    "League Schedule Window", "current_score", "Live matchup score for the upcoming/current league matchup window where available.",
    "Refresh Log", "settings_current_round", "Round reported directly by SuperCoach settings.",
    "Refresh Log", "effective_current_round", "Round the pipeline actually uses after NRL fixture-completion logic.",
    "Refresh Log", "round_inference_source", "Whether the current round came from settings or fixture completion inference.",
    "Refresh Log", "mutable_rounds", "Rounds the refresh considered still likely to change.",
    "Refresh Log", "rounds_pulled", "SuperCoach rounds refreshed in that run.",
    "Refresh Log", "player_history_refreshed_n", "Number of player histories refreshed in that run."
  )
}

responsive_table <- function(output_id) {
  div(class = "table-wrap", tableOutput(output_id))
}

ui <- page_navbar(
  title = "SuperCoach War Room",
  theme = theme_sc,
  bg = "#0f2e23",
  inverse = FALSE,
  fillable = FALSE,
  header = tags$head(
    tags$style(HTML("
      body {
        background:
          linear-gradient(180deg, rgba(11,107,58,0.08), rgba(244,241,232,0.96) 180px),
          repeating-linear-gradient(
            180deg,
            rgba(11,107,58,0.03) 0px,
            rgba(11,107,58,0.03) 22px,
            rgba(255,255,255,0.0) 22px,
            rgba(255,255,255,0.0) 44px
          ),
          #f4f1e8;
      }
      .navbar { box-shadow: 0 10px 28px rgba(6, 35, 26, 0.18); }
      .navbar-brand, .nav-link {
        font-family: 'Oswald', sans-serif;
        letter-spacing: 0.04em;
        text-transform: uppercase;
      }
      .navbar .nav-link,
      .navbar .navbar-brand {
        color: rgba(244, 241, 232, 0.95) !important;
      }
      .navbar .nav-link.active {
        color: #f4b63f !important;
      }
      .bslib-page-nav {
        max-width: 1220px;
        margin: 0 auto;
      }
      .bslib-page-nav .tab-content {
        padding-top: 1rem;
      }
      .hero-card {
        background: linear-gradient(135deg, #103f5c 0%, #0b6b3a 100%);
        color: #f8f6ef;
        border: 0;
        border-radius: 28px;
        box-shadow: 0 20px 40px rgba(7, 43, 32, 0.22);
        margin-bottom: 1rem;
      }
      .hero-kicker {
        font-size: 0.78rem;
        letter-spacing: 0.18em;
        text-transform: uppercase;
        opacity: 0.82;
        margin-bottom: 0.45rem;
      }
      .hero-title {
        font-family: 'Oswald', sans-serif;
        font-size: 2.2rem;
        line-height: 1.05;
        margin-bottom: 0.55rem;
      }
      .hero-copy, .hero-note {
        font-size: 0.98rem;
        max-width: 760px;
        opacity: 0.92;
      }
      .hero-note {
        margin-top: 0.75rem;
        font-weight: 700;
      }
      .action-bar {
        display: flex;
        gap: 0.8rem;
        flex-wrap: wrap;
        margin-top: 1rem;
      }
      .btn-sc, .btn-sc-outline {
        border-radius: 999px;
        font-weight: 800;
        letter-spacing: 0.04em;
        text-transform: uppercase;
        padding: 0.8rem 1.25rem;
        transition: transform 120ms ease, box-shadow 120ms ease, background-color 120ms ease;
      }
      .btn-sc {
        background: #f4b63f;
        border: 0;
        color: #112018;
        box-shadow: 0 10px 24px rgba(244, 182, 63, 0.25);
      }
      .btn-sc:hover, .btn-sc:focus {
        background: #ffc857;
        color: #112018;
        transform: translateY(-1px);
        box-shadow: 0 14px 28px rgba(244, 182, 63, 0.3);
      }
      .btn-sc:active, .btn-sc-outline:active, .btn-sc.clicked, .btn-sc-outline.clicked {
        transform: scale(0.97);
      }
      .btn-sc-outline {
        background: rgba(255,255,255,0.12);
        border: 1px solid rgba(255,255,255,0.3);
        color: #f8f6ef;
      }
      .btn-sc-outline:hover, .btn-sc-outline:focus {
        background: rgba(255,255,255,0.18);
        color: #ffffff;
      }
      .metric-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 0.85rem;
        margin-bottom: 1rem;
      }
      .metric-card {
        min-height: 138px;
      }
      .sc-card {
        border: 0;
        border-radius: 24px;
        background: rgba(255,255,255,0.92);
        box-shadow: 0 16px 34px rgba(18, 44, 33, 0.1);
        margin-bottom: 1rem;
        overflow: visible;
      }
      .sc-card .card-header {
        background: linear-gradient(90deg, rgba(16,63,92,0.08), rgba(11,107,58,0.05));
        border-bottom: 1px solid rgba(16,63,92,0.08);
        color: #0f2e23;
        font-family: 'Oswald', sans-serif;
        letter-spacing: 0.03em;
        text-transform: uppercase;
      }
      .metric-label {
        color: #567569;
        font-size: 0.76rem;
        font-weight: 800;
        letter-spacing: 0.14em;
        text-transform: uppercase;
      }
      .metric-value {
        font-family: 'Oswald', sans-serif;
        font-size: 2rem;
        line-height: 1;
        margin-top: 0.55rem;
        color: #0f2e23;
      }
      .metric-subtitle, .section-note {
        color: #56645c;
        font-size: 0.9rem;
        margin-top: 0.5rem;
      }
      .section-stack {
        display: flex;
        flex-direction: column;
        gap: 0.15rem;
      }
      .table-wrap {
        overflow-x: auto;
        overflow-y: visible;
      }
      .table {
        margin-bottom: 0;
      }
      .table th {
        font-family: 'Oswald', sans-serif;
        letter-spacing: 0.02em;
      }
      .sc-explainer {
        margin: 0.85rem 1rem 0;
        border: 1px solid rgba(16,63,92,0.12);
        border-radius: 16px;
        background: rgba(248,246,239,0.92);
        overflow: hidden;
      }
      .sc-explainer summary {
        cursor: pointer;
        list-style: none;
        padding: 0.85rem 1rem;
        font-weight: 800;
        color: #103f5c;
        display: flex;
        align-items: center;
        justify-content: space-between;
      }
      .sc-explainer summary::-webkit-details-marker {
        display: none;
      }
      .sc-explainer summary::after {
        content: 'Open';
        font-size: 0.78rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #567569;
      }
      .sc-explainer[open] summary::after {
        content: 'Close';
      }
      .sc-explainer-body {
        padding: 0 1rem 1rem;
      }
      .definition-list {
        margin: 0 0 0.85rem;
        color: #44564f;
        font-size: 0.92rem;
      }
      .definition-list dt {
        font-weight: 800;
        color: #103f5c;
        margin-top: 0.6rem;
      }
      .definition-list dd {
        margin-left: 0;
      }
      .shiny-notification {
        border-radius: 16px;
        box-shadow: 0 18px 32px rgba(15, 46, 35, 0.22);
      }
      pre {
        white-space: pre-wrap;
        word-break: break-word;
        background: #f8f6ef;
        border-radius: 16px;
        padding: 1rem;
      }
      @media (max-width: 900px) {
        .hero-title { font-size: 1.75rem; }
        .metric-grid { grid-template-columns: 1fr; }
      }
    ")),
    tags$script(HTML("
      document.addEventListener('click', function(evt) {
        if (!evt.target.classList.contains('btn-sc') && !evt.target.classList.contains('btn-sc-outline')) return;
        evt.target.classList.add('clicked');
        window.setTimeout(function() { evt.target.classList.remove('clicked'); }, 220);
      });
    "))
  ),
  nav_panel(
    "Overview",
    card(
      class = "hero-card",
      full_screen = TRUE,
      card_body(
        tags$div(class = "hero-kicker", "Live league pulse"),
        tags$div(class = "hero-title", "Scan the week fast, then send the real pack to GPT."),
        tags$div(class = "hero-copy", "This board is for quick speculation, freshness checks, and matchup feel. GitHub Actions now refreshes the repo snapshot on a schedule, and this app is seeded from that deployed snapshot."),
        div(
          class = "action-bar",
          actionButton("refresh_app_data", "Reload Bundled Snapshot", class = "btn-sc"),
          downloadButton("download_prompt_pack", "Download Latest GPT Pack", class = "btn-sc-outline")
        ),
        tags$div(class = "hero-note", textOutput("snapshot_status_text"))
      )
    ),
    div(
      class = "metric-grid",
      metric_card("Current Round", "current_round_text"),
      metric_card("Latest Squad Pull", "snapshot_round_text"),
      metric_card("Last Data Refresh", "last_refresh_text"),
      metric_card("Current Matchup", "matchup_text"),
      metric_card("Latest GPT Pack", "latest_export_text")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("League Financial Snapshot"),
      plotOutput("league_finance_plot", height = "360px"),
      card_footer(class = "section-note", "Squad value vs cash balance, with projected weekly strength shown by bubble size.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Fixture Runway"),
      plotOutput("fixture_runway_plot", height = "340px"),
      explainer_details(
        "How this score is built",
        tags$p(
          class = "section-note",
          "Each point is a squad-weighted average of the official fixture difficulty attached to every NRL club represented in that side's latest known squad. This is not a raw ladder ranking; it is a blended squad exposure score."
        ),
        tags$dl(
          class = "definition-list",
          tags$dt("Weighted fixture difficulty"),
          tags$dd("Average of each represented club's next-three-round difficulty, weighted by how many players you or your opponent own from that club."),
          tags$dt("bye:n"),
          tags$dd("Number of rostered players on clubs with a bye in that round window."),
          tags$dt("Why your line moves"),
          tags$dd("It moves when your latest squad composition changes or when the official NRL draw/context changes for the clubs your squad is exposed to.")
        ),
        responsive_table("fixture_runway_breakdown_table")
      ),
      card_footer(class = "section-note", "Weighted difficulty for each side's latest known squad, using each club's next scheduled NRL fixture from the official draw rather than a blind next-round jump.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("League Schedule Window"),
      responsive_table("league_schedule_table")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Data Diagnostics"),
      verbatimTextOutput("data_diagnostic_text")
    )
  ),
  nav_panel(
    "Matchup",
    div(
      class = "section-stack",
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Head-to-Head Comparison"),
        plotOutput("matchup_compare_plot", height = "360px"),
        card_footer(class = "section-note", "Compares bank, team value, average projected player score, and DPP depth from each side's latest available squad snapshot.")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Opponent Fingerprint"),
        responsive_table("opponent_profile_table")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Your Availability Watch"),
        responsive_table("your_availability_table")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Opponent Availability Watch"),
        responsive_table("opponent_availability_table")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Opponent Trade Timeline"),
        plotOutput("opponent_trade_plot", height = "320px"),
        card_footer(class = "section-note", "Uses actual SuperCoach trade rows where available, otherwise infers round-to-round roster deltas from saved squad snapshots.")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("NRL Club Exposure"),
        plotOutput("club_exposure_plot", height = "320px"),
        card_footer(class = "section-note", "Mirrored bars make overlap easier to read: your clubs push right, opponent clubs push left.")
      )
    ),
  ),
  nav_panel(
    "Signals",
    div(
      class = "section-stack",
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Your Squad Leverage Watch"),
        responsive_table("your_signal_table"),
        card_footer(class = "section-note", "Proj 3w falls back to the last non-missing player projection when the live round slice is only partially populated. Urgency blends injuries, price cooling, byes, and matchup.")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Upcoming Fixture Market Watchlist"),
        responsive_table("market_watch_table"),
        explainer_details(
          "Definitions and factor breakdown",
          tags$p(
            class = "section-note",
            "This watchlist ranks players by a blended signal from recent scoring, fixture quality, team attack trend, price cycle, and injury availability. Open this panel to inspect the exact labels and score pieces."
          ),
          tags$dl(
            class = "definition-list",
            tags$dt("Category"),
            tags$dd("Buy target = strong price momentum plus a playable fixture. Fixture play = matchup-led watch. Premium hold = elite scorer whose price may cool. Price rise watch = more value growth likely. Injury watch = currently flagged unavailable/risky. Monitor = worth tracking but not a hard push."),
            tags$dt("Swing"),
            tags$dd("easier_short_term = next two rounds are easier than the wider five-round runway. harder_short_term = next two are tougher. stable = no strong near-term swing."),
            tags$dt("Why"),
            tags$dd("Plain-language explanation chosen from the strongest contributing factor or combination of factors."),
            tags$dt("Price Signal"),
            tags$dd("Heuristic next-price-cycle move, not an official breakeven. It leans on recent form and the stored price trend.")
          ),
          responsive_table("market_watch_factor_table")
        ),
        card_footer(class = "section-note", "Category definitions: Buy target = price upside plus playable fixture; Fixture play = matchup-driven watch; Premium hold = premium scorer whose price may cool; Injury watch = likely unavailable despite signal.")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("Cash Generation Radar"),
        responsive_table("cash_watch_table"),
        card_footer(class = "section-note", "Next Signal estimates the next price move off the current price cycle and recent scoring. Negative total cash means a player has already burned value since acquisition.")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("NRL Context Watch"),
        responsive_table("nrl_context_table")
      ),
      card(
        class = "sc-card",
        full_screen = TRUE,
        card_header("NRL Trend Radar"),
        plotOutput("team_performance_plot", height = "360px"),
        card_footer(class = "section-note", "Solid lines are actual points scored by round. Faint dashed lines show the rolling three-game attacking average.")
      )
    )
  ),
  nav_panel(
    "League",
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("League Table"),
      responsive_table("league_snapshot_table"),
      explainer_details(
        "League table definitions",
        tags$p(
          class = "section-note",
          "This table mixes ladder results with live points and live finance. The record columns come from the official SuperCoach league ladder, while value and cash come from each team's latest known squad plus current player prices."
        ),
        tags$dl(
          class = "definition-list",
          tags$dt("Total Pts (Live)"),
          tags$dd("Season points through the last completed round plus any live points in the current round."),
          tags$dt("Squad Value vs Total Value"),
          tags$dd("Squad Value is players only. Total Value is Squad Value plus Cash."),
          tags$dt("Changes"),
          tags$dd("Detected roster changes/trades from the stored league trade summary, not just your own team.")
        )
      ),
      card_footer(class = "section-note", "Prev Round Pts comes from the last complete league-finance snapshot. Current Round Pts is the live round score feed, which will stay at 0 until games start.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Refresh Log"),
      responsive_table("source_health_table")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Coverage Gaps"),
      responsive_table("coverage_gap_table")
    )
  ),
  nav_panel(
    "Strategy",
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Current Weekly Strategy Brief"),
      verbatimTextOutput("strategy_brief_text"),
      card_footer(class = "section-note", "Edit data/supercoach_league_21064/manual_inputs/weekly_strategy_brief.md to set the round posture and strategic constraints before rebuilding the GPT pack.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Strategy Prompt Instructions"),
      verbatimTextOutput("strategy_prompt_text"),
      card_footer(class = "section-note", "These instructions are appended to the GPT pack so the model reasons about strategy, not just players.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Rolling Strategy Decision Log"),
      responsive_table("strategy_log_table"),
      card_footer(class = "section-note", "File the GPT's weekly output back into strategy_decision_log.csv so next week's pack can review and carry it forward.")
    )
  ),
  nav_panel(
    "Trades",
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Current Matchup Trade Log"),
      responsive_table("matchup_trade_table"),
      card_footer(class = "section-note", "Trade price is approximated at the previous round's finalised price. Source shows whether the row came from the SuperCoach API or roster-delta inference.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("League-Wide Trade Log"),
      responsive_table("league_trade_table")
    )
  ),
  nav_panel(
    "Planner",
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Rolling Lockout Deception Planner"),
      div(
        class = "card-body",
        tags$p(
          class = "section-note",
          "Pick up to three trades. The planner will build a score-maximising final team, a low-reveal bogus team to start the round, and the exact moves needed to let the real side fall into place under rolling lockout."
        ),
        fluidRow(
          column(
            width = 6,
            selectizeInput("planner_trade_out_1", "Trade out 1", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          ),
          column(
            width = 6,
            selectizeInput("planner_trade_in_1", "Trade in 1", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          )
        ),
        fluidRow(
          column(
            width = 6,
            selectizeInput("planner_trade_out_2", "Trade out 2", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          ),
          column(
            width = 6,
            selectizeInput("planner_trade_in_2", "Trade in 2", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          )
        ),
        fluidRow(
          column(
            width = 6,
            selectizeInput("planner_trade_out_3", "Trade out 3", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          ),
          column(
            width = 6,
            selectizeInput("planner_trade_in_3", "Trade in 3", choices = c("No trade" = ""), selected = "", options = list(placeholder = "No trade"))
          )
        ),
        tags$div(class = "hero-note", textOutput("planner_status_text"))
      )
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Bogus Starting Setup"),
      responsive_table("planner_start_table"),
      card_footer(class = "section-note", "This is the legal pre-first-lock setup intended to reveal as little as possible while still preserving your path to the final scoring side.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Exact Move Schedule"),
      responsive_table("planner_move_table"),
      card_footer(class = "section-note", "Times are shown in Australia/Sydney and aim for a small safety buffer before each relevant kickoff.")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Final Intended Counting Side"),
      responsive_table("planner_final_table"),
      explainer_details(
        "Planner field dictionary",
        tags$dl(
          class = "definition-list",
          tags$dt("Bogus Score"),
          tags$dd("The deception utility used for the starting team. Higher means a better disguise, later placeholder, or better trade concealment."),
          tags$dt("Real Score"),
          tags$dd("The scoring heuristic used to pick the real final 14. It blends recent scoring, fixture quality, attack trend, goal-kicking, starting role, byes, and injury penalties."),
          tags$dt("Reserve ON"),
          tags$dd("One of the four reserve highlights for the current state. These are rotated through the move schedule as the real team comes on field.")
        )
      )
    )
  ),
  nav_panel(
    "Dictionary",
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Field Dictionary"),
      div(
        class = "card-body",
        selectInput(
          "dictionary_table_filter",
          "Table",
          choices = c("All tables", sort(unique(build_field_dictionary()$table_name))),
          selected = "All tables"
        )
      ),
      responsive_table("field_dictionary_table"),
      card_footer(class = "section-note", "This is the app-side field dictionary for displayed tables and breakdown tables. Plot cards are documented in their expandable explainers.")
    )
  ),
  nav_panel(
    "Export",
    div(
      class = "action-bar",
      actionButton("build_prompt_pack", "Build GPT Pack", class = "btn-sc"),
      downloadButton("download_prompt_pack_export", "Download Latest GPT Pack", class = "btn-sc-outline")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Export Status"),
      div(
        class = "card-body",
        textOutput("prompt_pack_status"),
        tags$div(class = "small text-muted mt-2", "This pack is meant for your custom GPT. The dashboard is for scanning, not final reasoning.")
      )
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Origin Watch"),
      responsive_table("origin_watch_table")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("Weekly Notes"),
      verbatimTextOutput("weekly_notes_text")
    ),
    card(
      class = "sc-card",
      full_screen = TRUE,
      card_header("GPT Pack Preview"),
      verbatimTextOutput("prompt_pack_preview")
    )
  )
)

server <- function(input, output, session) {
  refresh_nonce <- reactiveVal(Sys.time())
  prompt_status <- reactiveVal("No GPT pack built in this session.")

  safe_text <- function(expr, fallback = "Unavailable") {
    renderText({
      tryCatch(expr, error = function(e) fallback)
    })
  }

  safe_table <- function(expr) {
    renderTable({
      tryCatch(
        expr,
        error = function(e) data.frame(Status = conditionMessage(e), check.names = FALSE)
      )
    }, striped = TRUE, bordered = TRUE, spacing = "s")
  }

  safe_plot <- function(expr) {
    renderPlot({
      tryCatch(
        expr,
        error = function(e) {
          plot.new()
          title(main = "Chart unavailable")
          text(0.5, 0.55, "This panel is waiting on data.", cex = 1)
          text(0.5, 0.42, conditionMessage(e), cex = 0.85, col = "#56645c")
        }
      )
    })
  }

  observeEvent(input$refresh_app_data, {
    reload_bundled_snapshot()
    refresh_nonce(Sys.time())
    prompt_status("Dashboard data reloaded from the deployed GitHub snapshot.")
    showNotification("Dashboard reloaded from the deployed snapshot.", type = "message", duration = 4)
  })

  observeEvent(input$build_prompt_pack, {
    prompt_status("Building GPT pack...")

    result <- tryCatch(
      {
        source(build_prompt_script, local = TRUE)
        build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)
      },
      error = function(e) e
    )

    if (inherits(result, "error")) {
      prompt_status(paste("GPT pack build failed:", conditionMessage(result)))
      return()
    }

    refresh_nonce(Sys.time())
    prompt_status(
      paste(
        "GPT pack built at",
        format(result$generated_at, tz = "Australia/Sydney", usetz = TRUE)
      )
    )
    showNotification("GPT pack rebuilt and synced.", type = "message", duration = 4)
  })

  dashboard_data <- reactive({
    refresh_nonce()
    load_dashboard_data()
  })

  zero_tackle_injuries <- reactive({
    data <- dashboard_data()
    fetch_zero_tackle_injuries(
      player_id_lookup = data$player_id_lookup,
      current_round = current_round()
    )
  })

  trade_log <- reactive({
    data <- dashboard_data()
    if (!is.null(data$league_trade_log) && nrow(data$league_trade_log)) {
      return(data$league_trade_log)
    }

    build_trade_log(
      team_players_latest = data$team_players_latest,
      player_id_lookup = data$player_id_lookup,
      player_price_history = data$player_price_history,
      ladder_history = data$ladder_history,
      actual_trade_history = data$actual_trade_history
    )
  })

  trade_rounds <- reactive({
    data <- dashboard_data()
    if (!is.null(data$league_trade_round_summary) && nrow(data$league_trade_round_summary)) {
      return(data$league_trade_round_summary)
    }
    trade_round_summary(trade_log())
  })

  trade_team_totals <- reactive({
    data <- dashboard_data()
    if (!is.null(data$league_trade_team_summary) && nrow(data$league_trade_team_summary)) {
      return(data$league_trade_team_summary)
    }
    trade_team_summary(trade_log())
  })

  cash_generation_clean <- reactive({
    df <- dashboard_data()$cash_generation
    if (is.null(df) || nrow(df) == 0) {
      return(df)
    }

    if (!"projected_price_signal_next_round" %in% names(df)) {
      df$projected_price_signal_next_round <- NA_real_
    }

    df %>%
      mutate(
        projected_price_signal_next_round = sanitize_price_signal(
          projected_delta = coalesce(projected_price_signal_next_round, projected_price_rise_next_round),
          current_price = current_price,
          last_change = price_change_last_round
        )
      )
  })

  round_state <- reactive({
    data <- dashboard_data()
    infer_effective_round_from_nrl(
      game_rules = data$game_rules,
      nrl_fixture_source_history = data$nrl_fixture_source_history
    )
  })

  current_round <- reactive({
    round_state()$current_round
  })

  next_round <- reactive({
    round_state()$next_round %||% (current_round() + 1L)
  })

  snapshot_round <- reactive({
    data <- dashboard_data()
    finance_round <- latest_complete_ladder_round_value(data$ladder_history)
    if (!is.na(finance_round)) {
      return(finance_round)
    }

    available_rounds <- c(
      if (!is.null(data$fixtures_history) && "round" %in% names(data$fixtures_history)) data$fixtures_history$round else integer(),
      if (!is.null(data$ladder_history) && "round" %in% names(data$ladder_history)) data$ladder_history$round else integer(),
      if (!is.null(data$team_players_latest) && "round" %in% names(data$team_players_latest)) data$team_players_latest$round else integer()
    )
    available_rounds <- suppressWarnings(as.integer(available_rounds))
    available_rounds <- available_rounds[!is.na(available_rounds) & available_rounds <= current_round()]
    if (length(available_rounds) == 0) {
      return(NA_integer_)
    }
    max(available_rounds)
  })

  finance_snapshot <- reactive({
    data <- dashboard_data()
    live_team_finance(
      team_players_latest = data$team_players_latest,
      master_player = data$master_player,
      ladder_history = data$ladder_history
    )
  })

  structure_snapshot <- reactive({
    latest_team_structure(dashboard_data()$structure_health)
  })

  team_stats_snapshot <- reactive({
    latest_team_round_stats(dashboard_data()$team_round_stats_history)
  })

  club_next_fixture <- reactive({
    data <- dashboard_data()
    next_team_fixture_lookup(
      nrl_fixture_source_history = data$nrl_fixture_source_history,
      fixture_matchup = data$fixture_matchup
    )
  })

  planner_context <- reactive({
    ladder <- latest_ladder_round()
    my_team_id <- ladder %>%
      filter(is_me %in% TRUE) %>%
      pull(user_team_id) %>%
      first()

    opponent_team_id <- tryCatch(current_matchup()$opponent_team_id, error = function(e) NA_integer_)

    list(
      my_team_id = my_team_id,
      opponent_team_id = opponent_team_id
    )
  })

  planner_market_pool <- reactive({
    data <- dashboard_data()

    prepare_planner_roster(
      base_players = data$master_player %>%
        transmute(
          player_id,
          full_name,
          team_abbrev = team,
          position = positions
        ),
      master_player = data$master_player,
      player_id_lookup = data$player_id_lookup,
      availability_risk = data$availability_risk,
      zero_tackle_tbl = zero_tackle_injuries(),
      next_fixture_lookup = club_next_fixture(),
      team_performance = data$team_performance,
      current_round = current_round()
    )
  })

  current_planner_roster <- reactive({
    data <- dashboard_data()
    context <- planner_context()
    req(!is.na(context$my_team_id))

    snapshot <- latest_team_players_snapshot(data$team_players_latest, context$my_team_id)
    req(!is.null(snapshot), nrow(snapshot) > 0)

    prepare_planner_roster(
      base_players = snapshot,
      master_player = data$master_player,
      player_id_lookup = data$player_id_lookup,
      availability_risk = data$availability_risk,
      zero_tackle_tbl = zero_tackle_injuries(),
      next_fixture_lookup = club_next_fixture(),
      team_performance = data$team_performance,
      current_round = current_round()
    )
  })

  planner_trade_out_choices <- reactive({
    roster <- current_planner_roster() %>%
      arrange(current_position, player)

    c(
      "No trade" = "",
      setNames(
        as.character(roster$player_id),
        paste0(
          roster$player,
          " | ",
          coalesce(roster$positions_string, roster$current_position, "?"),
          " | ",
          dollar(coalesce(roster$current_price, 0))
        )
      )
    )
  })

  planner_trade_in_choices <- reactive({
    roster_ids <- current_planner_roster()$player_id

    market <- planner_market_pool() %>%
      filter(!player_id %in% roster_ids) %>%
      arrange(desc(active_flag %in% TRUE), desc(real_score), player)

    c(
      "No trade" = "",
      setNames(
        as.character(market$player_id),
        paste0(
          market$player,
          " | ",
          coalesce(market$positions_string, market$current_position, "?"),
          " | ",
          market$team_abbrev,
          " | ",
          dollar(coalesce(market$current_price, 0))
        )
      )
    )
  })

  observe({
    out_choices <- planner_trade_out_choices()
    in_choices <- planner_trade_in_choices()

    updateSelectizeInput(session, "planner_trade_out_1", choices = out_choices, selected = isolate(input$planner_trade_out_1 %||% ""), server = TRUE)
    updateSelectizeInput(session, "planner_trade_out_2", choices = out_choices, selected = isolate(input$planner_trade_out_2 %||% ""), server = TRUE)
    updateSelectizeInput(session, "planner_trade_out_3", choices = out_choices, selected = isolate(input$planner_trade_out_3 %||% ""), server = TRUE)

    updateSelectizeInput(session, "planner_trade_in_1", choices = in_choices, selected = isolate(input$planner_trade_in_1 %||% ""), server = TRUE)
    updateSelectizeInput(session, "planner_trade_in_2", choices = in_choices, selected = isolate(input$planner_trade_in_2 %||% ""), server = TRUE)
    updateSelectizeInput(session, "planner_trade_in_3", choices = in_choices, selected = isolate(input$planner_trade_in_3 %||% ""), server = TRUE)
  })

  planner_trades <- reactive({
    pairs <- data.frame(
      out_id = c(
        as.character(input$planner_trade_out_1 %||% ""),
        as.character(input$planner_trade_out_2 %||% ""),
        as.character(input$planner_trade_out_3 %||% "")
      ),
      in_id = c(
        as.character(input$planner_trade_in_1 %||% ""),
        as.character(input$planner_trade_in_2 %||% ""),
        as.character(input$planner_trade_in_3 %||% "")
      ),
      stringsAsFactors = FALSE
    ) %>%
      mutate(
        out_id = suppressWarnings(as.integer(if_else(nzchar(out_id), out_id, NA_character_))),
        in_id = suppressWarnings(as.integer(if_else(nzchar(in_id), in_id, NA_character_)))
      ) %>%
      filter(!is.na(out_id) | !is.na(in_id))

    if (!nrow(pairs)) {
      return(pairs)
    }

    current_lookup <- current_planner_roster() %>%
      select(out_id = player_id, out_player = player, out_team = team_abbrev)
    market_lookup <- planner_market_pool() %>%
      select(in_id = player_id, in_player = player, in_team = team_abbrev)

    pairs %>%
      left_join(current_lookup, by = "out_id") %>%
      left_join(market_lookup, by = "in_id")
  })

  planner_bundle <- reactive({
    current_roster <- current_planner_roster()
    future_market <- planner_market_pool()
    trades <- planner_trades()
    slots <- slot_template_from_game_rules(dashboard_data()$game_rules)

    notes <- character()
    if (nrow(trades)) {
      if (any(is.na(trades$out_id) | is.na(trades$in_id))) {
        notes <- c(notes, "Incomplete trade rows were ignored because each line needs both a trade-out and a trade-in.")
      }
      if (any(duplicated(na.omit(trades$out_id)))) {
        notes <- c(notes, "You have duplicated a trade-out player.")
      }
      if (any(duplicated(na.omit(trades$in_id)))) {
        notes <- c(notes, "You have duplicated a trade-in player.")
      }
    }

    trades_complete <- trades %>%
      filter(!is.na(out_id), !is.na(in_id))

    trade_out_ids <- na.omit(trades_complete$out_id)
    trade_in_ids <- na.omit(trades_complete$in_id)

    future_roster <- bind_rows(
      current_roster %>% filter(!player_id %in% trade_out_ids),
      future_market %>% filter(player_id %in% trade_in_ids)
    ) %>%
      arrange(player_id) %>%
      distinct(player_id, .keep_all = TRUE)

    final_assign <- solve_best_lineup(future_roster, slots, "real_score")
    req(!is.null(final_assign), nrow(final_assign) > 0)

    final_ids <- final_assign$player_id
    kickoff_candidates <- future_roster$next_kickoff_utc[!is.na(future_roster$next_kickoff_utc)]
    first_kickoff <- if (length(kickoff_candidates)) min(kickoff_candidates) else as.POSIXct(NA, tz = "UTC")

    current_target_ids <- intersect(final_ids, current_roster$player_id)
    current_roster <- current_roster %>%
      mutate(
        late_bonus = case_when(
          is.na(next_kickoff_utc) ~ 22,
          !is.na(first_kickoff) ~ pmax(as.numeric(difftime(next_kickoff_utc, first_kickoff, units = "hours")), 0) / 3,
          TRUE ~ 0
        ),
        placeholder_bonus = case_when(
          bye_this_round %in% TRUE ~ 12,
          risk_band == "high" ~ 10,
          TRUE ~ 0
        ),
        bogus_value = if_else(player_id %in% trade_out_ids, 42, 0) +
          if_else(!player_id %in% current_target_ids, 24, -14) +
          late_bonus +
          placeholder_bonus -
          real_score / 8
      )

    pre_assign <- solve_best_lineup(current_roster, slots, "bogus_value")
    req(!is.null(pre_assign), nrow(pre_assign) > 0)

    future_roster <- future_roster %>%
      mutate(
        late_bonus = case_when(
          is.na(next_kickoff_utc) ~ 18,
          !is.na(first_kickoff) ~ pmax(as.numeric(difftime(next_kickoff_utc, first_kickoff, units = "hours")), 0) / 3,
          TRUE ~ 0
        ),
        placeholder_bonus = case_when(
          bye_this_round %in% TRUE ~ 12,
          risk_band == "high" ~ 9,
          TRUE ~ 0
        ),
        bogus_value = if_else(!player_id %in% final_ids, 26, -14) +
          late_bonus +
          placeholder_bonus -
          real_score / 8
      )

    post_assign <- if (nrow(trades)) solve_best_lineup(future_roster, slots, "bogus_value") else pre_assign
    req(!is.null(post_assign), nrow(post_assign) > 0)

    pre_reserves <- choose_planner_reserves(current_roster, pre_assign$player_id, current_target_ids)
    post_reserves <- choose_planner_reserves(future_roster, post_assign$player_id, final_ids)

    player_lookup <- c(
      setNames(current_roster$player, as.character(current_roster$player_id)),
      setNames(future_roster$player, as.character(future_roster$player_id))
    )
    player_lookup <- player_lookup[!duplicated(names(player_lookup))]

    trade_deadline <- if (length(trade_in_ids)) {
      incoming_times <- future_roster %>%
        filter(player_id %in% trade_in_ids) %>%
        pull(next_kickoff_utc)
      incoming_times <- incoming_times[!is.na(incoming_times)]
      if (length(incoming_times)) min(incoming_times) - 10 * 60 else NA
    } else {
      NA
    }

    state_assign <- pre_assign
    state_reserves <- pre_reserves
    state_roster <- current_roster
    move_rows <- list()

    if (nrow(trades_complete)) {
      incoming_positions <- vapply(trades_complete$in_id, function(one_id) {
        slot_hit <- post_assign$slot[match(one_id, post_assign$player_id)]
        if (length(slot_hit) && !is.na(slot_hit)) slot_hit else "Bench"
      }, character(1))

      trade_text <- paste(
        paste0(
          "Trade ",
          trades_complete$out_player,
          " -> ",
          trades_complete$in_player,
          " and park ",
          trades_complete$in_player,
          " at ",
          incoming_positions
        ),
        collapse = " | "
      )

      move_rows[[length(move_rows) + 1L]] <- data.frame(
        Step = length(move_rows) + 1L,
        When = format_planner_time(trade_deadline),
        Move = trade_text,
        `Reserve Change` = describe_reserve_transition(pre_reserves, post_reserves, player_lookup),
        Why = "Latest safe window to complete the selected trades and still keep the real side hidden before the incoming players lock.",
        stringsAsFactors = FALSE
      )
      state_assign <- post_assign
      state_reserves <- post_reserves
      state_roster <- future_roster
    }

    final_plan <- final_assign %>%
      left_join(
        future_roster %>%
          select(player_id, team_abbrev, next_opponent, next_kickoff_utc, real_score, risk_band, bye_this_round),
        by = "player_id"
      ) %>%
      arrange(coalesce(next_kickoff_utc, as.POSIXct("2100-01-01", tz = "UTC")), desc(real_score))

    for (i in seq_len(nrow(final_plan))) {
      desired_slot <- final_plan$slot[[i]]
      target_id <- final_plan$player_id[[i]]
      target_name <- final_plan$player[[i]]
      current_slot_for_target <- state_assign$slot[match(target_id, state_assign$player_id)]

      if (length(current_slot_for_target) && !is.na(current_slot_for_target) && identical(current_slot_for_target, desired_slot)) {
        next
      }

      desired_occ <- state_assign %>% filter(slot == desired_slot)
      desired_occ_id <- desired_occ$player_id[[1]]
      desired_occ_name <- desired_occ$player[[1]]

      if (length(current_slot_for_target) && !is.na(current_slot_for_target)) {
        state_assign$player_id[state_assign$slot == desired_slot] <- target_id
        state_assign$player[state_assign$slot == desired_slot] <- target_name
        state_assign$player_id[state_assign$slot == current_slot_for_target] <- desired_occ_id
        state_assign$player[state_assign$slot == current_slot_for_target] <- desired_occ_name
        move_text <- paste0(
          "Swap ", format_player_label(target_name, state_roster$current_position[match(target_id, state_roster$player_id)]),
          " into ", desired_slot,
          "; move ", format_player_label(desired_occ_name, state_roster$current_position[match(desired_occ_id, state_roster$player_id)]),
          " to ", current_slot_for_target
        )
      } else {
        state_assign$player_id[state_assign$slot == desired_slot] <- target_id
        state_assign$player[state_assign$slot == desired_slot] <- target_name
        move_text <- paste0("Move ", target_name, " into ", desired_slot, "; bench ", desired_occ_name)
      }

      next_reserves <- choose_planner_reserves(state_roster, state_assign$player_id, final_ids)

      move_rows[[length(move_rows) + 1L]] <- data.frame(
        Step = length(move_rows) + 1L,
        When = format_planner_time(final_plan$next_kickoff_utc[[i]] - 10 * 60),
        Move = move_text,
        `Reserve Change` = describe_reserve_transition(state_reserves, next_reserves, player_lookup),
        Why = if (!is.na(final_plan$next_kickoff_utc[[i]])) {
          paste0(
            "Latest clean switch before ",
            final_plan$team_abbrev[[i]],
            " v ",
            final_plan$next_opponent[[i]] %||% "their opponent",
            " locks."
          )
        } else if (final_plan$bye_this_round[[i]] %in% TRUE) {
          "No kickoff this round: only move if you need the shape for disguise."
        } else {
          "No kickoff found, so make this move before the first relevant lock."
        },
        stringsAsFactors = FALSE
      )

      state_reserves <- next_reserves
    }

    pre_field_ids <- pre_assign$player_id
    pre_bench <- current_roster %>%
      filter(!player_id %in% pre_field_ids) %>%
      arrange(desc(player_id %in% pre_reserves), next_kickoff_utc, desc(real_score), player)

    starting_setup <- bind_rows(
      pre_assign %>%
        left_join(
          current_roster %>%
            select(player_id, team_abbrev, next_opponent, next_kickoff_utc, real_score, bogus_value, current_position, risk_band, bye_this_round),
          by = "player_id"
        ) %>%
        transmute(
          Placement = slot,
          Player = player,
          Team = team_abbrev,
          `Reserve ON` = if_else(player_id %in% pre_reserves, "Yes", "No"),
          `Kickoff (AEST)` = format_planner_time(next_kickoff_utc, fallback = "Bye / no kickoff"),
          `Bogus Score` = round(bogus_value, 1),
          Note = case_when(
            player_id %in% trade_out_ids ~ "trade disguise: keeps the planned sell on field",
            player_id %in% current_target_ids ~ "real scorer left on field from the start",
            bye_this_round %in% TRUE ~ "zero-scoring bye placeholder",
            risk_band == "high" ~ "injury / non-play placeholder",
            TRUE ~ "bogus placeholder to hide the real shape"
          )
        ),
      pre_bench %>%
        transmute(
          Placement = "Bench",
          Player = player,
          Team = team_abbrev,
          `Reserve ON` = if_else(player_id %in% pre_reserves, "Yes", "No"),
          `Kickoff (AEST)` = format_planner_time(next_kickoff_utc, fallback = "Bye / no kickoff"),
          `Bogus Score` = round(bogus_value, 1),
          Note = case_when(
            player_id %in% current_target_ids & player_id %in% pre_reserves ~ "hidden scorer with reserve live",
            player_id %in% current_target_ids ~ "hidden scorer waiting for a later move",
            TRUE ~ "bench cover only"
          )
        )
    )

    final_setup <- final_assign %>%
      left_join(
        future_roster %>%
          select(player_id, team_abbrev, next_opponent, next_kickoff_utc, real_score, risk_band, bye_this_round, recent_average, matchup_rating),
        by = "player_id"
      ) %>%
      transmute(
        Slot = slot,
        Player = player,
        Team = team_abbrev,
        `Next Opp` = next_opponent,
        `Kickoff (AEST)` = format_planner_time(next_kickoff_utc, fallback = "Bye / no kickoff"),
        `Real Score` = round(real_score, 1),
        Why = case_when(
          risk_band == "high" ~ "forced in despite risk because the slot has no better legal alternative",
          bye_this_round %in% TRUE ~ "bye this round, so only survives if the slot has no better live scorer",
          recent_average >= 70 & matchup_rating >= 28 ~ "strong form and playable matchup",
          matchup_rating >= 32 ~ "fixture-led scoring play",
          recent_average >= 60 ~ "best available scorer in slot",
          TRUE ~ "best legal combination after trades"
        )
      )

    status_lines <- c(
      paste0("Real team is optimised for ", nrow(final_setup), " active scorers plus 4 rotating reserves."),
      if (nrow(trades_complete)) paste0("Selected trades: ", paste0(trades_complete$out_player, " -> ", trades_complete$in_player, collapse = " | ")) else "Selected trades: no trade.",
      if (!is.na(trade_deadline)) paste0("Latest trade window: ", format_planner_time(trade_deadline)) else "Latest trade window: no trade timing constraint detected."
    )

    if (length(notes)) {
      status_lines <- c(status_lines, paste(notes, collapse = " | "))
    }

    list(
      status_text = paste(status_lines, collapse = "\n"),
      starting_setup = starting_setup,
      move_schedule = bind_rows(move_rows),
      final_setup = final_setup
    )
  })

  live_ladder_round <- reactive({
    data <- dashboard_data()
    round_value <- current_round()
    req(!is.null(data$ladder_history), !is.na(round_value))

    data$ladder_history %>%
      filter(round == round_value) %>%
      arrange(desc(run_ts), desc(!is.na(round_points))) %>%
      group_by(user_team_id) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      transmute(
        user_team_id,
        current_round_points = round_points
      )
  })

  latest_ladder_round <- reactive({
    data <- dashboard_data()
    round_value <- snapshot_round()
    req(!is.null(data$ladder_history), !is.na(round_value))

    data$ladder_history %>%
      filter(round == round_value) %>%
      arrange(desc(run_ts), desc(!is.na(team_value_total_calc)), desc(!is.na(cash_end_round_calc))) %>%
      group_by(user_team_id) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      left_join(finance_snapshot(), by = "user_team_id") %>%
      mutate(
        squad_value_calc = coalesce(live_squad_value_calc, squad_value_calc, finance_squad_value_calc),
        cash_end_round_calc = coalesce(live_cash_end_round_calc, cash_end_round_calc, finance_cash_end_round_calc),
        team_value_total_calc = coalesce(live_team_value_total_calc, team_value_total_calc, finance_team_value_total_calc)
      )
  })

  latest_fixtures <- reactive({
    data <- dashboard_data()
    req(!is.null(data$fixtures_history))

    data$fixtures_history %>%
      arrange(desc(run_ts)) %>%
      group_by(fixture_id) %>%
      slice_head(n = 1) %>%
      ungroup()
  })

  current_matchup <- reactive({
    round_value <- current_round()
    req(!is.na(round_value))

    my_team_id <- latest_ladder_round() %>%
      filter(is_me %in% TRUE) %>%
      pull(user_team_id) %>%
      first()

    matchup <- latest_fixtures() %>%
      filter(round == round_value) %>%
      filter(user_team1_id == my_team_id | user_team2_id == my_team_id) %>%
      slice_head(n = 1)

    req(nrow(matchup) > 0)

    opponent_team_id <- if (matchup$user_team1_id[[1]] == my_team_id) matchup$user_team2_id[[1]] else matchup$user_team1_id[[1]]

    list(
      my_team_id = my_team_id,
      opponent_team_id = opponent_team_id,
      fixture = matchup
    )
  })

  squad_team_mix <- reactive({
    data <- dashboard_data()
    matchup <- current_matchup()
    req(!is.null(data$team_players_latest))

    player_team_lookup <- if (!is.null(data$player_id_lookup) && nrow(data$player_id_lookup)) {
      data$player_id_lookup %>% select(player_id, team_abbrev)
    } else {
      data$players_cf_latest %>% select(player_id, team_abbrev)
    }

    latest_team_players_snapshot(
      data$team_players_latest,
      c(matchup$my_team_id, matchup$opponent_team_id)
    ) %>%
      distinct(user_team_id, player_id) %>%
      left_join(player_team_lookup, by = "player_id") %>%
      filter(!is.na(team_abbrev)) %>%
      count(user_team_id, team_abbrev, name = "player_n") %>%
      mutate(side = if_else(user_team_id == matchup$my_team_id, "You", "Opponent"))
  })

  matchup_summary <- reactive({
    ladder <- latest_ladder_round()
    matchup <- current_matchup()

    summary_tbl <- ladder %>%
      filter(user_team_id %in% c(matchup$my_team_id, matchup$opponent_team_id)) %>%
      select(
        user_team_id,
        team_name,
        coach_name,
        is_me,
        squad_value_calc,
        cash_end_round_calc,
        team_value_total_calc
      ) %>%
      left_join(
        structure_snapshot() %>%
          select(user_team_id, avg_projected_score_this_week = structure_projected_score, locked_players = structure_locked_players, dpp_players = structure_dpp_players),
        by = "user_team_id"
      ) %>%
      left_join(
        team_stats_snapshot() %>%
          select(user_team_id, total_changes = stats_total_changes, trade_boosts_used = stats_trade_boosts_used),
        by = "user_team_id"
      ) %>%
      left_join(
        trade_team_totals() %>%
          select(user_team_id, cumulative_detected_changes, latest_trade_round),
        by = "user_team_id"
      ) %>%
      mutate(
        total_changes = coalesce(total_changes, cumulative_detected_changes, 0L),
        side = if_else(is_me %in% TRUE, "You", "Opponent")
      )

    req(nrow(summary_tbl) == 2)
    summary_tbl
  })

  current_squad_signals <- reactive({
    data <- dashboard_data()
    matchup <- current_matchup()

    req(
      !is.null(data$squad_round_enriched),
      !is.null(data$availability_risk),
      !is.null(data$fixture_matchup),
      !is.null(data$nrl_fixture_source_history)
    )

    latest_team_squad_snapshot(
      data$squad_round_enriched,
      c(matchup$my_team_id, matchup$opponent_team_id)
    ) %>%
      left_join(
        latest_projection_lookup(
          data$squad_round_enriched,
          c(matchup$my_team_id, matchup$opponent_team_id)
        ),
        by = c("user_team_id", "player_id")
      ) %>%
      mutate(
        projected_score_this_week = coalesce(projected_score_this_week, projected_score_this_week_fallback),
        projected_score_next_3_weeks = coalesce(projected_score_next_3_weeks, projected_score_next_3_weeks_fallback),
        projected_value_change_next_3_weeks = coalesce(projected_value_change_next_3_weeks, projected_value_change_next_3_weeks_fallback),
        sell_urgency = coalesce(sell_urgency, sell_urgency_fallback)
      ) %>%
      left_join(
        data$availability_risk %>%
          select(
            player_id,
            team_abbrev,
            risk_band,
            injury_suspension_status_text,
            expected_return,
            played_status_display,
            locked_flag
          ),
        by = "player_id"
      ) %>%
      left_join(
        zero_tackle_injuries() %>%
          select(player_id, zero_tackle_reason, zero_tackle_expected_return, zero_tackle_risk_band, zero_tackle_status_text),
        by = "player_id"
      ) %>%
      left_join(
        club_next_fixture() %>%
          select(
            team_abbrev,
            next_opponent,
            next_matchup_rating,
            next_3_rounds_difficulty,
            schedule_swing_indicator,
            bye_flag
          ),
        by = "team_abbrev"
      ) %>%
      left_join(
        cash_generation_clean() %>%
          select(player_id, projected_price_signal_next_round, cumulative_cash_generation),
        by = "player_id"
      ) %>%
      mutate(
        side = if_else(user_team_id == matchup$my_team_id, "You", "Opponent"),
        expected_return = coalesce(zero_tackle_expected_return, expected_return),
        injury_suspension_status_text = coalesce(zero_tackle_status_text, injury_suspension_status_text),
        risk_band = coalesce(zero_tackle_risk_band, risk_band),
        risk_weight = case_when(
          risk_band == "high" ~ 3,
          risk_band == "medium" ~ 2,
          TRUE ~ 1
        ),
        display_urgency = case_when(
          risk_band == "high" ~ "high",
          risk_band == "medium" ~ "medium",
          coalesce(projected_price_signal_next_round, 0) < -30000 & coalesce(next_matchup_rating, 99) < 24 ~ "medium",
          bye_flag %in% TRUE ~ "medium",
          TRUE ~ coalesce(sell_urgency, "normal")
        ),
        signal_score = coalesce(projected_score_next_3_weeks, 0) / 12 +
          coalesce(next_matchup_rating, 0) / 2 +
          coalesce(projected_price_signal_next_round, 0) / 15000 -
          risk_weight * 3 -
          if_else(bye_flag %in% TRUE, 8, 0)
      )
  })

  market_watch_data <- reactive({
    data <- dashboard_data()

    req(
      !is.null(data$master_player),
      !is.null(data$players_cf_latest),
      !is.null(data$fixture_matchup),
      !is.null(data$cash_generation),
      !is.null(data$team_performance)
    )

    data$master_player %>%
      select(
        player_id,
        full_name,
        current_price,
        current_season_average,
        average_3_round
      ) %>%
      left_join(
        data$players_cf_latest %>%
          select(player_id, team_abbrev, active_flag, injury_suspension_status_text),
        by = "player_id"
      ) %>%
      left_join(
        cash_generation_clean() %>%
          select(player_id, projected_price_signal_next_round, cash_cow_maturity_status),
        by = "player_id"
      ) %>%
      left_join(
        zero_tackle_injuries() %>%
          select(player_id, zero_tackle_expected_return, zero_tackle_status_text),
        by = "player_id"
      ) %>%
      left_join(
        club_next_fixture() %>%
          select(
            team_abbrev,
            next_opponent,
            next_matchup_rating,
            schedule_swing_indicator,
            bye_flag
          ),
        by = "team_abbrev"
      ) %>%
      left_join(
        data$team_performance %>%
          filter(!is.na(attacking_trend_last_3)) %>%
          arrange(desc(round), desc(run_ts)) %>%
          group_by(team_abbrev) %>%
          slice_head(n = 1) %>%
          ungroup() %>%
          select(team_abbrev, attacking_trend_last_3),
        by = "team_abbrev"
      ) %>%
      mutate(
        recent_average = coalesce(average_3_round, current_season_average, 0),
        injury_text = coalesce(zero_tackle_status_text, injury_suspension_status_text),
        matchup_component = coalesce(next_matchup_rating, 0) / 2,
        attack_component = pmax(coalesce(attacking_trend_last_3, 0), 0) / 6,
        price_component = coalesce(projected_price_signal_next_round, 0) / 15000,
        bye_penalty = if_else(bye_flag %in% TRUE, 40, 0),
        injury_penalty = if_else(!is.na(injury_text) & nzchar(injury_text), 35, 0),
        signal_score = recent_average +
          matchup_component +
          attack_component +
          price_component -
          bye_penalty -
          injury_penalty
      ) %>%
      filter(
        active_flag %in% TRUE,
        recent_average >= 25,
        !is.na(next_opponent)
      ) %>%
      arrange(desc(signal_score), desc(recent_average)) %>%
      transmute(
        player = full_name,
        team = team_abbrev,
        next_opponent,
        recent_average = round(recent_average, 1),
        matchup = round(next_matchup_rating, 1),
        matchup_component = round(matchup_component, 2),
        attack_component = round(attack_component, 2),
        price_component = round(price_component, 2),
        bye_penalty,
        injury_penalty,
        signal_score = round(signal_score, 2),
        category = case_when(
          !is.na(injury_text) & nzchar(injury_text) ~ "Injury watch",
          projected_price_signal_next_round >= 40000 & next_matchup_rating >= 30 ~ "Buy target",
          projected_price_signal_next_round < 0 & recent_average >= 75 ~ "Premium hold",
          next_matchup_rating >= 32 ~ "Fixture play",
          projected_price_signal_next_round >= 25000 ~ "Price rise watch",
          TRUE ~ "Monitor"
        ),
        price_signal = dollar(projected_price_signal_next_round),
        swing = schedule_swing_indicator,
        maturity = cash_cow_maturity_status,
        why = case_when(
          !is.na(injury_text) & nzchar(injury_text) ~ injury_text,
          projected_price_signal_next_round >= 40000 & next_matchup_rating >= 30 ~ "hot form, positive price momentum, and a strong immediate fixture",
          projected_price_signal_next_round >= 25000 ~ "recent form suggests more price growth even without an elite matchup",
          next_matchup_rating >= 32 ~ "fixture-driven watch: strong immediate opponent setup",
          recent_average >= 80 & projected_price_signal_next_round < 0 ~ "premium scorer, but price is cooling from a high base",
          TRUE ~ "blended watchlist signal from form, upcoming matchup, and price cycle"
        )
      ) %>%
      slice_head(n = 14)
  })

  market_watchlist <- reactive({
    market_watch_data() %>%
      transmute(
        player,
        team,
        next_opponent,
        recent_average,
        matchup,
        category,
        price_signal,
        swing,
        maturity,
        why
      )
  })

  cash_watch <- reactive({
    data <- dashboard_data()

    req(!is.null(data$cash_generation), !is.null(data$players_cf_latest), !is.null(data$fixture_matchup))

    cash_generation_clean() %>%
      left_join(
        zero_tackle_injuries() %>%
          select(player_id, zero_tackle_status_text),
        by = "player_id"
      ) %>%
      left_join(
        club_next_fixture() %>%
          select(team_abbrev, next_opponent),
        by = "team_abbrev"
      ) %>%
      arrange(desc(projected_price_signal_next_round)) %>%
      transmute(
        player = full_name,
        team = team_abbrev,
        next_opponent,
        current_price = dollar(current_price),
        category = case_when(
          !is.na(zero_tackle_status_text) & nzchar(zero_tackle_status_text) ~ "Injury hold",
          player_classification == "cash_cow" & cash_cow_maturity_status == "rising" ~ "Cash cow upside",
          cumulative_cash_generation < 0 & current_price >= 500000 ~ "Cooling premium",
          cash_cow_maturity_status == "near_peak_or_peaked" ~ "Peak risk",
          cash_cow_maturity_status == "flattening" ~ "Flattening",
          TRUE ~ "Monitor"
        ),
        next_signal = dollar(projected_price_signal_next_round),
        total_cash = dollar(cumulative_cash_generation),
        maturity = cash_cow_maturity_status,
        why = case_when(
          !is.na(zero_tackle_status_text) & nzchar(zero_tackle_status_text) ~ zero_tackle_status_text,
          player_classification == "cash_cow" & cash_cow_maturity_status == "rising" ~ "still generating cash",
          cumulative_cash_generation < 0 & current_price >= 500000 ~ "negative total cash generation means this is not a true cash cow despite the next-signal spike",
          cash_cow_maturity_status == "near_peak_or_peaked" ~ "near peak price",
          cash_cow_maturity_status == "flattening" ~ "cash growth flattening",
          TRUE ~ "monitor price cycle"
        )
      ) %>%
      slice_head(n = 12)
  })

  future_league_schedule <- reactive({
    matchup <- current_matchup()

    latest_fixtures() %>%
      filter(round >= current_round(), round <= current_round() + 4L) %>%
      filter(user_team1_id == matchup$my_team_id | user_team2_id == matchup$my_team_id) %>%
      transmute(
        round,
        opponent_team = if_else(user_team1_id == matchup$my_team_id, user_team2_name, user_team1_name),
        opponent_coach = if_else(user_team1_id == matchup$my_team_id, user_team2_coach, user_team1_coach),
        current_score = if_else(user_team1_id == matchup$my_team_id, user_team2_points, user_team1_points)
      )
  })

  source_health <- reactive({
    data <- dashboard_data()
    req(!is.null(data$source_refresh_log))

    data$source_refresh_log %>%
      arrange(desc(run_ts)) %>%
      transmute(
        run_ts = format(run_ts, tz = "Australia/Sydney", usetz = TRUE),
        settings_current_round = if ("settings_current_round" %in% names(.)) settings_current_round else NA_integer_,
        effective_current_round = if ("effective_current_round" %in% names(.)) effective_current_round else current_round,
        current_round,
        round_inference_source = if ("round_inference_source" %in% names(.)) round_inference_source else NA_character_,
        mutable_rounds,
        rounds_pulled,
        fixture_rounds_pulled,
        player_history_refreshed_n,
        nrl_fixture_rounds_pulled
      ) %>%
      slice_head(n = 6)
  })

  output$current_round_text <- safe_text({
    round_value <- current_round()

    if (is.na(round_value)) {
      "NA"
    } else {
      settings_round <- round_state()$settings_current_round
      inference_source <- round_state()$round_inference_source

      if (!is.na(settings_round) && settings_round != round_value) {
        paste0("R", round_value, " (settings R", settings_round, ", ", inference_source %||% "inferred", ")")
      } else {
        paste0("R", round_value)
      }
    }
  })

  output$snapshot_round_text <- safe_text({
    matchup <- current_matchup()
    rounds <- latest_round_by_team(
      dashboard_data()$team_players_latest,
      c(matchup$my_team_id, matchup$opponent_team_id)
    )

    if (is.null(rounds) || !nrow(rounds)) {
      "Unavailable"
    } else if (nrow(rounds) == 1) {
      paste0("R", rounds$latest_round[[1]])
    } else {
      you_round <- rounds %>% filter(user_team_id == matchup$my_team_id) %>% pull(latest_round) %>% first()
      opp_round <- rounds %>% filter(user_team_id == matchup$opponent_team_id) %>% pull(latest_round) %>% first()
      paste0("You R", you_round %||% "NA", " / Opp R", opp_round %||% "NA")
    }
  })

  output$snapshot_status_text <- safe_text({
    live_round <- current_round()
    matchup <- current_matchup()
    rounds <- latest_round_by_team(
      dashboard_data()$team_players_latest,
      c(matchup$my_team_id, matchup$opponent_team_id)
    )

    if (is.na(live_round) || is.null(rounds) || !nrow(rounds)) {
      "No saved squad pull is available yet."
    } else {
      you_round <- rounds %>% filter(user_team_id == matchup$my_team_id) %>% pull(latest_round) %>% first()
      opp_round <- rounds %>% filter(user_team_id == matchup$opponent_team_id) %>% pull(latest_round) %>% first()
      paste0(
        "Live matchup round is R", live_round,
        ". Team value and bank use latest detected squads plus current player prices: you through R", you_round %||% "NA",
        ", opponent through R", opp_round %||% "NA", "."
      )
    }
  }, fallback = "Snapshot status is unavailable.")

  output$last_refresh_text <- safe_text({
    data <- dashboard_data()
    if (is.null(data$source_refresh_log) || nrow(data$source_refresh_log) == 0) {
      "No refresh yet"
    } else {
      format(max(data$source_refresh_log$run_ts), tz = "Australia/Sydney", usetz = TRUE)
    }
  })

  output$matchup_text <- safe_text({
    matchup_summary() %>%
      filter(side == "Opponent") %>%
      transmute(label = paste0(trimws(team_name), " (", trimws(coach_name), ")")) %>%
      pull(label) %>%
      first()
  }, fallback = "No matchup found")

  output$latest_export_text <- safe_text({
    path <- file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack.md")
    if (!file.exists(path)) {
      "Not built yet"
    } else {
      format(file.info(path)$mtime, tz = "Australia/Sydney", usetz = TRUE)
    }
  })

  output$league_finance_plot <- safe_plot({
    plot_df <- latest_ladder_round() %>%
      left_join(
        structure_snapshot() %>%
          select(user_team_id, avg_projected_score_this_week = structure_projected_score),
        by = "user_team_id"
      ) %>%
      mutate(
        highlight = case_when(
          is_me %in% TRUE ~ "You",
          user_team_id == current_matchup()$opponent_team_id ~ "Opponent",
          TRUE ~ "League"
        ),
        point_size = coalesce(avg_projected_score_this_week, median(avg_projected_score_this_week, na.rm = TRUE), 55)
      )

    ggplot(plot_df, aes(team_value_total_calc, cash_end_round_calc, color = highlight, size = point_size)) +
      geom_point(alpha = 0.85) +
      geom_text(aes(label = team_name), nudge_y = 15000, size = 3, show.legend = FALSE) +
      scale_x_continuous(labels = label_dollar()) +
      scale_y_continuous(labels = label_dollar()) +
      scale_color_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70", "League" = "#8f8571")) +
      scale_size_continuous(range = c(3, 9), guide = "none") +
      labs(x = "Total Team Value", y = "Cash In Bank", color = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  output$matchup_compare_plot <- safe_plot({
    plot_df <- matchup_summary() %>%
      transmute(
        side,
        `Team Value` = team_value_total_calc,
        `Cash` = cash_end_round_calc,
        `Avg Player Projection` = avg_projected_score_this_week,
        `DPP Players` = dpp_players
      ) %>%
      pivot_longer(-side, names_to = "metric", values_to = "value") %>%
      group_by(metric) %>%
      filter(any(!is.na(value)) && !all(coalesce(value, 0) == 0)) %>%
      ungroup()

    ggplot(plot_df, aes(metric, value, fill = side)) +
      geom_col(position = "dodge") +
      facet_wrap(~ metric, scales = "free_y", ncol = 2) +
      scale_fill_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70")) +
      labs(x = NULL, y = NULL, fill = NULL) +
      theme_minimal(base_size = 12) +
      theme(
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        legend.position = "top"
      )
  })

  output$opponent_profile_table <- safe_table({
    matchup_summary() %>%
      filter(side == "Opponent") %>%
      transmute(
        Coach = coach_name,
        Team = team_name,
        `Squad Value` = dollar(team_value_total_calc),
        Bank = dollar(cash_end_round_calc),
        `Avg Player Projection` = round(avg_projected_score_this_week, 1),
        `Detected Changes` = total_changes,
        `Latest Change Round` = latest_trade_round,
        `Boosts Used` = trade_boosts_used,
        `Locked Players` = locked_players,
        `DPP Players` = dpp_players
      )
  })

  output$your_availability_table <- safe_table({
    current_squad_signals() %>%
      filter(side == "You") %>%
      filter(
        risk_band %in% c("medium", "high") |
          currently_locked %in% TRUE |
          (!is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text))
      ) %>%
      transmute(
        Player = full_name,
        Team = team_abbrev,
        Risk = risk_band,
        Status = coalesce(injury_suspension_status_text, played_status_display),
        `Return / Note` = expected_return,
        Locked = currently_locked,
        `Proj 3w` = round(projected_score_next_3_weeks, 1)
      ) %>%
      slice_head(n = 12)
  })

  output$opponent_availability_table <- safe_table({
    current_squad_signals() %>%
      filter(side == "Opponent") %>%
      filter(
        risk_band %in% c("medium", "high") |
          currently_locked %in% TRUE |
          (!is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text))
      ) %>%
      transmute(
        Player = full_name,
        Team = team_abbrev,
        Risk = risk_band,
        Status = coalesce(injury_suspension_status_text, played_status_display),
        `Return / Note` = expected_return,
        Locked = currently_locked,
        `Proj 3w` = round(projected_score_next_3_weeks, 1)
      ) %>%
      slice_head(n = 12)
  })

  output$opponent_trade_plot <- safe_plot({
    trade_df <- trade_rounds() %>%
      filter(user_team_id == current_matchup()$opponent_team_id) %>%
      transmute(round, inferred_moves, actual_moves) %>%
      pivot_longer(-round, names_to = "move_type", values_to = "moves") %>%
      mutate(moves = coalesce(moves, 0))

    if (!nrow(trade_df) || all(trade_df$moves == 0)) {
      latest_known_round <- latest_round_by_team(
        dashboard_data()$team_players_latest,
        current_matchup()$opponent_team_id
      ) %>%
        pull(latest_round)

      ggplot(data.frame(round = seq_len(max(1, latest_known_round %||% 1)), moves = 0), aes(round, moves)) +
        geom_line(color = "#1f5c70", linewidth = 1) +
        geom_point(color = "#1f5c70", size = 2.5) +
        annotate("text", x = mean(c(1, max(1, latest_known_round %||% 1))), y = 0.02, label = paste0("No detected trade deltas through latest opponent squad pull (R", latest_known_round %||% "NA", ")"), color = "#56645c") +
        scale_y_continuous(limits = c(0, 0.03)) +
        labs(x = "Round", y = "Moves detected") +
        theme_minimal(base_size = 12)
    } else {
      ggplot(trade_df, aes(round, moves, fill = move_type)) +
        geom_col(position = "dodge") +
        scale_fill_manual(values = c("inferred_moves" = "#1f5c70", "actual_moves" = "#c4512d"), labels = c("actual_moves" = "Actual API", "inferred_moves" = "Inferred roster delta")) +
        scale_x_continuous(breaks = pretty_breaks()) +
        labs(x = "Round", y = "Moves detected", fill = NULL) +
        theme_minimal(base_size = 12) +
        theme(legend.position = "top")
    }
  })

  output$club_exposure_plot <- safe_plot({
    plot_df <- squad_team_mix() %>%
      mutate(
        player_n_plot = if_else(side == "Opponent", -player_n, player_n),
        label_hjust = if_else(side == "Opponent", 1.15, -0.15)
      ) %>%
      group_by(team_abbrev) %>%
      mutate(order_key = max(abs(player_n_plot), na.rm = TRUE)) %>%
      ungroup()

    ggplot(plot_df, aes(player_n_plot, reorder(team_abbrev, order_key), fill = side)) +
      geom_col() +
      geom_text(aes(label = abs(player_n_plot), hjust = label_hjust), size = 3.2, show.legend = FALSE) +
      scale_x_continuous(labels = function(x) abs(x)) +
      coord_flip() +
      scale_fill_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70")) +
      labs(x = NULL, y = "Players from club", fill = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  fixture_runway_components <- reactive({
    dashboard_data()$fixture_matchup %>%
      inner_join(
        squad_team_mix(),
        by = "team_abbrev",
        relationship = "many-to-many"
      ) %>%
      filter(round >= current_round(), round <= current_round() + 4L) %>%
      mutate(
        team_difficulty = next_3_rounds_difficulty,
        weighted_component = team_difficulty * pmax(player_n, 1)
      ) %>%
      filter(is.finite(team_difficulty))
  })

  output$fixture_runway_plot <- safe_plot({
    fixture_df <- fixture_runway_components() %>%
      group_by(side, round) %>%
      summarise(
        weighted_difficulty = weighted.mean(team_difficulty, w = pmax(player_n, 1), na.rm = TRUE),
        bye_players = sum(if_else(bye_flag %in% TRUE, player_n, 0L), na.rm = TRUE),
        .groups = "drop"
      ) %>%
      filter(is.finite(weighted_difficulty))

    ggplot(fixture_df, aes(round, weighted_difficulty, color = side)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 3) +
      geom_text(aes(label = if_else(bye_players > 0, paste0("bye:", bye_players), "")), nudge_y = 0.5, show.legend = FALSE) +
      scale_color_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70")) +
      scale_x_continuous(breaks = sort(unique(fixture_df$round))) +
      scale_y_continuous(expand = expansion(mult = c(0.08, 0.18))) +
      labs(x = "Round", y = "Weighted fixture difficulty", color = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  output$fixture_runway_breakdown_table <- safe_table({
    fixture_runway_components() %>%
      transmute(
        Side = side,
        Round = round,
        Club = team_abbrev,
        `Players From Club` = player_n,
        Opponent = opponent,
        `Fixture Rating` = round(team_difficulty, 2),
        `Weighted Contribution` = round(weighted_component, 2),
        `Short-Term Swing` = schedule_swing_indicator,
        Bye = if_else(bye_flag %in% TRUE, "Yes", "No")
      ) %>%
      arrange(Side, Round, desc(`Players From Club`), desc(`Fixture Rating`)) %>%
      slice_head(n = 24)
  })

  output$league_schedule_table <- safe_table({
    future_league_schedule()
  })

  output$your_signal_table <- safe_table({
    current_squad_signals() %>%
      filter(side == "You", selected_this_week %in% TRUE) %>%
      arrange(desc(signal_score)) %>%
      transmute(
        Player = full_name,
        Team = team_abbrev,
        `Next Opp` = next_opponent,
        `Proj 3w` = round(projected_score_next_3_weeks, 1),
        `Price Signal` = dollar(projected_price_signal_next_round),
        Matchup = round(next_matchup_rating, 1),
        Swing = schedule_swing_indicator,
        Urgency = display_urgency,
        Why = case_when(
          !is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text) ~ injury_suspension_status_text,
          projected_price_signal_next_round >= 40000 & next_matchup_rating >= 30 ~ "good matchup and strong price momentum",
          projected_price_signal_next_round < -25000 ~ "price cooling despite role hold",
          next_matchup_rating >= 30 ~ "strong immediate matchup",
          display_urgency %in% c("high", "medium") ~ paste("urgency:", display_urgency),
          TRUE ~ "balanced hold/watch profile"
        )
      ) %>%
      slice_head(n = 14)
  })

  output$market_watch_table <- safe_table({
    market_watchlist()
  })

  output$market_watch_factor_table <- safe_table({
    market_watch_data() %>%
      transmute(
        Player = player,
        Team = team,
        `Next Opp` = next_opponent,
        `Recent Avg` = recent_average,
        `Matchup Component` = matchup_component,
        `Attack Component` = attack_component,
        `Price Component` = price_component,
        `Bye Penalty` = bye_penalty,
        `Injury Penalty` = injury_penalty,
        `Signal Score` = signal_score,
        Category = category,
        Swing = swing,
        Why = why
      )
  })

  output$cash_watch_table <- safe_table({
    cash_watch()
  })

  output$nrl_context_table <- safe_table({
    dashboard_data()$fixture_matchup %>%
      inner_join(squad_team_mix(), by = "team_abbrev", relationship = "many-to-many") %>%
      filter(round >= current_round(), round <= current_round() + 2L) %>%
      transmute(
        Side = side,
        Round = round,
        Club = team_abbrev,
        Opponent = opponent,
        Players = player_n,
        `Home/Away` = home_away,
        Travel = travel_burden,
        `Team Env` = round(projected_team_scoring_environment, 1),
        `Matchup` = round(matchup_rating_by_team, 1),
        Swing = schedule_swing_indicator
      ) %>%
      arrange(Side, Round, desc(Players)) %>%
      slice_head(n = 18)
  })

  output$league_snapshot_table <- safe_table({
    latest_ladder_round() %>%
      left_join(
        live_ladder_round(),
        by = "user_team_id"
      ) %>%
      left_join(
        team_stats_snapshot() %>%
          select(user_team_id, total_changes = stats_total_changes, trade_boosts_used = stats_trade_boosts_used),
        by = "user_team_id"
      ) %>%
      left_join(
        trade_team_totals() %>%
          select(user_team_id, cumulative_detected_changes),
        by = "user_team_id"
      ) %>%
      arrange(position) %>%
      transmute(
        Pos = position,
        Team = team_name,
        Coach = coach_name,
        Wins = wins,
        Losses = losses,
        `Prev Round Pts` = round_points,
        `Current Round Pts` = coalesce(current_round_points, 0),
        `Total Pts (Live)` = coalesce(total_points, round_points, 0) + coalesce(current_round_points, 0),
        `Squad Value` = dollar(squad_value_calc),
        Cash = dollar(cash_end_round_calc),
        `Total Value` = dollar(team_value_total_calc),
        `Changes` = coalesce(total_changes, cumulative_detected_changes, 0L),
        `Boosts Used` = trade_boosts_used
      )
  })

  output$team_performance_plot <- safe_plot({
    selected_abbrevs <- squad_team_mix() %>%
      group_by(team_abbrev) %>%
      summarise(total_players = sum(player_n), .groups = "drop") %>%
      slice_max(total_players, n = 6, with_ties = FALSE)

    perf_df <- dashboard_data()$team_performance %>%
      filter(round <= current_round()) %>%
      filter(team_abbrev %in% unique(selected_abbrevs$team_abbrev)) %>%
      filter(!is.na(points_scored))

    ggplot(perf_df, aes(round, points_scored, color = team_abbrev)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      geom_line(
        data = perf_df %>% filter(!is.na(attacking_trend_last_3)),
        aes(y = attacking_trend_last_3),
        linewidth = 0.8,
        alpha = 0.45,
        linetype = "22"
      ) +
      scale_x_continuous(breaks = pretty_breaks()) +
      labs(x = "Round", y = "Points scored", color = "Team") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
  })

  output$source_health_table <- safe_table({
    source_health()
  })

  output$coverage_gap_table <- safe_table({
    dashboard_data()$checklist_coverage %>%
      filter(status != "implemented") %>%
      transmute(
        Item = checklist_item,
        Status = status,
        Notes = notes
      ) %>%
      slice_head(n = 12)
  })

  output$field_dictionary_table <- safe_table({
    dictionary <- build_field_dictionary()
    filter_value <- input$dictionary_table_filter %||% "All tables"
    if (!identical(filter_value, "All tables")) {
      dictionary <- dictionary %>% filter(table_name == filter_value)
    }
    dictionary %>%
      arrange(table_name, field) %>%
      transmute(
        Table = table_name,
        Field = field,
        Definition = definition
      )
  })

  output$matchup_trade_table <- safe_table({
    trade_log() %>%
      filter(user_team_id %in% c(current_matchup()$my_team_id, current_matchup()$opponent_team_id)) %>%
      mutate(
        Side = if_else(user_team_id == current_matchup()$my_team_id, "You", "Opponent"),
        Source = if_else(trade_source == "actual_api", "Actual API", "Inferred round delta")
      ) %>%
      arrange(desc(round), Side, desc(Source)) %>%
      transmute(
        Side,
        Round = round,
        Team = team_name,
        Coach = coach_name,
        Source,
        `Sell Player` = sell_player_name,
        `Sell Club` = sell_team_abbrev,
        `Sell Price` = dollar(sell_price),
        `Buy Player` = buy_player_name,
        `Buy Club` = buy_team_abbrev,
        `Buy Price` = dollar(buy_price)
      ) %>%
      slice_head(n = 20)
  })

  output$league_trade_table <- safe_table({
    trade_log() %>%
      mutate(Source = if_else(trade_source == "actual_api", "Actual API", "Inferred round delta")) %>%
      arrange(desc(round), team_name, coach_name) %>%
      transmute(
        Round = round,
        Team = team_name,
        Coach = coach_name,
        Source,
        `Sell Player` = sell_player_name,
        `Sell Club` = sell_team_abbrev,
        `Sell Price` = dollar(sell_price),
        `Buy Player` = buy_player_name,
        `Buy Club` = buy_team_abbrev,
        `Buy Price` = dollar(buy_price)
      ) %>%
      slice_head(n = 60)
  })

  output$planner_status_text <- safe_text({
    planner_bundle()$status_text
  }, fallback = "Planner is waiting on a valid squad snapshot and fixture schedule.")

  output$planner_start_table <- safe_table({
    planner_bundle()$starting_setup
  })

  output$planner_move_table <- safe_table({
    moves <- planner_bundle()$move_schedule
    if (is.null(moves) || !nrow(moves)) {
      data.frame(
        Status = "No moves were required beyond the bogus starting setup.",
        check.names = FALSE
      )
    } else {
      moves
    }
  })

  output$planner_final_table <- safe_table({
    planner_bundle()$final_setup
  })

  output$prompt_pack_status <- safe_text({
    prompt_status()
  })

  output$origin_watch_table <- safe_table({
    data <- dashboard_data()$origin_watch

    if (is.null(data) || nrow(data) == 0) {
      return(data.frame(Note = "Fill data/supercoach_league_21064/manual_inputs/origin_watch.csv to track probable and official Origin selections."))
    }

    data
  })

  output$weekly_notes_text <- safe_text({
    dashboard_data()$weekly_notes %||%
      "Add notes to data/supercoach_league_21064/manual_inputs/weekly_context_notes.md and they will appear here and in the GPT pack."
  })

  output$strategy_brief_text <- safe_text({
    dashboard_data()$strategy_brief %||%
      "Add notes to data/supercoach_league_21064/manual_inputs/weekly_strategy_brief.md and they will appear here and in the GPT pack."
  })

  output$strategy_prompt_text <- safe_text({
    dashboard_data()$strategy_prompt %||%
      "Add instructions to data/supercoach_league_21064/manual_inputs/strategy_prompt_instructions.md and they will be appended to the GPT pack."
  })

  output$strategy_log_table <- safe_table({
    data <- dashboard_data()$strategy_log

    if (is.null(data) || nrow(data) == 0) {
      return(data.frame(
        Note = "Fill data/supercoach_league_21064/manual_inputs/strategy_decision_log.csv to keep a rolling weekly strategy memory.",
        check.names = FALSE
      ))
    }

    required_cols <- c(
      "round", "decision_window", "strategy_mode", "priority_1", "priority_2",
      "priority_3", "opponent_read", "execution_status", "result_review",
      "next_week_carry_forward", "submitted_at"
    )
    missing_cols <- setdiff(required_cols, names(data))
    for (col in missing_cols) {
      data[[col]] <- NA_character_
    }

    data %>%
      mutate(round = suppressWarnings(as.integer(round))) %>%
      arrange(desc(round), desc(as.character(submitted_at))) %>%
      transmute(
        Round = round,
        Window = decision_window,
        `Strategy Mode` = strategy_mode,
        `Priority 1` = priority_1,
        `Priority 2` = priority_2,
        `Priority 3` = priority_3,
        `Opponent Read` = opponent_read,
        Status = execution_status,
        `Review` = result_review,
        `Carry Forward` = next_week_carry_forward,
        `Submitted` = submitted_at
      ) %>%
      slice_head(n = 12)
  })

  output$prompt_pack_preview <- safe_text({
    text <- dashboard_data()$prompt_pack_text
    if (is.null(text) || !nzchar(text)) {
      return("No GPT pack built yet. Use the Build GPT Pack button or run the manual analysis export workflow.")
    }

    preview <- substr(text, 1, 4500)
    if (nchar(text) > 4500) {
      paste0(preview, "\n\n...preview truncated...")
    } else {
      preview
    }
  })

  output$data_diagnostic_text <- renderText({
    data <- dashboard_data()

    lines <- c(
      paste0("bundled_data_dir: ", normalizePath(bundled_data_dir, winslash = "/", mustWork = FALSE)),
      paste0("runtime_data_dir: ", normalizePath(data_dir, winslash = "/", mustWork = FALSE)),
      paste0("bundled_populated: ", data_dir_is_populated(bundled_data_dir)),
      paste0("runtime_populated: ", data_dir_is_populated(data_dir)),
      paste0("game_rules_rows: ", if (is.null(data$game_rules)) 0 else nrow(data$game_rules)),
      paste0("fixtures_rows: ", if (is.null(data$fixtures_history)) 0 else nrow(data$fixtures_history)),
      paste0("ladder_rows: ", if (is.null(data$ladder_history)) 0 else nrow(data$ladder_history)),
      paste0("squad_rows: ", if (is.null(data$squad_round_enriched)) 0 else nrow(data$squad_round_enriched)),
      paste0("cash_rows: ", if (is.null(data$cash_generation)) 0 else nrow(data$cash_generation)),
      paste0("refresh_log_rows: ", if (is.null(data$source_refresh_log)) 0 else nrow(data$source_refresh_log)),
      paste0("zero_tackle_rows: ", if (is.null(zero_tackle_injuries())) 0 else nrow(zero_tackle_injuries())),
      paste0("trade_log_rows: ", if (is.null(trade_log())) 0 else nrow(trade_log()))
    )

    paste(lines, collapse = "\n")
  })

  output$download_prompt_pack <- downloadHandler(
    filename = function() {
      paste0("supercoach-gpt-pack-round-", current_round() %||% "na", ".md")
    },
    content = function(file) {
      source(build_prompt_script, local = TRUE)
      result <- build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)
      file.copy(result$markdown_path, file, overwrite = TRUE)
    }
  )

  output$download_prompt_pack_export <- downloadHandler(
    filename = function() {
      paste0("supercoach-gpt-pack-round-", current_round() %||% "na", ".md")
    },
    content = function(file) {
      source(build_prompt_script, local = TRUE)
      result <- build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)
      file.copy(result$markdown_path, file, overwrite = TRUE)
    }
  )
}

shinyApp(ui, server)

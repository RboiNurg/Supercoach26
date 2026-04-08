suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(jsonlite)
})

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
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

fmt_number <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "NA",
    formatC(x, format = "f", digits = digits, big.mark = ",")
  )
}

fmt_int <- function(x) {
  ifelse(
    is.na(x),
    "NA",
    formatC(round(x), format = "d", big.mark = ",")
  )
}

fmt_money <- function(x) {
  ifelse(
    is.na(x),
    "NA",
    paste0("$", format(round(x), big.mark = ",", trim = TRUE))
  )
}

safe_chr <- function(x) {
  x <- as.character(x)
  x[is.na(x) | !nzchar(x)] <- "NA"
  x
}

markdown_table <- function(df, max_rows = 12) {
  if (is.null(df) || nrow(df) == 0) {
    return("_No rows available._")
  }

  df <- utils::head(as.data.frame(df, stringsAsFactors = FALSE), max_rows)
  df[] <- lapply(df, function(col) {
    value <- safe_chr(col)
    gsub("\\|", "/", value)
  })

  header <- paste(names(df), collapse = " | ")
  separator <- paste(rep("---", ncol(df)), collapse = " | ")
  rows <- apply(df, 1, function(row) paste(row, collapse = " | "))

  paste(c(paste0("| ", header, " |"),
          paste0("| ", separator, " |"),
          paste0("| ", rows, " |")),
        collapse = "\n")
}

summarise_trade_behaviour <- function(opponent_behaviour, opponent_team_id) {
  if (is.null(opponent_behaviour) || !nrow(opponent_behaviour)) {
    return(NULL)
  }

  opponent_behaviour %>%
    filter(user_team_id == opponent_team_id) %>%
    arrange(desc(round)) %>%
    transmute(
      round,
      inferred_trade_events,
      inferred_players_in,
      actual_trade_count,
      trade_boosts_used,
      behaviour_source
    ) %>%
    utils::head(6)
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
      avg_projected_score_this_week = avg_projected_score_this_week,
      locked_players = locked_players,
      dpp_players = dpp_players
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
      total_changes = total_changes,
      trade_boosts_used = trade_boosts_used
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
    mutate(prev_round = lag(round), prev_player_ids = lag(player_ids)) %>%
    ungroup()

  inferred_rounds <- roster_by_round %>%
    filter(!is.na(prev_round)) %>%
    rowwise() %>%
    mutate(
      players_in = list(setdiff(player_ids, prev_player_ids)),
      players_out = list(setdiff(prev_player_ids, player_ids))
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
          select(buy_player_id = player_id, buy_player_name = full_name, buy_team_abbrev = team_abbrev),
        by = "buy_player_id"
      ) %>%
      left_join(
        player_id_lookup %>%
          select(sell_player_id = player_id, sell_player_name = full_name, sell_team_abbrev = team_abbrev),
        by = "sell_player_id"
      )
  }

  if (!is.null(player_price_history) && nrow(player_price_history)) {
    trade_log <- trade_log %>%
      left_join(
        player_price_history %>% select(buy_player_id = player_id, price_round = round, buy_price = price),
        by = c("buy_player_id", "price_round")
      ) %>%
      left_join(
        player_price_history %>% select(sell_player_id = player_id, price_round = round, sell_price = price),
        by = c("sell_player_id", "price_round")
      )
  }

  if (!is.null(ladder_history) && nrow(ladder_history)) {
    trade_log <- trade_log %>%
      left_join(team_lookup_from_ladder(ladder_history), by = "user_team_id")
  }

  trade_log %>% arrange(round, user_team_id, trade_source)
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

build_gpt_prompt_pack <- function(
    data_dir,
    league_id,
    output_dir = file.path(data_dir, "analysis_export"),
    strategy_path = "Purpose and Strategy.md"
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  manual_input_dir <- file.path(data_dir, "manual_inputs")
  dir.create(manual_input_dir, recursive = TRUE, showWarnings = FALSE)

  origin_watch_path <- file.path(manual_input_dir, "origin_watch.csv")
  weekly_notes_path <- file.path(manual_input_dir, "weekly_context_notes.md")

  if (!file.exists(origin_watch_path)) {
    writeLines(
      "player_name,team_abbrev,state,selection_status,confidence,note",
      origin_watch_path
    )
  }

  if (!file.exists(weekly_notes_path)) {
    writeLines(
      c(
        "# Weekly context notes",
        "",
        "- Add any rumours, beat-reporter notes, or manual context here.",
        "- This file is optional and will be included in the GPT export when populated."
      ),
      weekly_notes_path
    )
  }

  game_rules <- read_optional_rds(file.path(data_dir, "game_rules_round_state.rds"))
  ladder_history <- read_optional_rds(file.path(data_dir, "ladder_history.rds"))
  fixtures_history <- read_optional_rds(file.path(data_dir, "fixtures_history.rds"))
  structure_health <- read_optional_rds(file.path(data_dir, "structure_health_table.rds"))
  opponent_behaviour <- read_optional_rds(file.path(data_dir, "opponent_behaviour_history.rds"))
  fixture_matchup <- read_optional_rds(file.path(data_dir, "fixture_matchup_table.rds"))
  team_performance <- read_optional_rds(file.path(data_dir, "team_performance_context.rds"))
  nrl_fixture_source_history <- read_optional_rds(file.path(data_dir, "nrl_fixture_source_history.rds"))
  source_refresh_log <- read_optional_rds(file.path(data_dir, "source_refresh_log.rds"))
  team_round_stats_history <- read_optional_rds(file.path(data_dir, "team_round_stats_history.rds"))
  players_cf_latest <- read_optional_rds(file.path(data_dir, "players_cf_latest.rds"))
  team_players_latest <- read_optional_rds(file.path(data_dir, "team_players_latest.rds"))
  player_id_lookup <- read_optional_rds(file.path(data_dir, "player_id_lookup.rds"))
  player_price_history <- read_optional_rds(file.path(data_dir, "player_price_history_sc.rds"))
  actual_trade_history <- read_optional_rds(file.path(data_dir, "actual_trade_history.rds"))
  league_trade_log <- read_optional_rds(file.path(data_dir, "league_trade_log.rds"))
  league_trade_round_summary <- read_optional_rds(file.path(data_dir, "league_trade_round_summary.rds"))
  league_trade_team_summary <- read_optional_rds(file.path(data_dir, "league_trade_team_summary.rds"))
  availability_risk <- read_optional_rds(file.path(data_dir, "availability_risk_table.rds"))
  squad_round_enriched <- read_optional_rds(file.path(data_dir, "squad_round_enriched.rds"))
  cash_generation <- read_optional_rds(file.path(data_dir, "cash_generation_model.rds"))
  master_player <- read_optional_rds(file.path(data_dir, "master_player_round_latest.rds"))
  checklist_coverage <- read_optional_rds(file.path(data_dir, "checklist_coverage_status.rds"))
  long_horizon <- read_optional_rds(file.path(data_dir, "long_horizon_planning_table.rds"))
  origin_watch <- read_optional_csv(origin_watch_path)
  weekly_notes <- read_optional_text(weekly_notes_path)
  strategy_doc <- read_optional_text(strategy_path)

  if (is.null(game_rules) || !nrow(game_rules)) {
    stop("game_rules_round_state.rds is required to build the GPT pack.", call. = FALSE)
  }

  latest_refresh_row <- if (!is.null(source_refresh_log) && nrow(source_refresh_log)) {
    source_refresh_log %>% arrange(desc(run_ts)) %>% slice_head(n = 1)
  } else {
    NULL
  }

  current_round <- dplyr::coalesce(
    if (!is.null(latest_refresh_row) && "effective_current_round" %in% names(latest_refresh_row)) latest_refresh_row$effective_current_round[[1]] else NA_integer_,
    if (!is.null(latest_refresh_row) && "current_round" %in% names(latest_refresh_row)) latest_refresh_row$current_round[[1]] else NA_integer_,
    game_rules$current_round[[1]]
  )
  next_round <- game_rules$next_round[[1]] %||% (current_round + 1L)
  generated_at <- Sys.time()

  finance_round <- latest_complete_ladder_round_value(ladder_history)
  if (is.na(finance_round)) {
    finance_round <- current_round
  }

  finance_snapshot <- live_team_finance(team_players_latest, master_player, ladder_history)
  structure_snapshot <- latest_team_structure(structure_health)
  team_stats_snapshot <- latest_team_round_stats(team_round_stats_history)
  zero_tackle_injuries <- fetch_zero_tackle_injuries(player_id_lookup, current_round)
  trade_log <- if (!is.null(league_trade_log) && nrow(league_trade_log)) {
    league_trade_log
  } else {
    build_trade_log(team_players_latest, player_id_lookup, player_price_history, ladder_history, actual_trade_history)
  }
  trade_team_totals <- if (!is.null(league_trade_team_summary) && nrow(league_trade_team_summary)) {
    league_trade_team_summary
  } else {
    trade_team_summary(trade_log)
  }
  trade_rounds <- if (!is.null(league_trade_round_summary) && nrow(league_trade_round_summary)) {
    league_trade_round_summary
  } else {
    trade_round_summary(trade_log)
  }
  live_fixture_lookup <- next_team_fixture_lookup(
    nrl_fixture_source_history = nrl_fixture_source_history,
    fixture_matchup = fixture_matchup
  )

  latest_ladder_round <- ladder_history %>%
    filter(round == finance_round) %>%
    arrange(desc(run_ts), desc(!is.na(team_value_total_calc)), desc(!is.na(cash_end_round_calc))) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    left_join(finance_snapshot, by = "user_team_id") %>%
    mutate(
      squad_value_calc = coalesce(live_squad_value_calc, squad_value_calc, finance_squad_value_calc),
      cash_end_round_calc = coalesce(live_cash_end_round_calc, cash_end_round_calc, finance_cash_end_round_calc),
      team_value_total_calc = coalesce(live_team_value_total_calc, team_value_total_calc, finance_team_value_total_calc)
    )

  my_team_id <- latest_ladder_round %>%
    filter(is_me %in% TRUE) %>%
    pull(user_team_id) %>%
    first()

  live_ladder_round <- ladder_history %>%
    filter(round == current_round) %>%
    arrange(desc(run_ts), desc(!is.na(round_points))) %>%
    group_by(user_team_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      user_team_id,
      current_round_points = round_points
    )

  latest_fixtures <- fixtures_history %>%
    group_by(fixture_id) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup()

  my_fixture <- latest_fixtures %>%
    filter(round == current_round) %>%
    filter(user_team1_id == my_team_id | user_team2_id == my_team_id) %>%
    slice_head(n = 1)

  opponent_team_id <- if (nrow(my_fixture)) {
    if (my_fixture$user_team1_id[[1]] == my_team_id) my_fixture$user_team2_id[[1]] else my_fixture$user_team1_id[[1]]
  } else {
    NA_integer_
  }

  matchup_summary <- latest_ladder_round %>%
    filter(user_team_id %in% c(my_team_id, opponent_team_id)) %>%
    select(
      user_team_id,
      team_name,
      coach_name,
      is_me,
      position,
      round_points,
      total_points,
      team_value_total_calc,
      cash_end_round_calc
    ) %>%
    left_join(live_ladder_round, by = "user_team_id") %>%
    left_join(
      structure_snapshot %>%
        select(user_team_id, avg_projected_score_this_week, locked_players, dpp_players),
      by = "user_team_id"
    ) %>%
    left_join(
      team_stats_snapshot %>%
        select(user_team_id, total_changes, trade_boosts_used),
      by = "user_team_id"
    ) %>%
    left_join(
      trade_team_totals,
      by = "user_team_id"
    ) %>%
    mutate(
      side = if_else(is_me %in% TRUE, "You", "Opponent"),
      total_changes = coalesce(total_changes, cumulative_detected_changes, 0L),
      team_value_total_calc = fmt_money(team_value_total_calc),
      cash_end_round_calc = fmt_money(cash_end_round_calc),
      avg_projected_score_this_week = fmt_number(avg_projected_score_this_week, 1),
      current_round_points = coalesce(current_round_points, 0),
      total_changes = coalesce(total_changes, 0L)
    ) %>%
    select(
      side,
      team_name,
      coach_name,
      position,
      prev_round_points = round_points,
      current_round_points,
      total_points,
      team_value_total_calc,
      cash_end_round_calc,
      total_changes,
      trade_boosts_used,
      avg_projected_score_this_week,
      locked_players,
      dpp_players
    )

  future_league_fixtures <- latest_fixtures %>%
    filter(round >= current_round, round <= current_round + 4L) %>%
    filter(user_team1_id == my_team_id | user_team2_id == my_team_id) %>%
    transmute(
      round,
      opponent_team = if_else(user_team1_id == my_team_id, user_team2_name, user_team1_name),
      opponent_coach = if_else(user_team1_id == my_team_id, user_team2_coach, user_team1_coach),
      current_fixture_points = if_else(user_team1_id == my_team_id, user_team2_points, user_team1_points)
    )

  league_pulse <- latest_ladder_round %>%
    arrange(position) %>%
    left_join(live_ladder_round, by = "user_team_id") %>%
    transmute(
      position,
      team_name,
      coach_name,
      prev_round_points = round_points,
      current_round_points = coalesce(current_round_points, 0),
      total_points,
      team_value = fmt_money(team_value_total_calc),
      bank = fmt_money(cash_end_round_calc)
    ) %>%
    utils::head(8)

  squad_signals <- latest_team_squad_snapshot(
    squad_round_enriched,
    c(my_team_id, opponent_team_id)
  ) %>%
    left_join(
      latest_projection_lookup(squad_round_enriched, c(my_team_id, opponent_team_id)),
      by = c("user_team_id", "player_id")
    ) %>%
    mutate(
      projected_score_this_week = coalesce(projected_score_this_week, projected_score_this_week_fallback),
      projected_score_next_3_weeks = coalesce(projected_score_next_3_weeks, projected_score_next_3_weeks_fallback),
      projected_value_change_next_3_weeks = coalesce(projected_value_change_next_3_weeks, projected_value_change_next_3_weeks_fallback),
      sell_urgency = coalesce(sell_urgency, sell_urgency_fallback)
    ) %>%
    left_join(
      availability_risk %>%
        select(
          player_id,
          team_abbrev,
          risk_band,
          injury_suspension_status_text,
          expected_return,
          played_status_display,
          locked_flag
        ),
      by = c("player_id")
    ) %>%
    left_join(
      zero_tackle_injuries %>%
        select(player_id, zero_tackle_status_text, zero_tackle_expected_return, zero_tackle_risk_band),
      by = "player_id"
    ) %>%
      left_join(
      live_fixture_lookup %>%
        select(
          team_abbrev,
          next_opponent,
          next_matchup_rating,
          next_3_rounds_difficulty,
          schedule_swing_indicator
        ),
      by = "team_abbrev"
    ) %>%
    mutate(
      side = if_else(user_team_id == my_team_id, "You", "Opponent"),
      expected_return = coalesce(zero_tackle_expected_return, expected_return),
      injury_suspension_status_text = coalesce(zero_tackle_status_text, injury_suspension_status_text),
      risk_band = coalesce(zero_tackle_risk_band, risk_band),
      display_urgency = case_when(
        risk_band == "high" ~ "high",
        risk_band == "medium" ~ "medium",
        TRUE ~ coalesce(sell_urgency, "normal")
      ),
      projected_score_this_week = projected_score_this_week,
      projected_score_next_3_weeks = projected_score_next_3_weeks,
      projected_value_change_next_3_weeks = projected_value_change_next_3_weeks
    ) %>%
    arrange(side, desc(selected_this_week), desc(currently_locked), desc(projected_score_next_3_weeks))

  availability_watch <- squad_signals %>%
    filter(
      risk_band %in% c("medium", "high") |
        currently_locked %in% TRUE |
        (!is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text))
    ) %>%
    transmute(
      side,
      player = full_name,
      team = team_abbrev,
      risk_band,
      status = dplyr::coalesce(injury_suspension_status_text, played_status_display),
      expected_return,
      currently_locked,
      projected_score_this_week
    ) %>%
    utils::head(18)

  squad_leverage_watch <- squad_signals %>%
    filter(side == "You", selected_this_week %in% TRUE) %>%
    transmute(
      player = full_name,
      team = team_abbrev,
      next_opponent,
      next_matchup_rating = fmt_number(next_matchup_rating, 1),
      next_3_rounds_difficulty = fmt_number(next_3_rounds_difficulty, 1),
      schedule_swing_indicator,
      projected_score_next_3_weeks = fmt_number(projected_score_next_3_weeks, 1),
      projected_value_change_next_3_weeks = fmt_money(projected_value_change_next_3_weeks),
      keeper_status,
      sell_urgency = display_urgency,
      why = case_when(
        !is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text) ~ injury_suspension_status_text,
        projected_value_change_next_3_weeks >= 40000 ~ "upside from form and price momentum",
        sell_urgency %in% c("high", "medium") ~ paste("urgency:", sell_urgency),
        TRUE ~ "balanced hold/watch profile"
      )
    ) %>%
    utils::head(14)

  opponent_profile <- squad_signals %>%
    filter(side == "Opponent", selected_this_week %in% TRUE) %>%
    transmute(
      player = full_name,
      team = team_abbrev,
      next_opponent,
      next_matchup_rating = fmt_number(next_matchup_rating, 1),
      projected_score_next_3_weeks = fmt_number(projected_score_next_3_weeks, 1),
      risk_band,
      currently_locked
    ) %>%
    utils::head(14)

  market_watchlist <- master_player %>%
    select(
      player_id,
      full_name,
      current_price,
      current_season_average,
      average_3_round,
      status = played_status
    ) %>%
    left_join(
      players_cf_latest %>%
        select(player_id, team_abbrev, active_flag, injury_suspension_status_text),
      by = "player_id"
    ) %>%
    left_join(
      cash_generation %>%
        select(player_id, projected_price_rise_next_round, cash_cow_maturity_status),
      by = "player_id"
    ) %>%
      left_join(
      zero_tackle_injuries %>%
        select(player_id, zero_tackle_status_text),
      by = "player_id"
    ) %>%
    left_join(
      live_fixture_lookup %>%
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
      team_performance %>%
        arrange(desc(run_ts)) %>%
        group_by(team_abbrev) %>%
        slice_head(n = 1) %>%
        ungroup() %>%
        select(team_abbrev, attacking_trend_last_3, defensive_trend_last_3),
      by = "team_abbrev"
    ) %>%
    mutate(
      recent_average = coalesce(average_3_round, current_season_average, 0),
      injury_text = coalesce(zero_tackle_status_text, injury_suspension_status_text),
      matchup_component = coalesce(next_matchup_rating, 0) / 2,
      attack_component = pmax(coalesce(attacking_trend_last_3, 0), 0) / 6,
      cash_component = coalesce(projected_price_rise_next_round, 0) / 15000,
      risk_penalty = if_else(!is.na(injury_text) & nzchar(injury_text), 30, 0),
      bye_penalty = if_else(bye_flag %in% TRUE, 40, 0),
      signal_score = recent_average + matchup_component + attack_component + cash_component - risk_penalty - bye_penalty
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
      current_price = fmt_money(current_price),
      recent_average = fmt_number(recent_average, 1),
      next_matchup_rating = fmt_number(next_matchup_rating, 1),
      category = case_when(
        !is.na(injury_text) & nzchar(injury_text) ~ "Injury watch",
        projected_price_rise_next_round >= 40000 & next_matchup_rating >= 35 ~ "Buy target",
        projected_price_rise_next_round < 0 & recent_average >= 75 ~ "Premium hold",
        next_matchup_rating >= 35 ~ "Fixture play",
        TRUE ~ "Monitor"
      ),
      projected_price_rise_next_round = fmt_money(projected_price_rise_next_round),
      schedule_swing_indicator,
      cash_cow_maturity_status,
      why = case_when(
        !is.na(injury_text) & nzchar(injury_text) ~ injury_text,
        projected_price_rise_next_round >= 40000 & next_matchup_rating >= 35 ~ "hot form + strong matchup + price rise",
        projected_price_rise_next_round >= 40000 ~ "hot form + price rise",
        next_matchup_rating >= 35 ~ "elite matchup next round",
        recent_average >= 80 ~ "premium form hold/watch",
        TRUE ~ "blend of form, matchup and price"
      )
    ) %>%
    utils::head(16)

  cash_watch <- cash_generation %>%
    left_join(
      zero_tackle_injuries %>%
        select(player_id, zero_tackle_status_text),
      by = "player_id"
    ) %>%
    left_join(
      live_fixture_lookup %>%
        select(team_abbrev, next_opponent, next_matchup_rating),
      by = "team_abbrev"
    ) %>%
    arrange(desc(projected_price_rise_next_round)) %>%
    transmute(
      player = full_name,
      team = team_abbrev,
      next_opponent,
      current_price = fmt_money(current_price),
      category = case_when(
        !is.na(zero_tackle_status_text) & nzchar(zero_tackle_status_text) ~ "Injury hold",
        player_classification == "cash_cow" & cash_cow_maturity_status == "rising" ~ "Cash cow upside",
        cumulative_cash_generation < 0 & current_price >= 500000 ~ "Short-term bump",
        cash_cow_maturity_status == "near_peak_or_peaked" ~ "Peak risk",
        cash_cow_maturity_status == "flattening" ~ "Flattening",
        TRUE ~ "Monitor"
      ),
      projected_price_rise_next_round = fmt_money(projected_price_rise_next_round),
      cumulative_cash_generation = fmt_money(cumulative_cash_generation),
      cash_cow_maturity_status,
      player_classification,
      why = case_when(
        !is.na(zero_tackle_status_text) & nzchar(zero_tackle_status_text) ~ zero_tackle_status_text,
        player_classification == "cash_cow" & cash_cow_maturity_status == "rising" ~ "still generating cash",
        cumulative_cash_generation < 0 & current_price >= 500000 ~ "price bump candidate, not a true cash cow yet",
        cash_cow_maturity_status == "near_peak_or_peaked" ~ "near peak price",
        cash_cow_maturity_status == "flattening" ~ "cash growth flattening",
        TRUE ~ "monitor price cycle"
      )
    ) %>%
    utils::head(14)

  nrl_context_watch <- fixture_matchup %>%
    filter(round >= current_round, round <= current_round + 2L) %>%
    inner_join(
      latest_team_players_snapshot(team_players_latest, c(my_team_id, opponent_team_id)) %>%
        distinct(user_team_id, player_id) %>%
        left_join(players_cf_latest %>% select(player_id, team_abbrev), by = "player_id") %>%
        filter(!is.na(team_abbrev)) %>%
        count(user_team_id, team_abbrev, name = "player_count") %>%
        mutate(side = if_else(user_team_id == my_team_id, "You", "Opponent")),
      by = "team_abbrev",
      relationship = "many-to-many"
    ) %>%
    transmute(
      side,
      round,
      club = team_abbrev,
      opponent,
      player_count,
      home_away,
      travel_burden,
      projected_team_scoring_environment = fmt_number(projected_team_scoring_environment, 1),
      matchup_rating_by_team = fmt_number(matchup_rating_by_team, 1),
      schedule_swing_indicator
    ) %>%
    arrange(side, round, desc(player_count)) %>%
    utils::head(18)

  trade_behaviour <- trade_rounds %>%
    filter(user_team_id == opponent_team_id) %>%
    arrange(desc(round)) %>%
    transmute(round, detected_changes, actual_moves, inferred_moves)
  if (is.null(trade_behaviour) || !nrow(trade_behaviour) || all(coalesce(trade_behaviour$detected_changes, 0) == 0)) {
    trade_behaviour <- tibble::tibble(
      note = "No detected trade deltas in saved snapshots for the current opponent yet."
    )
  }

  league_trade_log <- if (is.null(trade_log) || !nrow(trade_log)) {
    tibble::tibble(note = "No trade rows available from actual API or round-delta inference.")
  } else {
    trade_log %>%
      transmute(
        round,
        team = team_name,
        coach = coach_name,
        source = if_else(trade_source == "actual_api", "Actual API", "Inferred round delta"),
        sell_player = sell_player_name,
        sell_price = fmt_money(sell_price),
        buy_player = buy_player_name,
        buy_price = fmt_money(buy_price)
      ) %>%
      arrange(desc(round), team, coach) %>%
      utils::head(24)
  }

  coverage_gaps <- checklist_coverage %>%
    filter(status != "implemented") %>%
    select(checklist_item, status, notes)

  long_horizon_snapshot <- long_horizon %>%
    transmute(
      team_name,
      coach_name,
      current_round,
      current_squad_value = fmt_money(current_squad_value),
      projected_score_next_3_weeks = fmt_number(projected_score_next_3_weeks, 1),
      trades_remaining,
      boosts_remaining,
      finals_round,
      next_bye_rounds
    )

  refresh_snapshot <- source_refresh_log %>%
    arrange(desc(run_ts)) %>%
    transmute(
      run_ts = format(run_ts, tz = "Australia/Sydney", usetz = TRUE),
      settings_current_round = if ("settings_current_round" %in% names(.)) settings_current_round else NA_integer_,
      current_round,
      round_inference_source = if ("round_inference_source" %in% names(.)) round_inference_source else NA_character_,
      mutable_rounds,
      rounds_pulled,
      fixture_rounds_pulled,
      player_history_refreshed_n,
      nrl_fixture_rounds_pulled,
      nrl_ladder_rounds_pulled
    ) %>%
    utils::head(3)

  strategy_section <- if (is.null(strategy_doc) || !nzchar(trimws(strategy_doc))) {
    "_Purpose and Strategy.md was not found._"
  } else {
    strategy_doc
  }

  origin_section <- if (is.null(origin_watch) || !nrow(origin_watch)) {
    "_Origin watch file is empty. Fill `data/.../manual_inputs/origin_watch.csv` when you want probable or official Origin notes included._"
  } else {
    markdown_table(origin_watch, max_rows = 20)
  }

  weekly_notes_section <- if (is.null(weekly_notes) || !nzchar(trimws(weekly_notes))) {
    "_No manual weekly notes provided._"
  } else {
    weekly_notes
  }

  my_team_label <- matchup_summary %>%
    filter(side == "You") %>%
    transmute(label = paste0(trimws(team_name), " (", trimws(coach_name), ")")) %>%
    pull(label) %>%
    first() %||% "Unknown team"

  opponent_label <- matchup_summary %>%
    filter(side == "Opponent") %>%
    transmute(label = paste0(trimws(team_name), " (", trimws(coach_name), ")")) %>%
    pull(label) %>%
    first() %||% "Unknown opponent"

  latest_matchup_rounds <- latest_round_by_team(team_players_latest, c(my_team_id, opponent_team_id))
  your_latest_pull <- latest_matchup_rounds %>% filter(user_team_id == my_team_id) %>% pull(latest_round) %>% first()
  opp_latest_pull <- latest_matchup_rounds %>% filter(user_team_id == opponent_team_id) %>% pull(latest_round) %>% first()

  pack_lines <- c(
    "# SuperCoach Weekly Analysis Pack",
    "",
    paste0("- Generated at: ", format(generated_at, tz = "Australia/Sydney", usetz = TRUE)),
    paste0("- League ID: ", league_id),
    paste0("- Current round: ", current_round),
    paste0("- Latest squad pulls: you R", your_latest_pull %||% "NA", ", opponent R", opp_latest_pull %||% "NA"),
    "- Team value and bank use latest squad state plus current player prices, with bank carried from the latest known cash calculation.",
    paste0("- Next round: ", next_round),
    paste0("- Your team: ", my_team_label),
    paste0("- Current matchup: ", opponent_label),
    "",
    "## Source freshness",
    markdown_table(refresh_snapshot, max_rows = 3),
    "",
    "## Current matchup snapshot",
    markdown_table(matchup_summary, max_rows = 4),
    "",
    "## Next SuperCoach league opponents",
    markdown_table(future_league_fixtures, max_rows = 6),
    "",
    "## League pulse",
    markdown_table(league_pulse, max_rows = 8),
    "",
    "## Availability and lockout watch",
    markdown_table(availability_watch, max_rows = 18),
    "",
    "## Your squad leverage watch",
    markdown_table(squad_leverage_watch, max_rows = 14),
    "",
    "## Opponent squad profile",
    markdown_table(opponent_profile, max_rows = 14),
    "",
    "## Upcoming fixture market watchlist",
    markdown_table(market_watchlist, max_rows = 16),
    "",
    "## Cash generator watch",
    markdown_table(cash_watch, max_rows = 14),
    "",
    "## NRL context watch",
    markdown_table(nrl_context_watch, max_rows = 18),
    "",
    "## Opponent trade behaviour",
    markdown_table(trade_behaviour, max_rows = 6),
    "",
    "## League-wide trade log",
    markdown_table(league_trade_log, max_rows = 24),
    "",
    "## Long-horizon planning snapshot",
    markdown_table(long_horizon_snapshot, max_rows = 4),
    "",
    "## Origin watch",
    origin_section,
    "",
    "## Manual weekly notes",
    weekly_notes_section,
    "",
    "## Coverage gaps and caveats",
    markdown_table(coverage_gaps, max_rows = 20),
    "",
    "## Strategy reference",
    strategy_section
  )

  md_path <- file.path(output_dir, "latest_gpt_prompt_pack.md")
  txt_path <- file.path(output_dir, "latest_gpt_prompt_pack.txt")
  meta_path <- file.path(output_dir, "latest_gpt_prompt_pack_meta.json")
  pack_text <- paste(pack_lines, collapse = "\n")

  writeLines(pack_text, md_path, useBytes = TRUE)
  writeLines(pack_text, txt_path, useBytes = TRUE)

  metadata <- list(
    generated_at = format(generated_at, tz = "Australia/Sydney", usetz = TRUE),
    league_id = league_id,
    current_round = current_round,
    next_round = next_round,
    my_team = my_team_label,
    current_matchup = opponent_label,
    files = list(
      markdown = md_path,
      text = txt_path
    )
  )

  write_json(metadata, meta_path, auto_unbox = TRUE, pretty = TRUE)

  invisible(
    list(
      markdown_path = md_path,
      text_path = txt_path,
      metadata_path = meta_path,
      generated_at = generated_at,
      current_round = current_round
    )
  )
}

if (sys.nframe() == 0) {
  league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
  data_dir <- file.path("data", paste0("supercoach_league_", league_id))
  result <- build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)
  cat("GPT pack written to:\n")
  cat(result$markdown_path, "\n")
}

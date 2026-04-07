refresh_supercoach_logs <- function() {
  empty_ladder_history <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    round = integer(),
    user_team_id = integer()
  )

  empty_fixtures_history <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    round = integer(),
    fixture = integer(),
    fixture_id = character()
  )

  empty_team_players_snapshots <- tibble(
    run_ts = as.POSIXct(character()),
    user_team_id = integer(),
    round = integer(),
    player_id = integer()
  )

  empty_team_players_latest <- empty_team_players_snapshots

  empty_team_round_signatures <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    user_team_id = integer(),
    round = integer(),
    roster_signature = character()
  )

  empty_team_round_stats_history <- tibble(
    run_ts = as.POSIXct(character()),
    user_team_id = integer(),
    round = integer(),
    total_changes = integer(),
    trade_boosts_used = integer()
  )

  empty_actual_trade_history <- tibble(
    run_ts = as.POSIXct(character()),
    round = integer(),
    user_team_id = integer(),
    buy_player_id = integer(),
    sell_player_id = integer(),
    trade_source = character()
  )

  empty_inferred_changes <- tibble(
    detected_run_ts = as.POSIXct(character()),
    from_run_ts = as.POSIXct(character()),
    to_run_ts = as.POSIXct(character()),
    league_id = integer(),
    user_team_id = integer(),
    round = integer(),
    change_origin = character(),
    players_out = list(),
    players_in = list(),
    players_out_n = integer(),
    players_in_n = integer(),
    inferred_trade_pairs = list()
  )

  empty_run_log <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    first_run = logical(),
    settings_current_round = integer(),
    settings_next_round = integer(),
    current_round = integer(),
    next_round = integer(),
    round_inference_source = character(),
    round_closed_through_utc = as.POSIXct(character(), tz = "UTC"),
    rounds_pulled = character(),
    fixture_rounds_pulled = character(),
    mutable_rounds = character(),
    nrl_fixture_rounds_pulled = character(),
    nrl_ladder_rounds_pulled = character(),
    ladder_rows_new = integer(),
    nrl_fixture_rows_new = integer(),
    nrl_ladder_rows_new = integer(),
    player_snapshot_rows_new = integer(),
    changed_team_rounds = integer(),
    failed_team_rounds = integer(),
    players_cf_changed_n = integer(),
    player_history_refreshed_n = integer()
  )

  empty_player_price_history_2026 <- tibble(
    player_name = character(),
    year = integer(),
    round = integer(),
    score = numeric(),
    mins = numeric(),
    price = numeric()
  )

  empty_competition_state_history <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    settings_current_round = integer(),
    settings_next_round = integer(),
    current_round = integer(),
    next_round = integer(),
    round_inference_source = character(),
    round_closed_through_utc = as.POSIXct(character(), tz = "UTC"),
    competition_status = character(),
    is_lockout = logical(),
    is_partial_lockout = logical(),
    lockout_start = character(),
    lockout_end = character()
  )

  empty_nrl_fixture_source_history <- tibble(
    run_ts = as.POSIXct(character()),
    round = integer(),
    fixture_key = character(),
    source_url = character(),
    match_state = character(),
    match_mode = character(),
    kickoff_at_utc = as.POSIXct(character(), tz = "UTC"),
    venue = character(),
    venue_city = character(),
    team_abbrev = character(),
    team_name_nrl = character(),
    opponent_abbrev = character(),
    opponent_name_nrl = character(),
    home_away = character(),
    bye_flag = logical(),
    team_score = numeric(),
    opponent_score = numeric(),
    team_position = numeric(),
    opponent_position = numeric()
  )

  empty_nrl_team_context_history <- tibble(
    run_ts = as.POSIXct(character()),
    round = integer(),
    source_url = character(),
    team_abbrev = character(),
    team_name_nrl = character(),
    ladder_position = numeric(),
    ladder_movement = character(),
    next_opponent_abbrev = character(),
    next_opponent_name = character(),
    next_is_bye = logical(),
    games_played = numeric(),
    wins = numeric(),
    draws = numeric(),
    losses = numeric(),
    byes = numeric(),
    points_for = numeric(),
    points_against = numeric(),
    points_difference = numeric(),
    ladder_points = numeric(),
    bonus_points = numeric(),
    streak = character(),
    form = character(),
    average_losing_margin = numeric(),
    average_winning_margin = numeric(),
    home_record = character(),
    away_record = character(),
    day_record = character(),
    night_record = character(),
    players_used = numeric(),
    premiership_odds = character()
  )

  empty_players_cf_history <- tibble(
    run_ts = as.POSIXct(character()),
    player_id = integer(),
    first_name = character(),
    last_name = character(),
    full_name = character(),
    name_norm = character(),
    team_id = integer(),
    team_abbrev = character(),
    team_name = character(),
    locked_flag = logical(),
    played_status = character(),
    played_status_display = character(),
    active_flag = logical(),
    injury_suspension_status = character(),
    injury_suspension_status_text = character(),
    state_signature = character()
  )

  empty_player_history_refresh_log <- tibble(
    run_ts = as.POSIXct(character()),
    player_name = character(),
    refresh_reason = character(),
    current_price_external = numeric(),
    latest_price_stored = numeric(),
    is_league_focus = logical()
  )

  empty_source_refresh_log <- tibble(
    run_ts = as.POSIXct(character()),
    league_id = integer(),
    settings_current_round = integer(),
    settings_next_round = integer(),
    current_round = integer(),
    next_round = integer(),
    round_inference_source = character(),
    round_closed_through_utc = as.POSIXct(character(), tz = "UTC"),
    mutable_rounds = character(),
    rounds_pulled = character(),
    fixture_rounds_pulled = character(),
    nrl_fixture_rounds_pulled = character(),
    nrl_ladder_rounds_pulled = character(),
    nrl_fixture_rows_new = integer(),
    nrl_ladder_rows_new = integer(),
    players_cf_changed_n = integer(),
    player_history_refreshed_n = integer(),
    competition_status = character()
  )

  latest_non_na <- function(x) {
    vals <- x[!is.na(x)]
    if (length(vals) == 0) return(NA_real_)
    vals[[length(vals)]]
  }

  decode_html_json <- function(x) {
    x %>%
      gsub("&quot;", "\"", ., fixed = TRUE) %>%
      gsub("&amp;", "&", ., fixed = TRUE) %>%
      gsub("&#39;", "'", ., fixed = TRUE)
  }

  extract_q_data_json <- function(url, marker) {
    txt <- http_get_text(url, stats_headers())
    pattern <- sprintf('id="%s"[^>]*q-data="([^"]+)"', marker)
    match <- stringr::str_match(txt, pattern)

    if (is.na(match[1, 2])) {
      stop("Could not extract q-data payload from ", url)
    }

    jsonlite::fromJSON(decode_html_json(match[1, 2]), simplifyVector = FALSE)
  }

  ladder_history_existing <- read_rds_if_exists(path_ladder_history, empty_ladder_history)
  fixtures_history_existing <- read_rds_if_exists(path_fixtures_history, empty_fixtures_history)
  team_players_snapshots_existing <- read_rds_if_exists(path_team_players_snapshots, empty_team_players_snapshots)
  team_players_latest_existing <- read_rds_if_exists(path_team_players_latest, empty_team_players_latest)
  team_round_signatures_existing <- read_rds_if_exists(path_team_round_signatures, empty_team_round_signatures)
  team_round_stats_history_existing <- read_rds_if_exists(path_team_round_stats_history, empty_team_round_stats_history)
  actual_trade_history_existing <- read_rds_if_exists(path_actual_trade_history, empty_actual_trade_history)
  inferred_changes_existing <- read_rds_if_exists(path_inferred_changes, empty_inferred_changes)
  run_log_existing <- read_rds_if_exists(path_run_log, empty_run_log)
  player_price_history_existing <- read_rds_if_exists(path_player_price_history_2026, empty_player_price_history_2026)
  competition_state_history_existing <- read_rds_if_exists(path_competition_state_history, empty_competition_state_history)
  nrl_fixture_source_history_existing <- read_rds_if_exists(path_nrl_fixture_source_history, empty_nrl_fixture_source_history)
  nrl_team_context_history_existing <- read_rds_if_exists(path_nrl_team_context_history, empty_nrl_team_context_history)
  players_cf_history_existing <- read_rds_if_exists(path_players_cf_history, empty_players_cf_history)
  player_history_refresh_log_existing <- read_rds_if_exists(path_player_history_refresh_log, empty_player_history_refresh_log)
  source_refresh_log_existing <- read_rds_if_exists(path_source_refresh_log, empty_source_refresh_log)

  settings <- get_settings()
  me_profile <- get_me()
  teams_reference <- bind_rows_safe(get_teams()) %>%
    transmute(
      team_id = as.integer(id),
      team_abbrev = as.character(abbrev),
      team_feed_name = as.character(feed_name),
      team_name = as.character(name)
    )

  team_name_lookup <- bind_rows(
    teams_reference %>%
      transmute(team_abbrev, team_name_raw = team_name),
    tibble(
      team_abbrev = c("WST"),
      team_name_raw = c("Wests Tigers")
    )
  ) %>%
    mutate(team_name_norm = normalise_team_name(team_name_raw)) %>%
    distinct(team_name_norm, .keep_all = TRUE)

  nrl_team_abbrev <- function(team_name_raw) {
    team_name_norm <- normalise_team_name(safe_chr(team_name_raw, ""))
    team_name_lookup %>%
      filter(team_name_norm == !!team_name_norm) %>%
      pull(team_abbrev) %>%
      first() %>%
      `%||%`(NA_character_)
  }

  parse_ladder_stat <- function(stats_obj, field_name) {
    safe_dbl(stats_obj[[field_name]])
  }

  parse_team_position <- function(x) {
    suppressWarnings(
      as.numeric(
        stringr::str_extract(
          safe_chr(x),
          "\\d+"
        )
      )
    )
  }

  get_nrl_draw_round <- function(round_value) {
    source_url <- build_url("https://www.nrl.com/draw/", query = list(round = round_value))
    draw_payload <- extract_q_data_json(source_url, "vue-draw")

    match_rows <- purrr::map_dfr(draw_payload$fixtures %||% list(), function(z) {
      fixture_key <- safe_chr(z$matchCentreUrl)
      kickoff_at_utc <- safe_posixct(z$clock$kickOffTimeLong)
      venue <- safe_chr(z$venue)
      venue_city <- safe_chr(z$venueCity)
      match_state <- safe_chr(z$matchState)
      match_mode <- safe_chr(z$matchMode)
      round_number <- safe_int(stringr::str_extract(safe_chr(z$roundTitle), "\\d+"), round_value)
      home_team_name <- safe_chr(z$homeTeam$nickName)
      away_team_name <- safe_chr(z$awayTeam$nickName)
      home_team_abbrev <- nrl_team_abbrev(home_team_name)
      away_team_abbrev <- nrl_team_abbrev(away_team_name)

      bind_rows(
        tibble(
          run_ts = run_ts,
          round = round_number,
          fixture_key = fixture_key,
          source_url = source_url,
          match_state = match_state,
          match_mode = match_mode,
          kickoff_at_utc = kickoff_at_utc,
          venue = venue,
          venue_city = venue_city,
          team_abbrev = home_team_abbrev,
          team_name_nrl = home_team_name,
          opponent_abbrev = away_team_abbrev,
          opponent_name_nrl = away_team_name,
          home_away = "home",
          bye_flag = FALSE,
          team_score = safe_dbl(z$homeTeam$score),
          opponent_score = safe_dbl(z$awayTeam$score),
          team_position = parse_team_position(z$homeTeam$teamPosition),
          opponent_position = parse_team_position(z$awayTeam$teamPosition)
        ),
        tibble(
          run_ts = run_ts,
          round = round_number,
          fixture_key = fixture_key,
          source_url = source_url,
          match_state = match_state,
          match_mode = match_mode,
          kickoff_at_utc = kickoff_at_utc,
          venue = venue,
          venue_city = venue_city,
          team_abbrev = away_team_abbrev,
          team_name_nrl = away_team_name,
          opponent_abbrev = home_team_abbrev,
          opponent_name_nrl = home_team_name,
          home_away = "away",
          bye_flag = FALSE,
          team_score = safe_dbl(z$awayTeam$score),
          opponent_score = safe_dbl(z$homeTeam$score),
          team_position = parse_team_position(z$awayTeam$teamPosition),
          opponent_position = parse_team_position(z$homeTeam$teamPosition)
        )
      )
    })

    bye_rows <- purrr::map_dfr(draw_payload$byes %||% list(), function(z) {
      team_name_nrl <- safe_chr(z$teamNickName)

      tibble(
        run_ts = run_ts,
        round = safe_int(stringr::str_extract(safe_chr(z$roundTitle), "\\d+"), round_value),
        fixture_key = paste0("bye_round_", round_value, "_", normalise_team_name(team_name_nrl)),
        source_url = source_url,
        match_state = "Bye",
        match_mode = safe_chr(z$type),
        kickoff_at_utc = as.POSIXct(NA, tz = "UTC"),
        venue = NA_character_,
        venue_city = NA_character_,
        team_abbrev = nrl_team_abbrev(team_name_nrl),
        team_name_nrl = team_name_nrl,
        opponent_abbrev = NA_character_,
        opponent_name_nrl = NA_character_,
        home_away = "bye",
        bye_flag = TRUE,
        team_score = NA_real_,
        opponent_score = NA_real_,
        team_position = NA_real_,
        opponent_position = NA_real_
      )
    })

    bind_rows(match_rows, bye_rows) %>%
      filter(!is.na(team_abbrev))
  }

  get_nrl_ladder_round <- function(round_value) {
    source_url <- build_url("https://www.nrl.com/ladder/", query = list(round = round_value))
    ladder_payload <- extract_q_data_json(source_url, "vue-ladder")

    purrr::map_dfr(ladder_payload$positions %||% list(), function(z) {
      team_name_nrl <- safe_chr(z$teamNickname)
      stats_obj <- z$stats %||% list()

      tibble(
        run_ts = run_ts,
        round = round_value,
        source_url = source_url,
        team_abbrev = nrl_team_abbrev(team_name_nrl),
        team_name_nrl = team_name_nrl,
        ladder_position = NA_real_,
        ladder_movement = safe_chr(z$movement),
        next_opponent_abbrev = nrl_team_abbrev((z[["next"]] %||% list())[["nickname"]]),
        next_opponent_name = safe_chr((z[["next"]] %||% list())[["nickname"]]),
        next_is_bye = safe_lgl((z[["next"]] %||% list())[["isBye"]], FALSE),
        games_played = parse_ladder_stat(stats_obj, "played"),
        wins = parse_ladder_stat(stats_obj, "wins"),
        draws = parse_ladder_stat(stats_obj, "drawn"),
        losses = parse_ladder_stat(stats_obj, "lost"),
        byes = parse_ladder_stat(stats_obj, "byes"),
        points_for = parse_ladder_stat(stats_obj, "points for"),
        points_against = parse_ladder_stat(stats_obj, "points against"),
        points_difference = parse_ladder_stat(stats_obj, "points difference"),
        ladder_points = parse_ladder_stat(stats_obj, "points"),
        bonus_points = parse_ladder_stat(stats_obj, "bonus points"),
        streak = safe_chr(stats_obj[["streak"]]),
        form = safe_chr(stats_obj[["form"]]),
        average_losing_margin = parse_ladder_stat(stats_obj, "average losing margin"),
        average_winning_margin = parse_ladder_stat(stats_obj, "average winning margin"),
        home_record = safe_chr(stats_obj[["home record"]]),
        away_record = safe_chr(stats_obj[["away record"]]),
        day_record = safe_chr(stats_obj[["day record"]]),
        night_record = safe_chr(stats_obj[["night record"]]),
        players_used = parse_ladder_stat(stats_obj, "players used"),
        premiership_odds = safe_chr(stats_obj[["odds"]])
      )
    }) %>%
      filter(!is.na(team_abbrev))
  }

  infer_effective_round <- function(
    fixture_history,
    settings_current_round,
    settings_next_round,
    run_ts,
    season_rounds,
    close_buffer_hours = 3
  ) {
    if (nrow(fixture_history) == 0) {
      effective_current_round <- settings_current_round
      effective_next_round <- settings_next_round %||% min(max(season_rounds, na.rm = TRUE), settings_current_round + 1L)

      return(list(
        current_round = effective_current_round,
        next_round = effective_next_round,
        round_inference_source = "settings_only",
        round_closed_through_utc = as.POSIXct(NA, tz = "UTC")
      ))
    }

    run_ts_utc <- as.POSIXct(format(run_ts, tz = "UTC", usetz = TRUE), tz = "UTC")
    buffer_seconds <- close_buffer_hours * 60 * 60
    final_states <- c("fulltime", "full time", "post", "completed", "complete")

    fixture_level <- fixture_history %>%
      filter(!bye_flag %in% TRUE, !is.na(round), !is.na(fixture_key)) %>%
      group_by(round, fixture_key) %>%
      slice_max(run_ts, n = 1, with_ties = FALSE) %>%
      ungroup() %>%
      transmute(
        round,
        fixture_key,
        kickoff_at_utc,
        match_state_norm = stringr::str_to_lower(coalesce_chr(match_state)),
        close_cutoff_utc = if_else(
          is.na(kickoff_at_utc),
          as.POSIXct(NA, tz = "UTC"),
          kickoff_at_utc + buffer_seconds
        ),
        fixture_closed = case_when(
          match_state_norm %in% final_states ~ TRUE,
          !is.na(close_cutoff_utc) & run_ts_utc >= close_cutoff_utc ~ TRUE,
          TRUE ~ FALSE
        )
      )

    if (nrow(fixture_level) == 0) {
      effective_current_round <- settings_current_round
      effective_next_round <- settings_next_round %||% min(max(season_rounds, na.rm = TRUE), settings_current_round + 1L)

      return(list(
        current_round = effective_current_round,
        next_round = effective_next_round,
        round_inference_source = "settings_only",
        round_closed_through_utc = as.POSIXct(NA, tz = "UTC")
      ))
    }

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

    round_inference_source <- if (effective_current_round > settings_current_round) {
      "nrl_fixture_completion"
    } else {
      "settings"
    }

    round_closed_through_utc <- if (nrow(latest_closed_round) == 0) {
      as.POSIXct(NA, tz = "UTC")
    } else {
      latest_closed_round$round_closed_through_utc[[1]]
    }

    list(
      current_round = effective_current_round,
      next_round = effective_next_round,
      round_inference_source = round_inference_source,
      round_closed_through_utc = round_closed_through_utc
    )
  }

  settings_current_round <- safe_int(settings$competition$current_round)
  settings_next_round <- safe_int(settings$competition$next_round)
  competition_status <- safe_chr(settings$competition$status)

  if (is.na(settings_current_round)) {
    stop("Could not detect current round from /settings")
  }

  first_run <- nrow(ladder_history_existing) == 0 || nrow(team_round_signatures_existing) == 0
  max_round_available <- max(season_rounds, na.rm = TRUE)

  nrl_fixture_rounds_to_pull <- if (nrow(nrl_fixture_source_history_existing) == 0) {
    season_rounds
  } else {
    sort(unique(c(
      max(1L, settings_current_round - 1L),
      seq.int(settings_current_round, min(max_round_available, settings_current_round + 5L))
    )))
  }

  nrl_fixture_source_history_new <- map_dfr(nrl_fixture_rounds_to_pull, get_nrl_draw_round)
  nrl_fixture_source_history <- bind_rows(
    nrl_fixture_source_history_existing,
    nrl_fixture_source_history_new
  ) %>%
    distinct(run_ts, round, team_abbrev, .keep_all = TRUE) %>%
    arrange(run_ts, round, team_abbrev)

  round_inference <- infer_effective_round(
    fixture_history = nrl_fixture_source_history,
    settings_current_round = settings_current_round,
    settings_next_round = settings_next_round,
    run_ts = run_ts,
    season_rounds = season_rounds
  )

  current_round <- round_inference$current_round
  next_round <- round_inference$next_round
  round_inference_source <- round_inference$round_inference_source
  round_closed_through_utc <- round_inference$round_closed_through_utc

  mutable_rounds <- sort(unique(c(max(1L, current_round - 1L), current_round)))

  nrl_ladder_rounds_to_pull <- if (nrow(nrl_team_context_history_existing) == 0) {
    seq_len(current_round)
  } else {
    mutable_rounds
  }

  nrl_team_context_history_new <- map_dfr(nrl_ladder_rounds_to_pull, get_nrl_ladder_round) %>%
    group_by(round) %>%
    mutate(ladder_position = row_number()) %>%
    ungroup()

  nrl_team_context_history <- bind_rows(
    nrl_team_context_history_existing,
    nrl_team_context_history_new
  ) %>%
    distinct(run_ts, round, team_abbrev, .keep_all = TRUE) %>%
    arrange(run_ts, round, ladder_position, team_abbrev)

  competition_state_history <- bind_rows(
    competition_state_history_existing,
    tibble(
      run_ts = run_ts,
      league_id = league_id,
      settings_current_round = settings_current_round,
      settings_next_round = settings_next_round,
      current_round = current_round,
      next_round = next_round,
      round_inference_source = round_inference_source,
      round_closed_through_utc = round_closed_through_utc,
      competition_status = competition_status,
      is_lockout = safe_lgl(settings$competition$is_lockout, FALSE),
      is_partial_lockout = safe_lgl(settings$competition$is_partial_lockout, FALSE),
      lockout_start = safe_chr(settings$competition$lockout_start),
      lockout_end = safe_chr(settings$competition$lockout_end)
    )
  ) %>%
    distinct(run_ts, .keep_all = TRUE) %>%
    arrange(run_ts)

  players_cf_list <- sc_get_json("/players-cf")

  player_catalog_current <- tibble(
    player_id = map_int(players_cf_list, ~ safe_int(.x$id)),
    first_name = map_chr(players_cf_list, ~ safe_chr(.x$first_name)),
    last_name = map_chr(players_cf_list, ~ safe_chr(.x$last_name)),
    full_name = paste(last_name, first_name, sep = ", "),
    name_norm = normalise_player_name(full_name),
    team_id = map_int(players_cf_list, ~ safe_int(.x$team_id)),
    team_abbrev = map_chr(players_cf_list, ~ safe_chr(.x$team$abbrev)),
    team_name = map_chr(players_cf_list, ~ safe_chr(.x$team$name)),
    locked_flag = map_lgl(players_cf_list, ~ safe_lgl(.x$locked, FALSE)),
    played_status = map_chr(players_cf_list, ~ safe_chr(.x$played_status$status)),
    played_status_display = map_chr(players_cf_list, ~ safe_chr(.x$played_status$display)),
    active_flag = map_lgl(players_cf_list, ~ safe_lgl(.x$active, FALSE)),
    injury_suspension_status = map_chr(players_cf_list, ~ safe_chr(.x$injury_suspension_status)),
    injury_suspension_status_text = map_chr(players_cf_list, ~ safe_chr(.x$injury_suspension_status_text))
  ) %>%
    mutate(
      run_ts = run_ts,
      state_signature = paste(
        coalesce_chr(team_abbrev),
        coalesce_chr(locked_flag),
        coalesce_chr(played_status),
        coalesce_chr(played_status_display),
        coalesce_chr(active_flag),
        coalesce_chr(injury_suspension_status),
        coalesce_chr(injury_suspension_status_text),
        sep = "::"
      )
    )

  latest_players_cf_existing <- players_cf_history_existing %>%
    group_by(player_id) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(player_id, prev_state_signature = state_signature)

  players_cf_history_new <- player_catalog_current %>%
    left_join(latest_players_cf_existing, by = "player_id") %>%
    filter(is.na(prev_state_signature) | state_signature != prev_state_signature) %>%
    select(-prev_state_signature)

  players_cf_history <- bind_rows(players_cf_history_existing, players_cf_history_new) %>%
    arrange(run_ts, player_id)

  players_cf_latest <- players_cf_history %>%
    group_by(player_id) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup()

  player_catalog <- players_cf_latest %>%
    select(-state_signature)

  players_cf_2026 <- player_catalog
  player_id_lookup <- player_catalog %>%
    select(player_id, full_name, team_abbrev, team_name)

  rounds_to_pull <- if (first_run) {
    seq_len(current_round)
  } else {
    mutable_rounds
  }

  fixture_rounds_to_pull <- sort(unique(c(rounds_to_pull, if (is.na(next_round)) integer() else next_round)))
  ladder_pulls <- map(fixture_rounds_to_pull, get_ladder_fixtures_round)

  ladder_history_new <- map_dfr(ladder_pulls, "ladder") %>%
    filter(round %in% rounds_to_pull)

  fixtures_history_new <- map_dfr(ladder_pulls, "fixtures")

  ladder_history <- bind_rows(ladder_history_existing, ladder_history_new) %>%
    arrange(run_ts, round, position, user_team_id)

  fixtures_history <- bind_rows(fixtures_history_existing, fixtures_history_new) %>%
    distinct(run_ts, fixture_id, .keep_all = TRUE) %>%
    arrange(run_ts, round, fixture)

  team_lookup <- ladder_history %>%
    distinct(user_team_id, team_name, coach_name, is_me) %>%
    filter(!is.na(user_team_id))

  grog_baguettes_team_id <- team_lookup %>%
    filter(is_me %in% TRUE) %>%
    distinct(user_team_id) %>%
    pull(user_team_id) %>%
    first()

  team_round_grid <- ladder_history_new %>%
    distinct(user_team_id, round) %>%
    filter(!is.na(user_team_id), !is.na(round)) %>%
    arrange(round, user_team_id)

  grid_records <- split(team_round_grid, seq_len(nrow(team_round_grid)))

  team_pull_list <- parallel_map(
    grid_records,
    function(row_df) {
      team_id <- row_df$user_team_id[[1]]
      round_value <- row_df$round[[1]]

      tryCatch(
        get_stats_players_round(team_id, round_value),
        error = function(e) {
          list(
            players = tibble(),
            stats = tibble(),
            trades = tibble(),
            error = conditionMessage(e)
          )
        }
      )
    }
  )

  team_players_pull <- if (nrow(team_round_grid) == 0) {
    team_round_grid %>%
      mutate(
        pull = list(),
        players = list(),
        stats = list(),
        trades = list(),
        pull_error = character(),
        pull_ok = logical()
      )
  } else {
    team_round_grid %>%
      mutate(
        pull = team_pull_list,
        players = map(pull, "players"),
        stats = map(pull, "stats"),
        trades = map(pull, "trades"),
        pull_error = map_chr(pull, ~ .x$error %||% NA_character_),
        pull_ok = map_lgl(pull, ~ is.null(.x$error))
      )
  }

  team_round_stats_history_new <- team_players_pull %>%
    select(stats) %>%
    unnest(stats)

  actual_trade_history_new <- team_players_pull %>%
    select(trades) %>%
    unnest(trades)

  team_round_stats_history <- bind_rows(
    team_round_stats_history_existing,
    team_round_stats_history_new
  ) %>%
    distinct(run_ts, user_team_id, round, .keep_all = TRUE) %>%
    arrange(run_ts, round, user_team_id)

  actual_trade_history <- bind_rows(
    actual_trade_history_existing,
    actual_trade_history_new
  ) %>%
    distinct(round, user_team_id, buy_player_id, sell_player_id, .keep_all = TRUE) %>%
    arrange(round, user_team_id, buy_player_id, sell_player_id)

  latest_existing_signatures <- team_round_signatures_existing %>%
    group_by(user_team_id, round) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(user_team_id, round, prev_run_ts = run_ts, prev_roster_signature = roster_signature)

  team_round_results <- team_players_pull %>%
    mutate(
      roster_signature = map_chr(players, build_roster_signature),
      player_rows = map_int(players, nrow)
    ) %>%
    left_join(
      latest_existing_signatures,
      by = c("user_team_id", "round")
    ) %>%
    mutate(
      is_valid_roster_pull = pull_ok & !is.na(roster_signature) & player_rows > 0,
      is_new_snapshot = case_when(
        !is_valid_roster_pull ~ FALSE,
        is.na(prev_roster_signature) ~ TRUE,
        roster_signature != prev_roster_signature ~ TRUE,
        TRUE ~ FALSE
      )
    )

  team_round_signatures_new <- team_round_results %>%
    filter(is_new_snapshot) %>%
    transmute(
      run_ts = run_ts,
      league_id = league_id,
      user_team_id,
      round,
      roster_signature
    )

  team_players_snapshots_new <- team_round_results %>%
    filter(is_new_snapshot) %>%
    select(players) %>%
    unnest(players)

  team_round_signatures <- bind_rows(
    team_round_signatures_existing,
    team_round_signatures_new
  ) %>%
    arrange(run_ts, round, user_team_id)

  team_players_snapshots <- bind_rows(
    team_players_snapshots_existing,
    team_players_snapshots_new
  ) %>%
    arrange(run_ts, round, user_team_id, position_sort, player_id)

  latest_snapshot_per_team_round <- team_round_signatures %>%
    group_by(user_team_id, round) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(user_team_id, round, latest_run_ts = run_ts)

  team_players_latest <- team_players_snapshots %>%
    inner_join(
      latest_snapshot_per_team_round,
      by = c("user_team_id", "round")
    ) %>%
    filter(run_ts == latest_run_ts) %>%
    select(-latest_run_ts) %>%
    arrange(user_team_id, round, position_sort, position, player_id)

  previous_membership_lookup <- team_round_signatures_existing %>%
    group_by(user_team_id, round) %>%
    slice_max(run_ts, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(user_team_id, round, prev_run_ts = run_ts)

  previous_membership_source <- previous_membership_lookup %>%
    inner_join(
      team_players_snapshots_existing,
      by = c("user_team_id", "round", "prev_run_ts" = "run_ts")
    )

  previous_membership <- if (nrow(previous_membership_source) == 0) {
    tibble(
      user_team_id = integer(),
      round = integer(),
      prev_run_ts = as.POSIXct(character()),
      prev_players = list()
    )
  } else {
    previous_membership_source %>%
      group_by(user_team_id, round, prev_run_ts) %>%
      group_modify(~ tibble(prev_players = list(extract_roster_membership(.x)))) %>%
      ungroup()
  }

  current_membership <- team_round_results %>%
    filter(is_new_snapshot) %>%
    transmute(
      user_team_id,
      round,
      detected_run_ts = run_ts,
      from_run_ts = prev_run_ts,
      to_run_ts = run_ts,
      current_players = map(players, extract_roster_membership)
    )

  inferred_changes_new <- current_membership %>%
    left_join(previous_membership, by = c("user_team_id", "round", "from_run_ts" = "prev_run_ts")) %>%
    mutate(
      is_initial_snapshot = is.na(from_run_ts),
      prev_players = map(prev_players, ~ if (is.null(.x)) tibble(player_id = integer()) else .x),
      players_in_tbl = map2(current_players, prev_players, ~ anti_join(.x, .y, by = "player_id")),
      players_out_tbl = map2(prev_players, current_players, ~ anti_join(.x, .y, by = "player_id")),
      players_in = map2(players_in_tbl, is_initial_snapshot, ~ if (.y) integer() else .x$player_id),
      players_out = map2(players_out_tbl, is_initial_snapshot, ~ if (.y) integer() else .x$player_id),
      players_in_n = map_int(players_in, length),
      players_out_n = map_int(players_out, length),
      inferred_trade_pairs = map2(players_out, players_in, pair_inferred_trades)
    ) %>%
    transmute(
      detected_run_ts,
      from_run_ts,
      to_run_ts,
      league_id = league_id,
      user_team_id,
      round,
      change_origin = if_else(is_initial_snapshot, "initial_snapshot", "snapshot_delta"),
      players_out,
      players_in,
      players_out_n,
      players_in_n,
      inferred_trade_pairs
    )

  inferred_changes <- bind_rows(
    inferred_changes_existing,
    inferred_changes_new
  ) %>%
    arrange(to_run_ts, round, user_team_id)

  initialvalue_catalog <- extract_initialvalue_catalog(season_year) %>%
    mutate(name_norm = normalise_player_name(player_name))

  league_focus_player_names <- team_players_latest %>%
    distinct(player_id) %>%
    inner_join(player_catalog %>% select(player_id, full_name), by = "player_id") %>%
    pull(full_name) %>%
    unique()

  existing_history_summary <- player_price_history_existing %>%
    filter(year == season_year) %>%
    group_by(player_name) %>%
    summarise(
      latest_price_stored = latest_non_na(price),
      stored_rounds = list(sort(unique(round))),
      .groups = "drop"
    )

  recent_history_refresh <- player_history_refresh_log_existing %>%
    group_by(player_name) %>%
    summarise(
      last_history_refresh_ts = max(run_ts, na.rm = TRUE),
      .groups = "drop"
    )

  player_refresh_candidates <- initialvalue_catalog %>%
    mutate(is_league_focus = player_name %in% league_focus_player_names) %>%
    left_join(existing_history_summary, by = "player_name") %>%
    left_join(recent_history_refresh, by = "player_name") %>%
    mutate(
      stored_rounds = map(stored_rounds, ~ if (is.null(.x)) integer() else as.integer(.x)),
      missing_history = is.na(latest_price_stored),
      current_price_changed = if_else(
        missing_history,
        FALSE,
        if_else(is.na(current_price_external), FALSE, !dplyr::near(latest_price_stored, current_price_external))
      ),
      missing_mutable_rounds = map_lgl(
        stored_rounds,
        ~ any(!mutable_rounds %in% .x)
      ),
      hours_since_history_refresh = as.numeric(difftime(run_ts, last_history_refresh_ts, units = "hours")),
      league_focus_due = is_league_focus & (
        is.na(last_history_refresh_ts) |
          is.na(hours_since_history_refresh) |
          hours_since_history_refresh >= 12
      ),
      refresh_reason = case_when(
        missing_history ~ "missing_history",
        current_price_changed ~ "current_price_changed",
        missing_mutable_rounds ~ "mutable_round_missing",
        league_focus_due ~ "league_focus_refresh",
        TRUE ~ NA_character_
      )
    )

  players_to_refresh_tbl <- player_refresh_candidates %>%
    filter(!is.na(refresh_reason)) %>%
    select(player_name, refresh_reason, current_price_external, latest_price_stored, is_league_focus, last_history_refresh_ts, hours_since_history_refresh)

  player_price_history_new <- if (nrow(players_to_refresh_tbl) == 0) {
    empty_player_price_history_2026
  } else {
    bind_rows(parallel_map(players_to_refresh_tbl$player_name, safe_get_price_history))
  }

  player_price_history_2026 <- bind_rows(
    player_price_history_existing %>%
      anti_join(players_to_refresh_tbl %>% select(player_name), by = "player_name"),
    player_price_history_new
  ) %>%
    filter(year == season_year) %>%
    distinct(player_name, year, round, .keep_all = TRUE) %>%
    arrange(player_name, round) %>%
    mutate(
      score = if_else(round > current_round, NA_real_, score),
      mins = if_else(round > current_round, NA_real_, mins)
    )

  player_history_refresh_log <- bind_rows(
    player_history_refresh_log_existing,
    players_to_refresh_tbl %>%
      mutate(run_ts = run_ts) %>%
      select(run_ts, everything())
  ) %>%
    arrange(run_ts, player_name)

  player_crosswalk_primary <- initialvalue_catalog %>%
    inner_join(
      player_catalog %>% select(player_id, full_name, name_norm, team_abbrev),
      by = c("name_norm", "team_abbrev")
    ) %>%
    distinct(player_name, player_id, .keep_all = TRUE)

  unmatched_initialvalue <- initialvalue_catalog %>%
    anti_join(player_crosswalk_primary, by = c("player_name", "team_abbrev", "name_norm"))

  player_crosswalk_fallback <- unmatched_initialvalue %>%
    inner_join(
      player_catalog %>%
        count(name_norm, name = "sc_name_matches") %>%
        filter(sc_name_matches == 1) %>%
        inner_join(player_catalog %>% select(player_id, full_name, name_norm, team_abbrev), by = "name_norm"),
      by = "name_norm"
    ) %>%
    distinct(player_name, player_id, .keep_all = TRUE)

  player_crosswalk <- bind_rows(player_crosswalk_primary, player_crosswalk_fallback) %>%
    distinct(player_name, player_id, .keep_all = TRUE)

  player_price_history_sc <- player_price_history_2026 %>%
    inner_join(
      player_crosswalk %>% select(player_name, player_id),
      by = "player_name"
    ) %>%
    transmute(
      player_id,
      player_name,
      year,
      round,
      score,
      mins,
      price
    ) %>%
    distinct(player_id, round, .keep_all = TRUE) %>%
    arrange(player_id, round)

  price_match_discrepancies <- team_players_latest %>%
    distinct(user_team_id, round, player_id) %>%
    anti_join(
      player_price_history_sc %>% distinct(player_id, round),
      by = c("player_id", "round")
    ) %>%
    left_join(player_id_lookup, by = "player_id") %>%
    arrange(round, user_team_id, player_id)

  if (nrow(price_match_discrepancies) > 0) {
    print_results(price_match_discrepancies)
    stop("Stopping: unmatched in-league player_id/round combinations remain in player_price_history_sc")
  }

  run_log <- bind_rows(
    run_log_existing,
    tibble(
      run_ts = run_ts,
      league_id = league_id,
      first_run = first_run,
      settings_current_round = settings_current_round,
      settings_next_round = settings_next_round,
      current_round = current_round,
      next_round = next_round,
      round_inference_source = round_inference_source,
      round_closed_through_utc = round_closed_through_utc,
      rounds_pulled = paste(rounds_to_pull, collapse = ","),
      fixture_rounds_pulled = paste(fixture_rounds_to_pull, collapse = ","),
      mutable_rounds = paste(mutable_rounds, collapse = ","),
      nrl_fixture_rounds_pulled = paste(nrl_fixture_rounds_to_pull, collapse = ","),
      nrl_ladder_rounds_pulled = paste(nrl_ladder_rounds_to_pull, collapse = ","),
      ladder_rows_new = nrow(ladder_history_new),
      nrl_fixture_rows_new = nrow(nrl_fixture_source_history_new),
      nrl_ladder_rows_new = nrow(nrl_team_context_history_new),
      player_snapshot_rows_new = nrow(team_players_snapshots_new),
      changed_team_rounds = nrow(team_round_signatures_new),
      failed_team_rounds = sum(!team_round_results$pull_ok),
      players_cf_changed_n = nrow(players_cf_history_new),
      player_history_refreshed_n = nrow(players_to_refresh_tbl)
    )
  )

  source_refresh_log <- bind_rows(
    source_refresh_log_existing,
    tibble(
      run_ts = run_ts,
      league_id = league_id,
      settings_current_round = settings_current_round,
      settings_next_round = settings_next_round,
      current_round = current_round,
      next_round = next_round,
      round_inference_source = round_inference_source,
      round_closed_through_utc = round_closed_through_utc,
      mutable_rounds = paste(mutable_rounds, collapse = ","),
      rounds_pulled = paste(rounds_to_pull, collapse = ","),
      fixture_rounds_pulled = paste(fixture_rounds_to_pull, collapse = ","),
      nrl_fixture_rounds_pulled = paste(nrl_fixture_rounds_to_pull, collapse = ","),
      nrl_ladder_rounds_pulled = paste(nrl_ladder_rounds_to_pull, collapse = ","),
      nrl_fixture_rows_new = nrow(nrl_fixture_source_history_new),
      nrl_ladder_rows_new = nrow(nrl_team_context_history_new),
      players_cf_changed_n = nrow(players_cf_history_new),
      player_history_refreshed_n = nrow(players_to_refresh_tbl),
      competition_status = competition_status
    )
  )

  saveRDS(ladder_history, path_ladder_history)
  saveRDS(fixtures_history, path_fixtures_history)
  saveRDS(team_players_snapshots, path_team_players_snapshots)
  saveRDS(team_players_latest, path_team_players_latest)
  saveRDS(team_round_signatures, path_team_round_signatures)
  saveRDS(team_round_stats_history, path_team_round_stats_history)
  saveRDS(actual_trade_history, path_actual_trade_history)
  saveRDS(inferred_changes, path_inferred_changes)
  saveRDS(competition_state_history, path_competition_state_history)
  saveRDS(nrl_fixture_source_history, path_nrl_fixture_source_history)
  saveRDS(nrl_team_context_history, path_nrl_team_context_history)
  saveRDS(players_cf_history, path_players_cf_history)
  saveRDS(players_cf_latest, path_players_cf_latest)
  saveRDS(player_history_refresh_log, path_player_history_refresh_log)
  saveRDS(source_refresh_log, path_source_refresh_log)
  saveRDS(run_log, path_run_log)
  saveRDS(player_price_history_2026, path_player_price_history_2026)
  saveRDS(players_cf_2026, path_players_cf_2026)
  saveRDS(player_id_lookup, path_player_id_lookup)
  saveRDS(player_price_history_sc, path_player_price_history_sc)

  grog_baguettes_latest <- team_players_latest %>%
    filter(user_team_id == grog_baguettes_team_id)

  grog_baguettes_changes <- inferred_changes %>%
    filter(user_team_id == grog_baguettes_team_id) %>%
    arrange(desc(to_run_ts))

  league_change_summary <- inferred_changes %>%
    left_join(
      team_lookup %>% distinct(user_team_id, team_name, coach_name),
      by = "user_team_id"
    ) %>%
    arrange(desc(to_run_ts), round, team_name)

  list(
    settings = settings,
    me_profile = me_profile,
    teams_reference = teams_reference,
    settings_current_round = settings_current_round,
    settings_next_round = settings_next_round,
    current_round = current_round,
    next_round = next_round,
    round_inference_source = round_inference_source,
    round_closed_through_utc = round_closed_through_utc,
    competition_status = competition_status,
    mutable_rounds = mutable_rounds,
    first_run = first_run,
    ladder_history = ladder_history,
    fixtures_history = fixtures_history,
    team_lookup = team_lookup,
    grog_baguettes_team_id = grog_baguettes_team_id,
    team_players_pull = team_players_pull,
    team_round_results = team_round_results,
    team_round_stats_history = team_round_stats_history,
    actual_trade_history = actual_trade_history,
    team_round_signatures = team_round_signatures,
    team_players_snapshots = team_players_snapshots,
    team_players_latest = team_players_latest,
    inferred_changes = inferred_changes,
    run_log = run_log,
    competition_state_history = competition_state_history,
    nrl_fixture_source_history = nrl_fixture_source_history,
    nrl_team_context_history = nrl_team_context_history,
    players_cf_history = players_cf_history,
    players_cf_latest = players_cf_latest,
    player_history_refresh_log = player_history_refresh_log,
    source_refresh_log = source_refresh_log,
    player_catalog = player_catalog,
    players_cf_2026 = players_cf_2026,
    player_id_lookup = player_id_lookup,
    initialvalue_catalog = initialvalue_catalog,
    player_price_history_2026 = player_price_history_2026,
    player_price_history_sc = player_price_history_sc,
    grog_baguettes_latest = grog_baguettes_latest,
    grog_baguettes_changes = grog_baguettes_changes,
    league_change_summary = league_change_summary,
    rounds_to_pull = rounds_to_pull,
    fixture_rounds_to_pull = fixture_rounds_to_pull
  )
}

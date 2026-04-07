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
drive_sync_script <- "scripts/google_drive_bundle_sync.R"
build_prompt_script <- "scripts/build_gpt_prompt_pack.R"
app_state <- new.env(parent = emptyenv())
app_state$last_drive_sync <- as.POSIXct(NA)

initialize_runtime_data_dir <- function() {
  dir.create(runtime_root, recursive = TRUE, showWarnings = FALSE)

  if (dir.exists(data_dir)) {
    return(invisible(data_dir))
  }

  if (dir.exists(bundled_data_dir)) {
    dir.create(dirname(data_dir), recursive = TRUE, showWarnings = FALSE)
    file.copy(
      from = bundled_data_dir,
      to = dirname(data_dir),
      recursive = TRUE
    )
  } else {
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

sync_from_drive_if_needed <- function(force = FALSE) {
  if (!file.exists(drive_sync_script)) {
    return(invisible(FALSE))
  }

  source(drive_sync_script, local = TRUE)

  if (!exists("drive_sync_is_configured", mode = "function") ||
      !drive_sync_is_configured()) {
    return(invisible(FALSE))
  }

  needs_sync <- force ||
    is.na(app_state$last_drive_sync) ||
    as.numeric(difftime(Sys.time(), app_state$last_drive_sync, units = "mins")) >= 5

  if (!needs_sync) {
    return(invisible(FALSE))
  }

  try(
    restore_data_bundle_from_drive(data_dir, league_id),
    silent = TRUE
  )

  app_state$last_drive_sync <- Sys.time()
  invisible(TRUE)
}

upload_to_drive_if_configured <- function() {
  if (!file.exists(drive_sync_script)) {
    return(invisible(FALSE))
  }

  source(drive_sync_script, local = TRUE)

  if (!exists("drive_sync_is_configured", mode = "function") ||
      !drive_sync_is_configured()) {
    return(invisible(FALSE))
  }

  try(
    upload_data_bundle_to_drive(data_dir, league_id),
    silent = TRUE
  )
}

load_dashboard_data <- function() {
  sync_from_drive_if_needed(force = FALSE)

  list(
    game_rules = read_required_rds(file.path(data_dir, "game_rules_round_state.rds")),
    ladder_history = read_required_rds(file.path(data_dir, "ladder_history.rds")),
    fixtures_history = read_required_rds(file.path(data_dir, "fixtures_history.rds")),
    structure_health = read_required_rds(file.path(data_dir, "structure_health_table.rds")),
    opponent_behaviour = read_required_rds(file.path(data_dir, "opponent_behaviour_history.rds")),
    fixture_matchup = read_required_rds(file.path(data_dir, "fixture_matchup_table.rds")),
    team_performance = read_required_rds(file.path(data_dir, "team_performance_context.rds")),
    source_refresh_log = read_required_rds(file.path(data_dir, "source_refresh_log.rds")),
    team_round_stats_history = read_required_rds(file.path(data_dir, "team_round_stats_history.rds")),
    players_cf_latest = read_required_rds(file.path(data_dir, "players_cf_latest.rds")),
    team_players_latest = read_required_rds(file.path(data_dir, "team_players_latest.rds")),
    availability_risk = read_required_rds(file.path(data_dir, "availability_risk_table.rds")),
    squad_round_enriched = read_required_rds(file.path(data_dir, "squad_round_enriched.rds")),
    cash_generation = read_required_rds(file.path(data_dir, "cash_generation_model.rds")),
    master_player = read_required_rds(file.path(data_dir, "master_player_round_latest.rds")),
    checklist_coverage = read_required_rds(file.path(data_dir, "checklist_coverage_status.rds")),
    long_horizon = read_required_rds(file.path(data_dir, "long_horizon_planning_table.rds")),
    prompt_pack_meta = read_optional_text(file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack_meta.json")),
    prompt_pack_text = read_optional_text(file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack.md")),
    origin_watch = read_optional_csv(file.path(data_dir, "manual_inputs", "origin_watch.csv")),
    weekly_notes = read_optional_text(file.path(data_dir, "manual_inputs", "weekly_context_notes.md"))
  )
}

theme_sc <- bs_theme(
  version = 5,
  bg = "#f7f3ea",
  fg = "#1b1a17",
  primary = "#8a5a00",
  secondary = "#24434d",
  success = "#2f6f4f",
  base_font = font_google("DM Sans"),
  heading_font = font_google("Space Grotesk")
)

metric_card <- function(title, output_id, subtitle = NULL) {
  card(
    class = "shadow-sm border-0 h-100",
    div(
      class = "card-body",
      tags$div(class = "text-muted text-uppercase small", title),
      tags$div(class = "display-6 fw-bold", textOutput(output_id)),
      if (!is.null(subtitle)) tags$div(class = "small text-muted mt-2", subtitle)
    )
  )
}

responsive_table <- function(output_id) {
  div(class = "table-responsive", tableOutput(output_id))
}

ui <- page_navbar(
  title = "SuperCoach HQ",
  theme = theme_sc,
  bg = "#efe3c5",
  inverse = FALSE,
  header = tags$head(
    tags$style(HTML("
      .bslib-card { border-radius: 20px; }
      .display-6 { font-size: 1.7rem; }
      .section-note { color: #5f5a4e; }
      .table-responsive { overflow-x: auto; }
      pre { white-space: pre-wrap; word-break: break-word; }
      .app-actions { display: flex; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 1rem; }
    "))
  ),
  nav_panel(
    "Overview",
    div(
      class = "app-actions",
      actionButton("refresh_app_data", "Refresh From Storage", class = "btn btn-primary")
    ),
    layout_column_wrap(
      width = 1/4,
      metric_card("Current Round", "current_round_text"),
      metric_card("Last Refresh", "last_refresh_text"),
      metric_card("Current Matchup", "matchup_text"),
      metric_card("Latest GPT Pack", "latest_export_text")
    ),
    card(
      full_screen = TRUE,
      card_header("League Financial Snapshot"),
      plotOutput("league_finance_plot", height = "360px"),
      card_footer(class = "section-note", "Squad value vs cash balance, with projected weekly strength shown by bubble size.")
    ),
    card(
      card_header("Fixture Runway"),
      plotOutput("fixture_runway_plot", height = "340px"),
      card_footer(class = "section-note", "Next five rounds of official NRL fixture difficulty for your side and this week's opponent.")
    ),
    card(
      card_header("League Schedule Window"),
      responsive_table("league_schedule_table")
    )
  ),
  nav_panel(
    "Matchup",
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Head-to-Head Comparison"),
        plotOutput("matchup_compare_plot", height = "360px")
      ),
      card(
        card_header("Opponent Fingerprint"),
        responsive_table("opponent_profile_table")
      )
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Your Availability Watch"),
        responsive_table("your_availability_table")
      ),
      card(
        card_header("Opponent Availability Watch"),
        responsive_table("opponent_availability_table")
      )
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Opponent Trade Timeline"),
        plotOutput("opponent_trade_plot", height = "320px")
      ),
      card(
        card_header("NRL Club Exposure"),
        plotOutput("club_exposure_plot", height = "320px")
      )
    )
  ),
  nav_panel(
    "Signals",
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Your Squad Leverage Watch"),
        responsive_table("your_signal_table")
      ),
      card(
        card_header("Next-Round Market Watchlist"),
        responsive_table("market_watch_table")
      )
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Cash Generation Radar"),
        responsive_table("cash_watch_table")
      ),
      card(
        card_header("NRL Context Watch"),
        responsive_table("nrl_context_table")
      )
    ),
    card(
      card_header("NRL Trend Radar"),
      plotOutput("team_performance_plot", height = "360px"),
      card_footer(class = "section-note", "Attacking trend lines for the NRL clubs most represented in this week's head-to-head.")
    )
  ),
  nav_panel(
    "League",
    card(
      card_header("League Table"),
      responsive_table("league_snapshot_table")
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Refresh Log"),
        responsive_table("source_health_table")
      ),
      card(
        card_header("Coverage Gaps"),
        responsive_table("coverage_gap_table")
      )
    )
  ),
  nav_panel(
    "Export",
    div(
      class = "app-actions",
      actionButton("build_prompt_pack", "Build GPT Pack", class = "btn btn-primary"),
      downloadButton("download_prompt_pack", "Download Latest GPT Pack", class = "btn btn-outline-secondary")
    ),
    card(
      card_header("Export Status"),
      div(
        class = "card-body",
        textOutput("prompt_pack_status"),
        tags$div(class = "small text-muted mt-2", "This pack is meant for your custom GPT. The dashboard is for scanning, not final reasoning.")
      )
    ),
    layout_column_wrap(
      width = 1/2,
      card(
        card_header("Origin Watch"),
        responsive_table("origin_watch_table")
      ),
      card(
        card_header("Weekly Notes"),
        verbatimTextOutput("weekly_notes_text")
      )
    ),
    card(
      card_header("GPT Pack Preview"),
      verbatimTextOutput("prompt_pack_preview")
    )
  )
)

server <- function(input, output, session) {
  refresh_nonce <- reactiveVal(Sys.time())
  prompt_status <- reactiveVal("No GPT pack built in this session.")

  observeEvent(input$refresh_app_data, {
    sync_from_drive_if_needed(force = TRUE)
    refresh_nonce(Sys.time())
    prompt_status("Dashboard data refreshed from storage.")
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

    upload_to_drive_if_configured()
    refresh_nonce(Sys.time())
    prompt_status(
      paste(
        "GPT pack built at",
        format(result$generated_at, tz = "Australia/Sydney", usetz = TRUE)
      )
    )
  })

  dashboard_data <- reactive({
    refresh_nonce()
    load_dashboard_data()
  })

  current_round <- reactive({
    data <- dashboard_data()
    if (is.null(data$game_rules) || nrow(data$game_rules) == 0) {
      return(NA_integer_)
    }
    data$game_rules$current_round[[1]]
  })

  next_round <- reactive({
    data <- dashboard_data()
    if (is.null(data$game_rules) || nrow(data$game_rules) == 0) {
      return(NA_integer_)
    }
    data$game_rules$next_round[[1]] %||% (current_round() + 1L)
  })

  latest_ladder_round <- reactive({
    data <- dashboard_data()
    round_value <- current_round()
    req(!is.null(data$ladder_history), !is.na(round_value))

    data$ladder_history %>%
      filter(round == round_value) %>%
      group_by(user_team_id) %>%
      slice_max(run_ts, n = 1, with_ties = FALSE) %>%
      ungroup()
  })

  latest_fixtures <- reactive({
    data <- dashboard_data()
    req(!is.null(data$fixtures_history))

    data$fixtures_history %>%
      group_by(fixture_id) %>%
      slice_max(run_ts, n = 1, with_ties = FALSE) %>%
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
    round_value <- current_round()
    matchup <- current_matchup()
    req(!is.null(data$team_players_latest), !is.null(data$players_cf_latest))

    data$team_players_latest %>%
      filter(
        round == round_value,
        user_team_id %in% c(matchup$my_team_id, matchup$opponent_team_id)
      ) %>%
      distinct(user_team_id, player_id) %>%
      left_join(
        data$players_cf_latest %>% select(player_id, team_abbrev),
        by = "player_id"
      ) %>%
      filter(!is.na(team_abbrev)) %>%
      count(user_team_id, team_abbrev, name = "player_n") %>%
      mutate(side = if_else(user_team_id == matchup$my_team_id, "You", "Opponent"))
  })

  matchup_summary <- reactive({
    ladder <- latest_ladder_round()
    structure <- dashboard_data()$structure_health
    team_round_stats <- dashboard_data()$team_round_stats_history
    round_value <- current_round()
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
        structure %>%
          filter(round == round_value) %>%
          select(user_team_id, avg_projected_score_this_week, locked_players, dpp_players),
        by = "user_team_id"
      ) %>%
      left_join(
        team_round_stats %>%
          filter(round == round_value) %>%
          group_by(user_team_id) %>%
          slice_max(run_ts, n = 1, with_ties = FALSE) %>%
          ungroup() %>%
          select(user_team_id, total_changes, trade_boosts_used),
        by = "user_team_id"
      ) %>%
      mutate(side = if_else(is_me %in% TRUE, "You", "Opponent"))

    req(nrow(summary_tbl) == 2)
    summary_tbl
  })

  current_squad_signals <- reactive({
    data <- dashboard_data()
    matchup <- current_matchup()
    round_value <- current_round()
    next_round_value <- next_round()

    req(
      !is.null(data$squad_round_enriched),
      !is.null(data$availability_risk),
      !is.null(data$fixture_matchup)
    )

    data$squad_round_enriched %>%
      filter(round == round_value, user_team_id %in% c(matchup$my_team_id, matchup$opponent_team_id)) %>%
      left_join(
        data$availability_risk %>%
          select(
            player_id,
            team_abbrev,
            risk_band,
            injury_suspension_status_text,
            played_status_display,
            locked_flag
          ),
        by = "player_id"
      ) %>%
      left_join(
        data$fixture_matchup %>%
          filter(round == next_round_value) %>%
          select(
            team_abbrev,
            next_opponent = opponent,
            next_matchup_rating = matchup_rating_by_player,
            next_3_rounds_difficulty,
            schedule_swing_indicator,
            bye_flag
          ),
        by = "team_abbrev"
      ) %>%
      left_join(
        data$cash_generation %>%
          select(player_id, projected_price_rise_next_round, cumulative_cash_generation),
        by = "player_id"
      ) %>%
      mutate(
        side = if_else(user_team_id == matchup$my_team_id, "You", "Opponent"),
        risk_weight = case_when(
          risk_band == "high" ~ 3,
          risk_band == "medium" ~ 2,
          TRUE ~ 1
        ),
        signal_score = coalesce(projected_score_next_3_weeks, 0) / 12 +
          coalesce(next_matchup_rating, 0) / 2 +
          coalesce(projected_price_rise_next_round, 0) / 15000 -
          risk_weight * 3 -
          if_else(bye_flag %in% TRUE, 8, 0)
      )
  })

  market_watchlist <- reactive({
    data <- dashboard_data()
    next_round_value <- next_round()
    round_value <- current_round()

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
        data$cash_generation %>%
          select(player_id, projected_price_rise_next_round, cash_cow_maturity_status),
        by = "player_id"
      ) %>%
      left_join(
        data$fixture_matchup %>%
          filter(round == next_round_value) %>%
          select(
            team_abbrev,
            next_opponent = opponent,
            next_matchup_rating = matchup_rating_by_player,
            schedule_swing_indicator,
            bye_flag
          ),
        by = "team_abbrev"
      ) %>%
      left_join(
        data$team_performance %>%
          filter(round == round_value) %>%
          select(team_abbrev, attacking_trend_last_3),
        by = "team_abbrev"
      ) %>%
      mutate(
        recent_average = coalesce(average_3_round, current_season_average, 0),
        signal_score = recent_average +
          coalesce(next_matchup_rating, 0) / 2 +
          pmax(coalesce(attacking_trend_last_3, 0), 0) / 6 +
          coalesce(projected_price_rise_next_round, 0) / 15000 -
          if_else(bye_flag %in% TRUE, 40, 0) -
          if_else(!is.na(injury_suspension_status_text) & nzchar(injury_suspension_status_text), 25, 0)
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
        projected_rise = dollar(projected_price_rise_next_round),
        swing = schedule_swing_indicator,
        maturity = cash_cow_maturity_status
      ) %>%
      slice_head(n = 14)
  })

  cash_watch <- reactive({
    data <- dashboard_data()
    next_round_value <- next_round()

    req(!is.null(data$cash_generation), !is.null(data$players_cf_latest), !is.null(data$fixture_matchup))

    data$cash_generation %>%
      left_join(
        data$fixture_matchup %>%
          filter(round == next_round_value) %>%
          select(team_abbrev, next_opponent = opponent),
        by = "team_abbrev"
      ) %>%
      arrange(desc(projected_price_rise_next_round)) %>%
      transmute(
        player = full_name,
        team = team_abbrev,
        next_opponent,
        current_price = dollar(current_price),
        next_rise = dollar(projected_price_rise_next_round),
        total_cash = dollar(cumulative_cash_generation),
        maturity = cash_cow_maturity_status
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

  output$current_round_text <- renderText({
    data <- dashboard_data()
    round_value <- current_round()

    if (is.na(round_value)) {
      return("NA")
    }

    settings_round <- if (!is.null(data$game_rules) && "settings_current_round" %in% names(data$game_rules)) {
      data$game_rules$settings_current_round[[1]]
    } else {
      NA_integer_
    }

    inference_source <- if (!is.null(data$game_rules) && "round_inference_source" %in% names(data$game_rules)) {
      data$game_rules$round_inference_source[[1]]
    } else {
      NA_character_
    }

    if (!is.na(settings_round) && settings_round != round_value) {
      return(paste0(round_value, " (settings ", settings_round, ", ", inference_source %||% "inferred", ")"))
    }

    as.character(round_value)
  })

  output$last_refresh_text <- renderText({
    data <- dashboard_data()
    if (is.null(data$source_refresh_log) || nrow(data$source_refresh_log) == 0) {
      return("No refresh yet")
    }
    format(max(data$source_refresh_log$run_ts), tz = "Australia/Sydney", usetz = TRUE)
  })

  output$matchup_text <- renderText({
    matchup_summary() %>%
      filter(side == "Opponent") %>%
      transmute(label = paste0(trimws(team_name), " (", trimws(coach_name), ")")) %>%
      pull(label) %>%
      first()
  })

  output$latest_export_text <- renderText({
    path <- file.path(data_dir, "analysis_export", "latest_gpt_prompt_pack.md")
    if (!file.exists(path)) {
      return("Not built yet")
    }
    format(file.info(path)$mtime, tz = "Australia/Sydney", usetz = TRUE)
  })

  output$league_finance_plot <- renderPlot({
    structure <- dashboard_data()$structure_health

    plot_df <- latest_ladder_round() %>%
      left_join(
        structure %>%
          filter(round == current_round()) %>%
          select(user_team_id, avg_projected_score_this_week),
        by = "user_team_id"
      ) %>%
      mutate(
        highlight = case_when(
          is_me %in% TRUE ~ "You",
          user_team_id == current_matchup()$opponent_team_id ~ "Opponent",
          TRUE ~ "League"
        )
      )

    ggplot(plot_df, aes(team_value_total_calc, cash_end_round_calc, color = highlight, size = avg_projected_score_this_week)) +
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

  output$matchup_compare_plot <- renderPlot({
    plot_df <- matchup_summary() %>%
      transmute(
        side,
        `Team Value` = team_value_total_calc,
        `Cash` = cash_end_round_calc,
        `Proj Score` = avg_projected_score_this_week,
        `Locked Players` = locked_players
      ) %>%
      pivot_longer(-side, names_to = "metric", values_to = "value")

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

  output$opponent_profile_table <- renderTable({
    matchup_summary() %>%
      filter(side == "Opponent") %>%
      transmute(
        Coach = coach_name,
        Team = team_name,
        `Squad Value` = dollar(team_value_total_calc),
        Bank = dollar(cash_end_round_calc),
        `Projected Score` = round(avg_projected_score_this_week, 1),
        `Round Changes` = total_changes,
        `Boosts Used` = trade_boosts_used,
        `Locked Players` = locked_players,
        `DPP Players` = dpp_players
      )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$your_availability_table <- renderTable({
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
        Locked = currently_locked,
        `Proj 3w` = round(projected_score_next_3_weeks, 1)
      ) %>%
      slice_head(n = 12)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$opponent_availability_table <- renderTable({
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
        Locked = currently_locked,
        `Proj 3w` = round(projected_score_next_3_weeks, 1)
      ) %>%
      slice_head(n = 12)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$opponent_trade_plot <- renderPlot({
    trade_df <- dashboard_data()$opponent_behaviour %>%
      filter(user_team_id == current_matchup()$opponent_team_id) %>%
      transmute(
        round,
        inferred_moves = inferred_players_in,
        actual_moves = actual_trade_count
      ) %>%
      pivot_longer(-round, names_to = "move_type", values_to = "moves")

    ggplot(trade_df, aes(round, moves, fill = move_type)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = c("inferred_moves" = "#1f5c70", "actual_moves" = "#c4512d")) +
      scale_x_continuous(breaks = pretty_breaks()) +
      labs(x = "Round", y = "Moves detected", fill = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  output$club_exposure_plot <- renderPlot({
    ggplot(squad_team_mix(), aes(reorder(team_abbrev, player_n), player_n, fill = side)) +
      geom_col(position = "dodge") +
      coord_flip() +
      scale_fill_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70")) +
      labs(x = NULL, y = "Players from club", fill = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  output$fixture_runway_plot <- renderPlot({
    fixture_df <- dashboard_data()$fixture_matchup %>%
      inner_join(
        squad_team_mix(),
        by = "team_abbrev",
        relationship = "many-to-many"
      ) %>%
      filter(round >= current_round(), round <= current_round() + 4L) %>%
      group_by(side, round) %>%
      summarise(
        weighted_difficulty = weighted.mean(next_3_rounds_difficulty, w = pmax(player_n, 1), na.rm = TRUE),
        bye_players = sum(if_else(bye_flag %in% TRUE, player_n, 0L), na.rm = TRUE),
        .groups = "drop"
      )

    ggplot(fixture_df, aes(round, weighted_difficulty, color = side)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 3) +
      geom_text(aes(label = if_else(bye_players > 0, paste0("bye:", bye_players), "")), nudge_y = 0.5, show.legend = FALSE) +
      scale_color_manual(values = c("You" = "#c4512d", "Opponent" = "#1f5c70")) +
      scale_x_continuous(breaks = pretty_breaks()) +
      labs(x = "Round", y = "Weighted fixture difficulty", color = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
  })

  output$league_schedule_table <- renderTable({
    future_league_schedule()
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$your_signal_table <- renderTable({
    current_squad_signals() %>%
      filter(side == "You", selected_this_week %in% TRUE) %>%
      arrange(desc(signal_score)) %>%
      transmute(
        Player = full_name,
        Team = team_abbrev,
        `Next Opp` = next_opponent,
        `Proj 3w` = round(projected_score_next_3_weeks, 1),
        `Next Rise` = dollar(projected_price_rise_next_round),
        Matchup = round(next_matchup_rating, 1),
        Swing = schedule_swing_indicator,
        Urgency = sell_urgency
      ) %>%
      slice_head(n = 14)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$market_watch_table <- renderTable({
    market_watchlist()
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$cash_watch_table <- renderTable({
    cash_watch()
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$nrl_context_table <- renderTable({
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
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$league_snapshot_table <- renderTable({
    latest_ladder_round() %>%
      left_join(
        dashboard_data()$team_round_stats_history %>%
          filter(round == current_round()) %>%
          group_by(user_team_id) %>%
          slice_max(run_ts, n = 1, with_ties = FALSE) %>%
          ungroup() %>%
          select(user_team_id, total_changes, trade_boosts_used),
        by = "user_team_id"
      ) %>%
      arrange(position) %>%
      transmute(
        Pos = position,
        Team = team_name,
        Coach = coach_name,
        `Round Pts` = round_points,
        `Squad Value` = dollar(team_value_total_calc),
        Cash = dollar(cash_end_round_calc),
        `Changes` = total_changes,
        `Boosts Used` = trade_boosts_used
      )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$team_performance_plot <- renderPlot({
    selected_abbrevs <- squad_team_mix() %>%
      group_by(team_abbrev) %>%
      summarise(total_players = sum(player_n), .groups = "drop") %>%
      slice_max(total_players, n = 6, with_ties = FALSE)

    perf_df <- dashboard_data()$team_performance %>%
      filter(round <= current_round()) %>%
      filter(team_abbrev %in% unique(selected_abbrevs$team_abbrev))

    ggplot(perf_df, aes(round, attacking_trend_last_3, color = team_abbrev)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      scale_x_continuous(breaks = pretty_breaks()) +
      labs(x = "Round", y = "Attacking trend (last 3)", color = "Team") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
  })

  output$source_health_table <- renderTable({
    source_health()
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$coverage_gap_table <- renderTable({
    dashboard_data()$checklist_coverage %>%
      filter(status != "implemented") %>%
      transmute(
        Item = checklist_item,
        Status = status,
        Notes = notes
      ) %>%
      slice_head(n = 12)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$prompt_pack_status <- renderText({
    prompt_status()
  })

  output$origin_watch_table <- renderTable({
    data <- dashboard_data()$origin_watch

    if (is.null(data) || nrow(data) == 0) {
      return(data.frame(Note = "Fill data/supercoach_league_21064/manual_inputs/origin_watch.csv to track probable and official Origin selections."))
    }

    data
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$weekly_notes_text <- renderText({
    dashboard_data()$weekly_notes %||%
      "Add notes to data/supercoach_league_21064/manual_inputs/weekly_context_notes.md and they will appear here and in the GPT pack."
  })

  output$prompt_pack_preview <- renderText({
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

  output$download_prompt_pack <- downloadHandler(
    filename = function() {
      paste0("supercoach-gpt-pack-round-", current_round() %||% "na", ".md")
    },
    content = function(file) {
      source(build_prompt_script, local = TRUE)
      result <- build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)
      file.copy(result$markdown_path, file, overwrite = TRUE)
      upload_to_drive_if_configured()
    }
  )
}

shinyApp(ui, server)

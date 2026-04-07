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
data_dir <- file.path("data", paste0("supercoach_league_", league_id))
drive_sync_script <- "scripts/google_drive_bundle_sync.R"
app_state <- new.env(parent = emptyenv())
app_state$last_drive_sync <- as.POSIXct(NA)

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

read_required_rds <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  readRDS(path)
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
    players_cf_latest = read_required_rds(file.path(data_dir, "players_cf_latest.rds")),
    team_players_latest = read_required_rds(file.path(data_dir, "team_players_latest.rds"))
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

metric_card <- function(title, value, subtitle = NULL) {
  card(
    class = "shadow-sm border-0",
    card_body(
      tags$div(class = "text-muted text-uppercase small", title),
      tags$div(class = "display-6 fw-bold", value),
      if (!is.null(subtitle)) tags$div(class = "small text-muted mt-2", subtitle)
    )
  )
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
    "))
  ),
  nav_panel(
    "Overview",
    div(
      class = "mb-3",
      actionButton("refresh_app_data", "Refresh From Storage", class = "btn btn-primary")
    ),
    layout_column_wrap(
      width = 1/3,
      metric_card("Current Round", textOutput("current_round_text")),
      metric_card("Last Refresh", textOutput("last_refresh_text")),
      metric_card("Current Matchup", textOutput("matchup_text"))
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
      card_footer(class = "section-note", "Next five rounds of official NRL fixture difficulty for your team and this week's opponent.")
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
        tableOutput("opponent_profile_table")
      )
    ),
    card(
      card_header("Opponent Trade Timeline"),
      plotOutput("opponent_trade_plot", height = "320px"),
      card_footer(class = "section-note", "Inferred/observed squad change activity by round for this week's opponent.")
    )
  ),
  nav_panel(
    "League",
    card(
      card_header("League Table"),
      tableOutput("league_snapshot_table")
    ),
    card(
      card_header("Team Performance Trend"),
      plotOutput("team_performance_plot", height = "360px")
    )
  )
)

server <- function(input, output, session) {
  refresh_nonce <- reactiveVal(Sys.time())

  observeEvent(input$refresh_app_data, {
    sync_from_drive_if_needed(force = TRUE)
    refresh_nonce(Sys.time())
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

  current_matchup <- reactive({
    data <- dashboard_data()
    round_value <- current_round()
    req(!is.null(data$fixtures_history), !is.na(round_value))

    my_team_id <- latest_ladder_round() %>%
      filter(is_me %in% TRUE) %>%
      pull(user_team_id) %>%
      first()

    fixtures <- data$fixtures_history %>%
      filter(round == round_value) %>%
      group_by(fixture_id) %>%
      slice_max(run_ts, n = 1, with_ties = FALSE) %>%
      ungroup()

    matchup <- fixtures %>%
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
    round_value <- current_round()
    matchup <- current_matchup()

    summary_tbl <- ladder %>%
      filter(user_team_id %in% c(matchup$my_team_id, matchup$opponent_team_id)) %>%
      select(
        user_team_id, team_name, coach_name, is_me, squad_value_calc,
        cash_end_round_calc, team_value_total_calc, trades_remaining, boosts_remaining
      ) %>%
      left_join(
        structure %>%
          filter(round == round_value) %>%
          select(user_team_id, avg_projected_score_this_week, locked_players, dpp_players),
        by = "user_team_id"
      ) %>%
      mutate(side = if_else(is_me %in% TRUE, "You", "Opponent"))

    req(nrow(summary_tbl) == 2)
    summary_tbl
  })

  output$current_round_text <- renderText({
    current_round() %||% "NA"
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
      transmute(label = paste0(team_name, " (", coach_name, ")")) %>%
      pull(label) %>%
      first()
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
        `Bank` = dollar(cash_end_round_calc),
        `Projected Score` = round(avg_projected_score_this_week, 1),
        `Locked Players` = locked_players,
        `DPP Players` = dpp_players
      )
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

  output$fixture_runway_plot <- renderPlot({
    fixture_df <- dashboard_data()$fixture_matchup %>%
      inner_join(
        squad_team_mix(),
        by = "team_abbrev"
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

  output$league_snapshot_table <- renderTable({
    latest_ladder_round() %>%
      arrange(position) %>%
      transmute(
        Pos = position,
        Team = team_name,
        Coach = coach_name,
        `Round Pts` = round_points,
        `Squad Value` = dollar(team_value_total_calc),
        `Cash` = dollar(cash_end_round_calc),
        `Trade Count` = trades_used_to_date
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
}

shinyApp(ui, server)

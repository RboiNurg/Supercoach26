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
    nrl_fixture_source_history = read_required_rds(file.path(data_dir, "nrl_fixture_source_history.rds")),
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

responsive_table <- function(output_id) {
  div(class = "table-wrap", tableOutput(output_id))
}

ui <- page_navbar(
  title = "SuperCoach War Room",
  theme = theme_sc,
  bg = "#0f2e23",
  inverse = FALSE,
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
      .bslib-page-nav {
        max-width: 1120px;
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
        overflow: hidden;
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
      }
      .table {
        margin-bottom: 0;
      }
      .table th {
        font-family: 'Oswald', sans-serif;
        letter-spacing: 0.02em;
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
      card_body(
        tags$div(class = "hero-kicker", "Live league pulse"),
        tags$div(class = "hero-title", "Scan the week fast, then send the real pack to GPT."),
        tags$div(class = "hero-copy", "This board is for quick speculation, freshness checks, and matchup feel. The heavier decision logic still belongs in your exported weekly prompt pack."),
        div(
          class = "action-bar",
          actionButton("refresh_app_data", "Refresh From Storage", class = "btn-sc"),
          downloadButton("download_prompt_pack", "Download Latest GPT Pack", class = "btn-sc-outline")
        ),
        tags$div(class = "hero-note", textOutput("snapshot_status_text"))
      )
    ),
    div(
      class = "metric-grid",
      metric_card("Current Round", "current_round_text"),
      metric_card("Snapshot Round", "snapshot_round_text"),
      metric_card("Last Refresh", "last_refresh_text"),
      metric_card("Current Matchup", "matchup_text"),
      metric_card("Latest GPT Pack", "latest_export_text")
    ),
    card(
      class = "sc-card",
      card_header("League Financial Snapshot"),
      plotOutput("league_finance_plot", height = "360px"),
      card_footer(class = "section-note", "Squad value vs cash balance, with projected weekly strength shown by bubble size.")
    ),
    card(
      class = "sc-card",
      card_header("Fixture Runway"),
      plotOutput("fixture_runway_plot", height = "340px"),
      card_footer(class = "section-note", "Next five rounds of official NRL fixture difficulty for your side and this week's opponent.")
    ),
    card(
      class = "sc-card",
      card_header("League Schedule Window"),
      responsive_table("league_schedule_table")
    )
  ),
  nav_panel(
    "Matchup",
    div(
      class = "section-stack",
      card(
        class = "sc-card",
        card_header("Head-to-Head Comparison"),
        plotOutput("matchup_compare_plot", height = "360px")
      ),
      card(
        class = "sc-card",
        card_header("Opponent Fingerprint"),
        responsive_table("opponent_profile_table")
      ),
      card(
        class = "sc-card",
        card_header("Your Availability Watch"),
        responsive_table("your_availability_table")
      ),
      card(
        class = "sc-card",
        card_header("Opponent Availability Watch"),
        responsive_table("opponent_availability_table")
      ),
      card(
        class = "sc-card",
        card_header("Opponent Trade Timeline"),
        plotOutput("opponent_trade_plot", height = "320px")
      ),
      card(
        class = "sc-card",
        card_header("NRL Club Exposure"),
        plotOutput("club_exposure_plot", height = "320px")
      )
    ),
  ),
  nav_panel(
    "Signals",
    div(
      class = "section-stack",
      card(
        class = "sc-card",
        card_header("Your Squad Leverage Watch"),
        responsive_table("your_signal_table")
      ),
      card(
        class = "sc-card",
        card_header("Next-Round Market Watchlist"),
        responsive_table("market_watch_table")
      ),
      card(
        class = "sc-card",
        card_header("Cash Generation Radar"),
        responsive_table("cash_watch_table")
      ),
      card(
        class = "sc-card",
        card_header("NRL Context Watch"),
        responsive_table("nrl_context_table")
      ),
      card(
        class = "sc-card",
        card_header("NRL Trend Radar"),
        plotOutput("team_performance_plot", height = "360px"),
        card_footer(class = "section-note", "Attacking trend lines for the NRL clubs most represented in this week's head-to-head.")
      )
    )
  ),
  nav_panel(
    "League",
    card(
      class = "sc-card",
      card_header("League Table"),
      responsive_table("league_snapshot_table")
    ),
    card(
      class = "sc-card",
      card_header("Refresh Log"),
      responsive_table("source_health_table")
    ),
    card(
      class = "sc-card",
      card_header("Coverage Gaps"),
      responsive_table("coverage_gap_table")
    )
  ),
  nav_panel(
    "Export",
    div(
      class = "action-bar",
      actionButton("build_prompt_pack", "Build GPT Pack", class = "btn-sc"),
      downloadButton("download_prompt_pack", "Download Latest GPT Pack", class = "btn-sc-outline")
    ),
    card(
      class = "sc-card",
      card_header("Export Status"),
      div(
        class = "card-body",
        textOutput("prompt_pack_status"),
        tags$div(class = "small text-muted mt-2", "This pack is meant for your custom GPT. The dashboard is for scanning, not final reasoning.")
      )
    ),
    card(
      class = "sc-card",
      card_header("Origin Watch"),
      responsive_table("origin_watch_table")
    ),
    card(
      class = "sc-card",
      card_header("Weekly Notes"),
      verbatimTextOutput("weekly_notes_text")
    ),
    card(
      class = "sc-card",
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
    showNotification("Dashboard refreshed from Drive/storage.", type = "message", duration = 4)
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
    showNotification("GPT pack rebuilt and synced.", type = "message", duration = 4)
  })

  dashboard_data <- reactive({
    refresh_nonce()
    load_dashboard_data()
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

  latest_ladder_round <- reactive({
    data <- dashboard_data()
    round_value <- snapshot_round()
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
    round_value <- snapshot_round()
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
    round_value <- snapshot_round()
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
    round_value <- snapshot_round()
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
        cash_generation_clean() %>%
          select(player_id, projected_price_signal_next_round, cumulative_cash_generation),
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
          coalesce(projected_price_signal_next_round, 0) / 15000 -
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
        cash_generation_clean() %>%
          select(player_id, projected_price_signal_next_round, cash_cow_maturity_status),
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
          coalesce(projected_price_signal_next_round, 0) / 15000 -
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
        price_signal = dollar(projected_price_signal_next_round),
        swing = schedule_swing_indicator,
        maturity = cash_cow_maturity_status
      ) %>%
      slice_head(n = 14)
  })

  cash_watch <- reactive({
    data <- dashboard_data()
    next_round_value <- next_round()

    req(!is.null(data$cash_generation), !is.null(data$players_cf_latest), !is.null(data$fixture_matchup))

    cash_generation_clean() %>%
      left_join(
        data$fixture_matchup %>%
          filter(round == next_round_value) %>%
          select(team_abbrev, next_opponent = opponent),
        by = "team_abbrev"
      ) %>%
      arrange(desc(projected_price_signal_next_round)) %>%
      transmute(
        player = full_name,
        team = team_abbrev,
        next_opponent,
        current_price = dollar(current_price),
        next_signal = dollar(projected_price_signal_next_round),
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

  output$current_round_text <- renderText({
    round_value <- current_round()

    if (is.na(round_value)) {
      return("NA")
    }

    settings_round <- round_state()$settings_current_round
    inference_source <- round_state()$round_inference_source

    if (!is.na(settings_round) && settings_round != round_value) {
      return(paste0("R", round_value, " (settings R", settings_round, ", ", inference_source %||% "inferred", ")"))
    }

    paste0("R", round_value)
  })

  output$snapshot_round_text <- renderText({
    round_value <- snapshot_round()
    if (is.na(round_value)) {
      return("Unavailable")
    }
    paste0("R", round_value)
  })

  output$snapshot_status_text <- renderText({
    live_round <- current_round()
    stored_round <- snapshot_round()

    if (is.na(live_round) && is.na(stored_round)) {
      return("No saved league snapshot is available yet.")
    }

    if (!is.na(live_round) && !is.na(stored_round) && live_round > stored_round) {
      return(paste0("Live round is R", live_round, " but your saved league snapshot is still R", stored_round, ". Run the refresh workflow once and the board will catch up."))
    }

    round_label <- if (!is.na(stored_round)) stored_round else live_round
    paste0("Live round and saved league snapshot are aligned at R", round_label, ".")
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
        `Price Signal` = dollar(projected_price_signal_next_round),
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
          filter(round == snapshot_round()) %>%
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

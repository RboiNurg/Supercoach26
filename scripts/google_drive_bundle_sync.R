drive_sync_is_configured <- function() {
  nzchar(Sys.getenv("SC_GDRIVE_FOLDER_ID")) &&
    (
      nzchar(Sys.getenv("GDRIVE_SERVICE_JSON_PATH")) ||
        nzchar(Sys.getenv("GDRIVE_SERVICE_JSON")) ||
        nzchar(Sys.getenv("GDRIVE_SERVICE_JSON_B64"))
    )
}

drive_required_packages_available <- function() {
  requireNamespace("googledrive", quietly = TRUE) &&
    requireNamespace("jsonlite", quietly = TRUE)
}

drive_bundle_name <- function(league_id) {
  paste0("supercoach_league_", league_id, "_data_bundle.zip")
}

drive_credentials_path <- local({
  cached_path <- NULL

  function() {
    if (!is.null(cached_path) && file.exists(cached_path)) {
      return(cached_path)
    }

    direct_path <- Sys.getenv("GDRIVE_SERVICE_JSON_PATH")

    if (nzchar(direct_path) && file.exists(direct_path)) {
      cached_path <<- direct_path
      return(cached_path)
    }

    raw_json <- Sys.getenv("GDRIVE_SERVICE_JSON")

    if (!nzchar(raw_json)) {
      b64_json <- Sys.getenv("GDRIVE_SERVICE_JSON_B64")

      if (nzchar(b64_json)) {
        raw_json <- rawToChar(jsonlite::base64_dec(b64_json))
      }
    }

    if (!nzchar(raw_json)) {
      stop("Google Drive sync is configured but no usable service account JSON was found.", call. = FALSE)
    }

    cached_path <<- tempfile("gdrive-service-", fileext = ".json")
    writeLines(raw_json, cached_path, useBytes = TRUE)
    cached_path
  }
})

ensure_drive_auth <- function() {
  if (!drive_sync_is_configured()) {
    return(FALSE)
  }

  if (!drive_required_packages_available()) {
    stop(
      "Google Drive sync requires packages `googledrive` and `jsonlite`.",
      call. = FALSE
    )
  }

  googledrive::drive_auth(
    path = drive_credentials_path(),
    cache = FALSE
  )

  TRUE
}

create_data_bundle <- function(data_dir, league_id) {
  dir.create(dirname(data_dir), recursive = TRUE, showWarnings = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

  bundle_path <- tempfile(
    pattern = paste0("supercoach_league_", league_id, "_"),
    fileext = ".zip"
  )

  parent_dir <- normalizePath(dirname(data_dir), mustWork = TRUE)
  bundle_root <- basename(normalizePath(data_dir, mustWork = TRUE))
  old_wd <- getwd()

  on.exit(setwd(old_wd), add = TRUE)

  setwd(parent_dir)
  utils::zip(bundle_path, files = bundle_root, flags = "-r9Xq")
  bundle_path
}

locate_drive_bundle <- function(league_id) {
  folder_id <- Sys.getenv("SC_GDRIVE_FOLDER_ID")
  bundle_name <- drive_bundle_name(league_id)

  files <- googledrive::drive_ls(googledrive::as_id(folder_id))
  files <- files[files$name %in% bundle_name, , drop = FALSE]

  if (nrow(files) == 0) {
    return(NULL)
  }

  files <- googledrive::drive_reveal(files, "modified_time")
  files[order(files$modified_time, decreasing = TRUE), , drop = FALSE][1, , drop = FALSE]
}

restore_data_bundle_from_drive <- function(data_dir, league_id) {
  if (!drive_sync_is_configured()) {
    message("Google Drive restore skipped: storage env vars are not configured.")
    return(FALSE)
  }

  ensure_drive_auth()
  bundle <- locate_drive_bundle(league_id)

  if (is.null(bundle)) {
    message("Google Drive restore skipped: no bundle found yet.")
    return(FALSE)
  }

  download_path <- tempfile(pattern = "supercoach-drive-restore-", fileext = ".zip")
  googledrive::drive_download(file = bundle, path = download_path, overwrite = TRUE)

  dir.create(dirname(data_dir), recursive = TRUE, showWarnings = FALSE)
  utils::unzip(download_path, exdir = dirname(data_dir))
  TRUE
}

upload_data_bundle_to_drive <- function(data_dir, league_id) {
  if (!drive_sync_is_configured()) {
    message("Google Drive upload skipped: storage env vars are not configured.")
    return(FALSE)
  }

  ensure_drive_auth()
  bundle_path <- create_data_bundle(data_dir, league_id)
  existing_bundle <- locate_drive_bundle(league_id)
  folder_id <- Sys.getenv("SC_GDRIVE_FOLDER_ID")
  bundle_name <- drive_bundle_name(league_id)

  if (is.null(existing_bundle)) {
    googledrive::drive_upload(
      media = bundle_path,
      path = googledrive::as_id(folder_id),
      name = bundle_name
    )
  } else {
    googledrive::drive_update(
      file = existing_bundle,
      media = bundle_path
    )
  }

  TRUE
}

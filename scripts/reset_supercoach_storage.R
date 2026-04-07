suppressPackageStartupMessages({
  library(fs)
})

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))
drive_sync_script <- "scripts/google_drive_bundle_sync.R"

preserve_paths <- c(
  file.path(data_dir, "manual_inputs")
)

copy_if_exists <- function(path, target_root) {
  if (!dir_exists(path) && !file_exists(path)) {
    return(invisible(FALSE))
  }

  rel_path <- path_rel(path, start = data_dir)
  dest_path <- path(target_root, rel_path)
  dir_create(path_dir(dest_path), recurse = TRUE)

  if (dir_exists(path)) {
    dir_copy(path, dest_path, overwrite = TRUE)
  } else {
    file_copy(path, dest_path, overwrite = TRUE)
  }

  invisible(TRUE)
}

delete_drive_bundle_if_configured <- function(league_id) {
  if (!file_exists(drive_sync_script)) {
    return(invisible(FALSE))
  }

  source(drive_sync_script, local = TRUE)

  if (!exists("drive_sync_is_configured", mode = "function") ||
      !drive_sync_is_configured()) {
    message("Drive bundle delete skipped: Drive sync is not configured in this environment.")
    return(invisible(FALSE))
  }

  ensure_drive_auth()
  bundle <- locate_drive_bundle(league_id)

  if (is.null(bundle) || nrow(bundle) == 0) {
    message("Drive bundle delete skipped: no remote bundle found.")
    return(invisible(FALSE))
  }

  googledrive::drive_rm(bundle)
  message("Deleted remote Drive bundle for league ", league_id, ".")
  invisible(TRUE)
}

message("Resetting generated SuperCoach storage for league ", league_id, "...")

preserve_root <- tempfile("supercoach-preserve-")
dir_create(preserve_root)

for (path in preserve_paths) {
  copy_if_exists(path, preserve_root)
}

if (dir_exists(data_dir)) {
  dir_delete(data_dir)
}

dir_create(data_dir, recurse = TRUE)

for (preserved_path in preserve_paths) {
  rel_path <- path_rel(preserved_path, start = data_dir)
  source_path <- path(preserve_root, rel_path)
  dest_path <- path(data_dir, rel_path)

  if (dir_exists(source_path)) {
    dir_copy(source_path, dest_path, overwrite = TRUE)
  } else if (file_exists(source_path)) {
    dir_create(path_dir(dest_path), recurse = TRUE)
    file_copy(source_path, dest_path, overwrite = TRUE)
  }
}

delete_drive_bundle_if_configured(league_id)

message("Local generated storage wiped.")
message("Preserved directories: ", paste(basename(preserve_paths), collapse = ", "))

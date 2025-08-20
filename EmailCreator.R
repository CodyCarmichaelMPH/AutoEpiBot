###############################################################################
# AutoEpi – Outlook sender via Microsoft Graph (no COM, no tenant mgmt)
#
# Requires from your pipeline:
#   • EmailStarterInfo.RData    -> email_df
#   • LogsFileLoc.RData         -> LogsFileLoc
#   • AutoEpi_Settings.RData    -> autoepi_settings
#   • [optional] Reports_Dir/individual_reports_metadata.RData
#       -> individual_reports_metadata (list with $file_path, etc.)
#
# Switches (priority: CLI > env > settings):
#   • Send enabled:
#       - CLI:  --off
#       - ENV:  AUTOEPI_SEND=0/1
#       - SET:  Email_Settings$SendEnabled (TRUE/FALSE, default TRUE)
#   • Display-only (create draft; don't send or update logs):
#       - CLI:  --display
#       - ENV:  AUTOEPI_DISPLAY_ONLY=1
#       - SET:  Email_Settings$DisplayOnly (TRUE/FALSE, default FALSE)
###############################################################################

## ────────────────────────────────────────────────────────────────────────────
## 0) Small utilities
## ────────────────────────────────────────────────────────────────────────────

`%||%` <- function(a,b) if (!is.null(a)) a else b

stop_if_missing <- function(path, hint=NULL){
  if (!file.exists(path)) stop(paste0("Missing file: ", path, if(!is.null(hint)) paste0("\n",hint)), call.=FALSE)
}

validate_emails <- function(vec){
  vec <- unique(trimws(vec))
  rx  <- "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
  ok  <- grepl(rx, vec)
  if (!all(ok)) stop("Invalid recipient(s): ", paste(vec[!ok], collapse=", "), call.=FALSE)
  vec
}

html_escape <- function(x){
  x <- ifelse(is.na(x), "", as.character(x))
  x <- gsub("&","&amp;",x,fixed=TRUE)
  x <- gsub("<","&lt;", x,fixed=TRUE)
  x <- gsub(">","&gt;", x,fixed=TRUE)
  x
}

df_to_html_table <- function(df, caption=NULL){
  if (is.null(df) || nrow(df)==0) return("<p><em>No data to display</em></p>")
  heads <- paste(sprintf(
    "<th style='padding:6px;text-align:left;border-bottom:1px solid #ddd'>%s</th>",
    html_escape(names(df))
  ), collapse="")
  rows  <- apply(df,1,function(r){
    cells <- paste(sprintf(
      "<td style='padding:6px;border-bottom:1px solid #f2f2f2'>%s</td>",
      html_escape(r)
    ), collapse="")
    paste0("<tr>", cells, "</tr>")
  })
  cap <- if (!is.null(caption)) sprintf(
    "<caption style='font-weight:bold;margin:4px 0 6px 0'>%s</caption>", html_escape(caption)
  ) else ""
  paste0(
    "<table style='border-collapse:collapse;margin:10px 0;font-family:Arial,sans-serif;font-size:12pt'>",
    cap, "<thead><tr>", heads, "</tr></thead>",
    "<tbody>", paste(rows, collapse=""), "</tbody></table>"
  )
}

## ────────────────────────────────────────────────────────────────────────────
## 1) Switches (CLI > env > settings)
## ────────────────────────────────────────────────────────────────────────────

parse_switches <- function(autoepi_settings){
  args <- commandArgs(trailingOnly=TRUE)
  
  send_enabled <- autoepi_settings$Email_Settings$SendEnabled %||% TRUE
  display_only <- autoepi_settings$Email_Settings$DisplayOnly %||% FALSE
  
  env_send <- Sys.getenv("AUTOEPI_SEND","")
  if (nzchar(env_send)) send_enabled <- as.integer(env_send)!=0
  
  env_disp <- Sys.getenv("AUTOEPI_DISPLAY_ONLY","")
  if (nzchar(env_disp)) display_only <- as.integer(env_disp)!=0
  
  if (length(args)) {
    if ("--off" %in% args)     send_enabled <- FALSE
    if ("--display" %in% args) display_only <- TRUE
  }
  
  list(send_enabled=send_enabled, display_only=display_only)
}

## ────────────────────────────────────────────────────────────────────────────
## 2) Microsoft Graph client (auto-detect signed-in account; no tenant arg)
## ────────────────────────────────────────────────────────────────────────────

get_outlook_client <- function(){
  if (!requireNamespace("Microsoft365R", quietly=TRUE))
    stop("Install Microsoft365R: install.packages('Microsoft365R')", call.=FALSE)
  # Auto-detects your cached token / signed-in context.
  Microsoft365R::get_business_outlook(
    scopes = c("Mail.ReadWrite","Mail.Send","offline_access")
  )
}

## ────────────────────────────────────────────────────────────────────────────
## 3) Main
## ────────────────────────────────────────────────────────────────────────────

main <- function(){
  message("AutoEpi Outlook (Graph) — starting")
  
  # Required artifacts
  stop_if_missing("EmailStarterInfo.RData", "Run TSCreate.R first.")
  stop_if_missing("LogsFileLoc.RData",      "Run LogsCreate.R first.")
  stop_if_missing("AutoEpi_Settings.RData", "Run GUI.R first.")
  
  load("EmailStarterInfo.RData")   # -> email_df
  load("LogsFileLoc.RData")        # -> LogsFileLoc
  load("AutoEpi_Settings.RData")   # -> autoepi_settings
  
  suppressPackageStartupMessages({ library(readr); library(dplyr); library(glue) })
  
  sw <- parse_switches(autoepi_settings)
  message("Switches: SendEnabled=", sw$send_enabled, " | DisplayOnly=", sw$display_only)
  
  # Read logs
  logs_date_fmt <- autoepi_settings$IO$LogsDateFormat %||% "%Y-%m-%d"
  stop_if_missing(LogsFileLoc, "Log file path came from LogsFileLoc.RData")
  readr::local_edition(1)
  logs_df <- readr::read_csv(
    LogsFileLoc,
    col_types = readr::cols(
      ObvsDate       = readr::col_date(format = logs_date_fmt),
      presented_name = readr::col_character(),
      AlertLevel     = readr::col_factor(levels = c("Normal","Warning","Alert","False Positive")),
      ReportCreated  = readr::col_factor(levels = c("no","yes")),
      ReportLocation = readr::col_character(),
      EmailSent      = readr::col_factor(levels = c("no","yes"))
    )
  )
  probs <- try(readr::problems(logs_df), silent=TRUE)
  if (!inherits(probs,"try-error") && nrow(probs)>0)
    warning("Parsing issues in logs (first rows):\n", utils::capture.output(print(utils::head(probs,5))), call.=FALSE)
  
  # Optional individual report metadata
  rpt_dir <- autoepi_settings$IO$Reports_Dir %||% getwd()
  indiv_meta_path <- file.path(rpt_dir, "individual_reports_metadata.RData")
  individual_reports <- list()
  if (file.exists(indiv_meta_path)) {
    load(indiv_meta_path)  # -> individual_reports_metadata
    individual_reports <- individual_reports_metadata
  }
  
  # Compose content
  syndrome_summary <- email_df %>%
    arrange(presented_name) %>%
    select(Syndrome = presented_name, `Start Date`=StartDate, `End Date`=EndDate)
  
  # Get all HTML reports from the rendered directory for today's date folder
  reports_dir <- autoepi_settings$IO$Reports_Dir
  today_folder <- format(Sys.Date(), "%Y-%m-%d")
  rendered_path <- file.path(reports_dir, "Rendered", today_folder)
  
  all_html_files <- character(0)
  if (dir.exists(rendered_path)) {
    # Get all subdirectories (date folders like 20201, 20305, etc.)
    subdirs <- list.dirs(rendered_path, full.names = TRUE, recursive = FALSE)
    for (subdir in subdirs) {
      if (dir.exists(subdir)) {
        # Get all HTML files in this subdirectory
        html_files <- list.files(subdir, pattern = "\\.html$", full.names = TRUE)
        all_html_files <- c(all_html_files, html_files)
      }
    }
  }
  
  # Create a comprehensive reports table
  reports_generated <- logs_df %>%
    filter(ReportCreated=="yes", 
           !is.na(ReportLocation), 
           nzchar(ReportLocation),
           grepl("\\.html$", ReportLocation)) %>%
    arrange(ObvsDate, presented_name) %>%
    select(Syndrome=presented_name, Date=ObvsDate, `Report Location`=ReportLocation)
  
  # Add any additional HTML files found in the rendered directory
  if (length(all_html_files) > 0) {
    # Extract syndrome and date from filename (format: YYYY-MM-DD__Syndrome__AutoEpi.html)
    additional_reports <- data.frame(
      `Report Location` = all_html_files,
      stringsAsFactors = FALSE
    )
    
    # Parse filename to extract date and syndrome
    additional_reports$filename <- basename(all_html_files)
    additional_reports$Date <- as.Date(sub("^([0-9]{4}-[0-9]{2}-[0-9]{2})__.*", "\\1", additional_reports$filename))
    additional_reports$Syndrome <- sub("^[0-9]{4}-[0-9]{2}-[0-9]{2}__(.*)__AutoEpi\\.html$", "\\1", additional_reports$filename)
    
    # Only include files that aren't already in the logs
    existing_paths <- reports_generated$`Report Location`
    additional_reports <- additional_reports[!additional_reports$`Report Location` %in% existing_paths, ]
    
    if (nrow(additional_reports) > 0) {
      additional_reports <- additional_reports %>%
        select(Syndrome, Date, `Report Location`) %>%
        arrange(Date, Syndrome)
      
      # Combine with existing reports
      reports_generated <- bind_rows(reports_generated, additional_reports) %>%
        arrange(Date, Syndrome)
    }
  }
  
  report_count <- nrow(reports_generated)
  
  today   <- format(Sys.Date(), "%Y-%m-%d")
  subject <- if (report_count==0)
    glue("AutoEpi Results for {today} - No Reports Generated")
  else
    glue("AutoEpi Results for {today} - {report_count} Report(s) Generated")
  
  body <- paste0(
    "<html><body style='font-family:Arial,sans-serif;line-height:1.5'>",
    "<h2 style='margin:0 0 10px 0'>AutoEpi Daily Summary</h2>",
    "<p>Today we examined the following syndromes over these dates:</p>",
    df_to_html_table(syndrome_summary),
    if (nrow(reports_generated)>0)
      paste0("<p>The following reports were generated:</p>", df_to_html_table(reports_generated))
    else
      "<p><strong>No reports were generated today.</strong> All examined syndromes were within normal parameters.</p>",
    sprintf("<p>View detailed logs at: <code>%s</code></p>", html_escape(LogsFileLoc)),
    "<hr style='margin:20px 0;border:none;border-top:1px solid #ddd'/>",
    "<p style='font-size:0.9em;color:#666'>This report was generated by AutoEpiBot.</p>",
    "</body></html>"
  )
  
  # Recipients
  to  <- validate_emails(autoepi_settings$Email_Settings$Recipients %||% character(0))
  if (!length(to)) stop("Email_Settings$Recipients is empty.", call.=FALSE)
  cc  <- autoepi_settings$Email_Settings$CC  %||% character(0);  if (length(cc))  cc  <- validate_emails(cc)
  bcc <- autoepi_settings$Email_Settings$BCC %||% character(0);  if (length(bcc)) bcc <- validate_emails(bcc)
  
  # Attachment paths that exist
  attachments <- character(0)
  if (length(individual_reports)) {
    attachments <- vapply(individual_reports, function(r) r$file_path %||% "", character(1))
    attachments <- attachments[nzchar(attachments) & file.exists(attachments)]
  }
  
  # Acquire Outlook (Graph) client — auto-detects your signed-in account
  outl <- get_outlook_client()
  
  if (!sw$send_enabled) {
    message("[DRY-RUN] Subject: ", subject)
    message("[DRY-RUN] To: ", paste(to, collapse=", "))
    if (length(attachments)) message("[DRY-RUN] Attachments: ", paste(basename(attachments), collapse=", "))
    message("Logs NOT updated (dry-run).")
    return(invisible(TRUE))
  }
  
  if (sw$display_only) {
    # Create a draft for manual review
    msg <- outl$create_email(
      body         = body,
      content_type = "html",
      subject      = subject,
      to           = to,
      cc           = if (length(cc))  cc  else NULL,
      bcc          = if (length(bcc)) bcc else NULL,
      send_now     = FALSE
    )
    if (length(attachments)) for (p in unique(attachments)) msg$add_attachment(p)
    message("Draft created in Outlook (Graph). Review/send manually.")
    message("Logs NOT updated (display-only).")
    return(invisible(TRUE))
  }
  
  # Send immediately (no draft kept): create -> attach -> send
  msg <- outl$create_email(
    body         = body,
    content_type = "html",
    subject      = subject,
    to           = to,
    cc           = if (length(cc))  cc  else NULL,
    bcc          = if (length(bcc)) bcc else NULL,
    send_now     = FALSE
  )
  if (length(attachments)) for (p in unique(attachments)) msg$add_attachment(p)
  msg$send()
  message("Email sent via Microsoft Graph.")
  
  # Update logs only on actual send
  today_syndromes <- unique(email_df$presented_name)
  logs_df <- logs_df %>%
    mutate(EmailSent = dplyr::if_else(
      presented_name %in% today_syndromes,
      factor("yes", levels=c("no","yes")),
      EmailSent
    ))
  readr::write_csv(logs_df, LogsFileLoc)
  message("Logs updated (EmailSent = yes) for ", length(today_syndromes), " syndromes")
  
  invisible(TRUE)
}

if (interactive()) main() else main()

# GUI.R — AutoEpi Settings (Desktop-friendly Shiny + native pickers)
# Requirements: shiny. (Optional: rstudioapi, tcltk)
# Run via: source("GUI.R"); main()
# If run interactively in R/RStudio, it will launch automatically.

suppressPackageStartupMessages({
  library(shiny)
})

# -------------------- constants / helpers --------------------

WA_COUNTIES <- c(
  "Adams","Asotin","Benton","Chelan","Clallam","Clark","Columbia","Cowlitz",
  "Douglas","Ferry","Franklin","Garfield","Grant","Grays Harbor","Island",
  "Jefferson","King","Kitsap","Kittitas","Klickitat","Lewis","Lincoln",
  "Mason","Okanogan","Pacific","Pend Oreille","Pierce","San Juan","Skagit",
  "Skamania","Snohomish","Spokane","Stevens","Thurston","Wahkiakum","Walla Walla",
  "Whatcom","Whitman","Yakima"
)

CLIMATE_STATIONS <- c(
  "pdt-eln" = "Ellensburg, Washington",
  "otx-lws" = "Lewiston, Idaho",
  "pdt-dls" = "Dallesport, Washington",
  "pdt-psc" = "Pasco, Washington",
  "sew-sew" = "Seattle, Washington",
  "otx-geg" = "Spokane, Washington",
  "pqr-vuo" = "Vancouver, Washington",
  "pdt-alw" = "Walla Walla, Washington",
  "otx-eat" = "Wenatchee, Washington",   # <-- fixed spelling
  "pdt-ykm" = "Yakima, Washington",
  "sew-olm" = "Olympia, Washington",
  "otx-omk" = "Omak, Washington",
  "sew-bli" = "Bellingham, Washington",
  "otx-dew" = "Deer Park, Washington"
)

`%||%` <- function(a,b) if (is.null(a)) b else a

# Normalize a path or return empty string
.norm_path <- function(p) {
  if (!nzchar(p)) return("")
  normalizePath(p, winslash = if (.Platform$OS.type == "windows") "\\" else "/", mustWork = FALSE)
}

# Robust, desktop-friendly directory picker
pick_dir <- function(caption = "Select folder", default = getwd()) {
  if (!dir.exists(default)) default <- getwd()
  p <- ""
  
  # 1) RStudio native (best UX if inside RStudio Desktop)
  try({
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      p0 <- rstudioapi::selectDirectory(caption = caption, path = default)
      if (!is.null(p0) && nzchar(p0)) p <- p0
    }
  }, silent = TRUE)
  
  # 2) tcltk (works on local desktops where available)
  if (!nzchar(p)) try({
    if (requireNamespace("tcltk", quietly = TRUE)) {
      p0 <- tcltk::tk_choose.dir(default = default, caption = caption)
      if (!is.na(p0) && nzchar(p0)) p <- p0
    }
  }, silent = TRUE)
  
  # 3) Windows-only chooser
  if (!nzchar(p) && .Platform$OS.type == "windows") try({
    p0 <- utils::choose.dir(default = default, caption = caption)
    if (!is.na(p0) && nzchar(p0)) p <- p0
  }, silent = TRUE)
  
  # 4) Last-ditch: pick a file, use its directory
  if (!nzchar(p)) try({
    f <- suppressWarnings(file.choose(new = FALSE))
    if (!is.na(f) && nzchar(f)) p <- dirname(f)
  }, silent = TRUE)
  
  .norm_path(p)
}

# Robust, desktop-friendly file picker
pick_file <- function(caption = "Select file", default = getwd(), filters = NULL) {
  if (!dir.exists(default)) default <- getwd()
  p <- ""
  
  # 1) RStudio native
  try({
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      p0 <- rstudioapi::selectFile(caption = caption, path = default, filter = filters %||% NULL)
      if (!is.null(p0) && nzchar(p0)) p <- p0
    }
  }, silent = TRUE)
  
  # 2) tcltk
  if (!nzchar(p)) try({
    if (requireNamespace("tcltk", quietly = TRUE)) {
      p0 <- tcltk::tk_choose.files(default = file.path(default, "*.*"),
                                   caption = caption, multi = FALSE)
      if (length(p0) > 0 && nzchar(p0[1])) p <- p0[1]
    }
  }, silent = TRUE)
  
  # 3) Cross-platform fallback
  if (!nzchar(p)) try({
    p0 <- suppressWarnings(file.choose(new = FALSE))
    if (!is.na(p0) && nzchar(p0)) p <- p0
  }, silent = TRUE)
  
  .norm_path(p)
}

# Build "&stationID=x&stationID=y"
compose_weather_param <- function(ids) {
  if (length(ids) == 0) return("")
  paste0(paste0("&stationID=", ids), collapse = "")
}

# Parse "0, 10, 25, 45, 65" => numeric cuts; final bin is last–120
parse_custom_ages <- function(txt) {
  txt <- gsub("\\s+", "", txt %||% "")
  if (nchar(txt) == 0) return(NULL)
  parts <- strsplit(txt, ",", fixed = TRUE)[[1]]
  nums <- suppressWarnings(as.numeric(parts))
  if (any(is.na(nums))) return(NULL)
  nums <- unique(sort(nums))
  if (length(nums) < 2) return(NULL)
  list(cuts = nums, final_upper = 120)
}

# Save format: "DDMonYY" e.g., "05Aug25"
format_start_date <- function(d) {
  if (is.null(d) || is.na(d)) return("")
  toupper_first <- function(x) paste0(toupper(substr(x,1,1)), tolower(substr(x,2,nchar(x))))
  paste0(format(d, "%d"), toupper_first(format(d, "%b")), format(d, "%y"))
}

# Always return a single string
collapse_value <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  paste(as.character(x), collapse = ", ")
}

safe_as_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  suppressWarnings(as.Date(x))
}

# Pointer file so we can auto-load last used settings next time
pointer_path <- function() file.path(getwd(), "AutoEpi_last_settings_path.txt")
write_last_path <- function(path) { if (nzchar(path)) try(cat(path, file = pointer_path(), sep = ""), silent = TRUE) }
read_last_path <- function() {
  pp <- pointer_path()
  if (file.exists(pp)) {
    ln <- tryCatch(readLines(pp, n = 1, warn = FALSE), error = function(e) "")
    if (length(ln) == 1 && nzchar(ln)) return(ln)
  }
  ""
}

# -------------------- UI --------------------

ui <- fluidPage(
  titlePanel("AutoEpi Settings"),
  tabsetPanel(
    tabPanel("README",
             h3("About This App"),
             p("This GUI is for creating or adjusting settings for AutoEpi."),
             p("You only need to run it if you want to make changes."),
             p("Once saved, AutoEpi will use these settings automatically."),
             p("Run via main() in R or double-click the file in RStudio.")
    ),
    tabPanel("Settings",
             sidebarLayout(
               sidebarPanel(width = 4,
                            h4("Credentials"),
                            textInput("ess_user", "ESSENCE Username", placeholder = "username01"),
                            passwordInput("ess_pass", "ESSENCE Password"),
                            tags$hr(),
                            
                            h4("Dates & Range"),
                            dateInput("start_date", "Start Date", value = Sys.Date(), format = "yyyy-mm-dd"),
                            numericInput("lookback", "Lookback Range (days)", value = 14, min = 0, step = 1),
                            tags$hr(),
                            
                            h4("Report Settings"),
                            checkboxInput("age_group_bar", "Age Group bar graph", TRUE),
                            conditionalPanel(
                              condition = "input.age_group_bar == true",
                              radioButtons("age_strat", "Age group stratification",
                                           choices = c(
                                             "(0-5, 6-18, 19-25, 25-34, 35-54, 55-64, 65+)" = "named",
                                             "by decade group" = "decade",
                                             "Custom (comma-separated bounds; last value start of final bin to 120)" = "custom"
                                           ),
                                           selected = "named"
                              ),
                              conditionalPanel(
                                condition = "input.age_strat == 'custom'",
                                textInput("custom_ages", "Custom bounds", placeholder = "0, 10, 25, 45, 65")
                              )
                            ),
                            checkboxInput("age_gender_bar", "Age Group + Gender stacked bar graph", TRUE),
                            checkboxInput("sex_only", "Sex only graph", TRUE),
                            checkboxInput("race_eth", "Race / Ethnicity graph", TRUE),
                            checkboxInput("hospital_bar", "Hospital bar graph", TRUE),
                            checkboxInput("age_per_10k", "Age per 10k graph", FALSE),
                            checkboxInput("sex_per_10k", "Sex per 10k graph", FALSE),
                            checkboxInput("hosp_per_10k", "Hospital per 10k graph", FALSE),
                            checkboxInput("choropleth", "Choropleth Map", FALSE),
                            
                            tags$hr(),
                            
                            h4("Climate"),
                            checkboxInput("include_climate", "Include Climate", FALSE),
                            conditionalPanel(
                              condition = "input.include_climate == true",
                              checkboxGroupInput("climate_stations", "Weather Stations",
                                                 choices = setNames(names(CLIMATE_STATIONS), CLIMATE_STATIONS)
                              ),
                              verbatimTextOutput("weather_param")
                            ),
                            
                            tags$hr(),
                            
                            h4("Air Quality"),
                            checkboxInput("include_aq", "Include Air Quality", FALSE),
                            conditionalPanel(
                              condition = "input.include_aq == true",
                              selectInput("aq_county", "County (Washington)", choices = WA_COUNTIES, selected = "King")
                            ),
                            
                            tags$hr(),
                            
                            h4("Key Folder Locations"),
                            fluidRow(
                              column(9, textInput("logs_dir", "Logs.csv folder", "")),
                              column(3, br(), actionButton("browse_logs", "Browse"))
                            ),
                            fluidRow(
                              column(9, textInput("reports_dir", "Reports folder", "")),
                              column(3, br(), actionButton("browse_reports", "Browse"))
                            ),
                            
                            h4("Syndrome List File"),
                            fluidRow(
                              column(9, textInput("syndrome_file", "Syndrome list file", "")),
                              column(3, br(), actionButton("browse_syndrome", "Browse"))
                            ),
                            
                            tags$hr(),
                            
                            h4("Save / Load Settings"),
                            fluidRow(
                              column(9, textInput("save_dir", "Save directory", "")),
                              column(3, br(), actionButton("browse_save_dir", "Browse"))
                            ),
                            textInput("save_name", "File name (without extension)", "AutoEpi_Settings"),
                            fluidRow(
                              column(6, actionButton("save_btn", "Save .RData")),
                              column(6, actionButton("load_btn", "Load Settings…"))
                            ),
                            br(),
                            verbatimTextOutput("save_status"),
                            verbatimTextOutput("loaded_from")
               ),
               mainPanel(width = 8,
                         h3("Preview"),
                         tableOutput("preview_table")
               )
             )
    )
  )
)

# -------------------- Server --------------------

server <- function(input, output, session) {
  
  # ---- Browse buttons (robust native pickers) ----
  observeEvent(input$browse_logs, {
    p <- pick_dir("Select Logs.csv folder", default = input$logs_dir %||% getwd())
    if (nzchar(p)) {
      updateTextInput(session, "logs_dir", value = p)
      showNotification(paste("Logs folder:", p), type = "message")
    } else {
      showNotification("Logs folder selection canceled.", type = "default")
    }
  })
  
  observeEvent(input$browse_reports, {
    p <- pick_dir("Select Reports folder", default = input$reports_dir %||% getwd())
    if (nzchar(p)) {
      updateTextInput(session, "reports_dir", value = p)
      showNotification(paste("Reports folder:", p), type = "message")
    } else {
      showNotification("Reports folder selection canceled.", type = "default")
    }
  })
  
  observeEvent(input$browse_syndrome, {
    base <- if (nzchar(input$syndrome_file)) dirname(input$syndrome_file) else getwd()
    p <- pick_file("Select syndrome list file", default = base)
    if (nzchar(p)) {
      updateTextInput(session, "syndrome_file", value = p)
      showNotification(paste("Syndrome file:", p), type = "message")
    } else {
      showNotification("Syndrome file selection canceled.", type = "default")
    }
  })
  
  observeEvent(input$browse_save_dir, {
    p <- pick_dir("Select save directory", default = input$save_dir %||% getwd())
    if (nzchar(p)) {
      updateTextInput(session, "save_dir", value = p)
      showNotification(paste("Save dir:", p), type = "message")
    } else {
      showNotification("Save directory selection canceled.", type = "default")
    }
  })
  
  # ---- Derived displays ----
  output$weather_param <- renderText({
    if (!isTRUE(input$include_climate)) return("")
    ids <- input$climate_stations %||% character(0)
    paste0("Weather_Stations: ", compose_weather_param(ids))
  })
  
  # ---- Build current settings (single source of truth) ----
  current_settings <- reactive({
    age_choice <- input$age_strat %||% "named"
    age_spec <- switch(age_choice,
                       "named"  = list(type = "named",
                                       groups = c("0-5","6-18","19-25","25-34","35-54","55-64","65+")),
                       "decade" = list(type = "decade"),
                       "custom" = {
                         parsed <- parse_custom_ages(input$custom_ages)
                         if (is.null(parsed)) list(type = "custom", error = "Invalid custom ages.") else
                           list(type = "custom", cuts = parsed$cuts, final_upper = parsed$final_upper)
                       }
    )
    
    list(
      Title = "AutoEpi Settings",
      Credentials = list(
        ESSENCE_Username = input$ess_user %||% "",
        ESSENCE_Password = input$ess_pass %||% ""
      ),
      Dates = list(
        StartDate_Display = as.character(input$start_date),
        StartDate_Saved   = format_start_date(safe_as_date(input$start_date)),
        Lookback_Days     = as.integer(input$lookback %||% 0)
      ),
      Report_Settings = list(
        Age_Group_Bar             = isTRUE(input$age_group_bar),
        Age_Group_Stratification  = age_spec,
        Age_Gender_Stacked_Bar    = isTRUE(input$age_gender_bar),
        Sex_Only_Graph            = isTRUE(input$sex_only),
        Race_Ethnicity_Graph      = isTRUE(input$race_eth),
        Hospital_Bar_Graph        = isTRUE(input$hospital_bar),
        Age_Per_10k_Graph         = isTRUE(input$age_per_10k),
        Sex_Per_10k_Graph         = isTRUE(input$sex_per_10k),
        Hospital_Per_10k_Graph    = isTRUE(input$hosp_per_10k),
        Choropleth_Map            = isTRUE(input$choropleth),
        Climate = list(
          Include           = isTRUE(input$include_climate),
          Weather_Stations  = if (isTRUE(input$include_climate))
            compose_weather_param(input$climate_stations) else "",
          Station_IDs       = if (isTRUE(input$include_climate))
            input$climate_stations else character(0)
        ),
        Air_Quality = if (isTRUE(input$include_aq))
          list(enabled = TRUE, county = input$aq_county)
        else list(enabled = FALSE),
        Time_to_Discharge_Analysis = FALSE
      ),
      IO = list(
        Logs_Dir            = input$logs_dir %||% "",
        Reports_Dir         = input$reports_dir %||% "",
        Syndrome_List_Path  = input$syndrome_file %||% ""
      ),
      Output = list(
        Save_Dir   = input$save_dir %||% "",
        Save_Name  = input$save_name %||% ""
      )
    )
  })
  
  # ---- Preview table ----
  output$preview_table <- renderTable({
    s <- current_settings()
    preview_list <- list(
      ESSENCE_Username    = s$Credentials$ESSENCE_Username,
      StartDate_Saved     = s$Dates$StartDate_Saved,
      Lookback_Days       = s$Dates$Lookback_Days,
      Weather_Stations    = s$Report_Settings$Climate$Weather_Stations,
      Logs_Dir            = s$IO$Logs_Dir,
      Reports_Dir         = s$IO$Reports_Dir,
      Syndrome_List_Path  = s$IO$Syndrome_List_Path,
      Save_Path           = file.path(s$Output$Save_Dir, paste0(s$Output$Save_Name, ".RData"))
    )
    data.frame(
      Field = names(preview_list),
      Value = vapply(preview_list, collapse_value, character(1)),
      stringsAsFactors = FALSE
    )
  })
  
  # ---- Save settings ----
  observeEvent(input$save_btn, {
    s <- current_settings()
    errs <- character(0)
    if (!nzchar(s$Output$Save_Dir))  errs <- c(errs, "Save directory is required.")
    if (!nzchar(s$Output$Save_Name)) errs <- c(errs, "Save file name is required.")
    
    out_path <- file.path(s$Output$Save_Dir, paste0(s$Output$Save_Name, ".RData"))
    s$Output$Save_Path <- out_path
    
    if (length(errs) > 0) {
      msg <- paste("ERROR:", paste(errs, collapse = "; "))
      output$save_status <- renderText(msg)
      showNotification(msg, type = "error")
      return()
    }
    
    autoepi_settings <- s
    ok <- tryCatch({
      dir.create(s$Output$Save_Dir, recursive = TRUE, showWarnings = FALSE)
      save(autoepi_settings, file = out_path)
      TRUE
    }, error = function(e) {
      output$save_status <- renderText(paste("ERROR saving file:", conditionMessage(e)))
      showNotification(paste("ERROR saving file:", conditionMessage(e)), type = "error")
      FALSE
    })
    
    if (ok) {
      output$save_status <- renderText(paste0("Saved: ", out_path, "\nObject: autoepi_settings"))
      showNotification(paste("Saved settings to", out_path), type = "message")
      write_last_path(out_path)
    }
  })
  
  # ---- Helper: apply loaded settings to UI (de-duplicated) ----
  apply_loaded_settings <- function(s) {
    updateTextInput(session, "ess_user", value = s$Credentials$ESSENCE_Username)
    # passwordInput shares text binding; updateTextInput works for it too
    updateTextInput(session, "ess_pass", value = s$Credentials$ESSENCE_Password)
    updateDateInput(session, "start_date", value = safe_as_date(s$Dates$StartDate_Display))
    updateNumericInput(session, "lookback", value = s$Dates$Lookback_Days)
    
    updateCheckboxInput(session, "age_group_bar", value = s$Report_Settings$Age_Group_Bar)
    
    sel_type <- s$Report_Settings$Age_Group_Stratification$type %||% "named"
    if (!sel_type %in% c("named", "decade", "custom")) sel_type <- "named"
    updateRadioButtons(session, "age_strat", selected = sel_type)
    if (identical(sel_type, "custom")) {
      ca <- s$Report_Settings$Age_Group_Stratification$cuts %||% NULL
      if (!is.null(ca)) updateTextInput(session, "custom_ages", value = paste(ca, collapse = ", "))
    }
    
    updateCheckboxInput(session, "age_gender_bar", value = s$Report_Settings$Age_Gender_Stacked_Bar)
    updateCheckboxInput(session, "sex_only", value = s$Report_Settings$Sex_Only_Graph)
    updateCheckboxInput(session, "race_eth", value = s$Report_Settings$Race_Ethnicity_Graph)
    updateCheckboxInput(session, "hospital_bar", value = s$Report_Settings$Hospital_Bar_Graph)
    updateCheckboxInput(session, "age_per_10k", value = s$Report_Settings$Age_Per_10k_Graph)
    updateCheckboxInput(session, "sex_per_10k", value = s$Report_Settings$Sex_Per_10k_Graph)
    updateCheckboxInput(session, "hosp_per_10k", value = s$Report_Settings$Hospital_Per_10k_Graph)
    updateCheckboxInput(session, "choropleth", value = s$Report_Settings$Choropleth_Map)
    
    updateCheckboxInput(session, "include_climate", value = s$Report_Settings$Climate$Include)
    updateCheckboxGroupInput(session, "climate_stations", selected = s$Report_Settings$Climate$Station_IDs)
    
    updateCheckboxInput(session, "include_aq", value = s$Report_Settings$Air_Quality$enabled)
    if (isTRUE(s$Report_Settings$Air_Quality$enabled)) {
      updateSelectInput(session, "aq_county", selected = s$Report_Settings$Air_Quality$county)
    }
    
    updateTextInput(session, "logs_dir", value = s$IO$Logs_Dir)
    updateTextInput(session, "reports_dir", value = s$IO$Reports_Dir)
    updateTextInput(session, "syndrome_file", value = s$IO$Syndrome_List_Path)
    
    updateTextInput(session, "save_dir", value = s$Output$Save_Dir)
    updateTextInput(session, "save_name", value = s$Output$Save_Name)
  }
  
  # ---- Load settings (button) ----
  observeEvent(input$load_btn, {
    p <- pick_file("Load AutoEpi settings (.RData)", default = input$save_dir %||% getwd())
    if (!nzchar(p)) {
      showNotification("Load canceled.", type = "default")
      return()
    }
    loaded <- tryCatch({
      e <- new.env()
      load(p, envir = e)
      if (!exists("autoepi_settings", envir = e)) stop("File does not contain 'autoepi_settings'.")
      e$autoepi_settings
    }, error = function(e) e)
    
    if (inherits(loaded, "error")) {
      showNotification(paste("Load failed:", loaded$message), type = "error")
      output$loaded_from <- renderText(paste("Load failed:", loaded$message))
      return()
    }
    
    apply_loaded_settings(loaded)
    output$loaded_from <- renderText(paste("Loaded from:", p))
    showNotification(paste("Loaded settings from", p), type = "message")
    write_last_path(p)
  })
  
  # ---- Auto-load last settings if pointer exists (once per session) ----
  observe({
    p <- read_last_path()
    if (!nzchar(p) || !file.exists(p)) return()
    if (isTRUE(session$userData$autoLoaded)) return()
    session$userData$autoLoaded <- TRUE
    
    loaded <- tryCatch({
      e <- new.env()
      load(p, envir = e)
      if (!exists("autoepi_settings", envir = e)) stop("File does not contain 'autoepi_settings'.")
      e$autoepi_settings
    }, error = function(e) e)
    
    if (inherits(loaded, "error")) {
      output$loaded_from <- renderText(paste("Auto-load failed:", loaded$message))
      return()
    }
    
    apply_loaded_settings(loaded)
    output$loaded_from <- renderText(paste("Auto-loaded from:", p))
  })
}

# -------------------- main --------------------

main <- function(...) {
  shinyApp(ui, server)
}

if (interactive() && identical(environment(), globalenv())) {
  main()
}

############################################################
##  AutoEpiBot - Package Installation Script
##  --------------------------------------------------------
##  Run this script on a new computer to install all 
##  required R packages for AutoEpiBot
############################################################

cat("=== AutoEpiBot Package Installation ===\n")

# List of required packages
required_packages <- c(
  # Core data manipulation and web
  "shiny",      # GUI interface
  "httr",       # HTTP requests to ESSENCE API
  "jsonlite",   # JSON parsing
  "dplyr",      # Data manipulation
  "readr",      # CSV reading/writing
  "tidyr",      # Data reshaping
  "stringr",    # String manipulation
  "purrr",      # Functional programming
  "glue",       # String interpolation
  
  # Visualization
  "plotly",     # Interactive plots
  "leaflet",    # Interactive maps
  
  # Spatial and mapping
  "sf",         # Spatial data handling
  "geojsonsf",  # GeoJSON processing
  
  # RMarkdown and reporting
  "rmarkdown",  # RMarkdown rendering
  "knitr",      # RMarkdown processing
  
  # File system operations
  "fs",         # File system operations
  
  # Email (Windows only)
  "RDCOMClient", # Outlook integration (Windows)
  "Microsoft365R" # Microsoft Graph API (alternative email)
)

# Function to install if not already installed
install_if_missing <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    cat("Installing", package, "...\n")
    install.packages(package)
    return(TRUE)
  } else {
    cat("✓", package, "already installed\n")
    return(FALSE)
  }
}

# Install missing packages
cat("\nChecking and installing required packages...\n")
newly_installed <- sapply(required_packages, install_if_missing)

# Special handling for RDCOMClient (Windows only)
if (.Platform$OS.type == "windows") {
  if ("RDCOMClient" %in% names(newly_installed) && newly_installed["RDCOMClient"]) {
    cat("\n📧 RDCOMClient installed for email functionality\n")
    cat("   Note: Requires Microsoft Outlook to be installed\n")
  }
} else {
  cat("\n⚠️  Email functionality (RDCOMClient) only available on Windows\n")
}

# Verify installations
cat("\n=== Verification ===\n")
all_loaded <- TRUE
for (pkg in required_packages) {
  if (.Platform$OS.type != "windows" && pkg == "RDCOMClient") {
    cat("⚠️  ", pkg, " (Windows only - skipped)\n")
    next
  }
  
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("✅ ", pkg, "\n")
  } else {
    cat("❌ ", pkg, " - Installation failed\n")
    all_loaded <- FALSE
  }
}

if (all_loaded) {
  cat("\n🎉 All packages successfully installed!\n")
  cat("You can now run: source('GUI.R') to start configuring AutoEpiBot\n")
} else {
  cat("\n⚠️  Some packages failed to install. Please check error messages above.\n")
}

cat("\n=== Next Steps ===\n")
cat("1. Run: source('GUI.R') to configure settings\n")
cat("2. Set up ESSENCE credentials in the GUI\n")
cat("3. Configure file paths for logs and reports\n")
cat("4. Run the workflow scripts in order\n")
cat("\nFor detailed instructions, see SETUP_INSTRUCTIONS.md\n")

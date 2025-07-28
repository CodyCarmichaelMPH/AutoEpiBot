#!/usr/bin/env Rscript
# AutoEpiBot Package Installation Script
# Installs all required R packages for the system

cat("AutoEpiBot Package Installation\n")
cat("===============================\n\n")

# List of required packages
required_packages <- c(
  "yaml",        # Configuration parsing
  "httr",        # HTTP requests
  "jsonlite",    # JSON parsing
  "dplyr",       # Data manipulation
  "lubridate",   # Date handling
  "rmarkdown",   # Report generation
  "blastula",    # Email sending
  "ggplot2",     # Chart creation
  "knitr",       # Report formatting
  "kableExtra"   # Table styling
)

# Function to install packages
install_packages <- function(packages) {
  cat("Installing required packages...\n")
  
  for (package in packages) {
    cat(sprintf("Installing %s... ", package))
    
    tryCatch({
      if (!require(package, character.only = TRUE, quietly = TRUE)) {
        install.packages(package, dependencies = TRUE, quiet = TRUE)
        cat("✓\n")
      } else {
        cat("already installed ✓\n")
      }
    }, error = function(e) {
      cat("✗ Error:", e$message, "\n")
    })
  }
}

# Function to verify installations
verify_packages <- function(packages) {
  cat("\nVerifying package installations...\n")
  
  missing_packages <- c()
  
  for (package in packages) {
    if (require(package, character.only = TRUE, quietly = TRUE)) {
      cat(sprintf("✓ %s\n", package))
    } else {
      cat(sprintf("✗ %s (missing)\n", package))
      missing_packages <- c(missing_packages, package)
    }
  }
  
  if (length(missing_packages) > 0) {
    cat(sprintf("\nWarning: %d packages could not be installed:\n", length(missing_packages)))
    cat(paste("  -", missing_packages), sep = "\n")
    cat("\nPlease install these packages manually:\n")
    cat("install.packages(c(", paste0('"', missing_packages, '"', collapse = ", "), "))\n")
    return(FALSE)
  } else {
    cat("\n✓ All packages installed successfully!\n")
    return(TRUE)
  }
}

# Function to test basic functionality
test_functionality <- function() {
  cat("\nTesting basic functionality...\n")
  
  # Test YAML parsing
  tryCatch({
    test_config <- list(
      api = list(username = "test", password = "test"),
      syndromes = list(list(name = "Test", ccddCategory = "test"))
    )
    yaml::as.yaml(test_config)
    cat("✓ YAML functionality\n")
  }, error = function(e) {
    cat("✗ YAML functionality failed\n")
  })
  
  # Test HTTP requests
  tryCatch({
    response <- httr::GET("https://httpbin.org/get", httr::timeout(5))
    if (httr::status_code(response) == 200) {
      cat("✓ HTTP functionality\n")
    } else {
      cat("✗ HTTP functionality failed\n")
    }
  }, error = function(e) {
    cat("✗ HTTP functionality failed\n")
  })
  
  # Test JSON parsing
  tryCatch({
    test_json <- '{"test": "data"}'
    parsed <- jsonlite::fromJSON(test_json)
    if (parsed$test == "data") {
      cat("✓ JSON functionality\n")
    } else {
      cat("✗ JSON functionality failed\n")
    }
  }, error = function(e) {
    cat("✗ JSON functionality failed\n")
  })
  
  # Test data manipulation
  tryCatch({
    test_df <- data.frame(x = 1:3, y = letters[1:3])
    result <- dplyr::filter(test_df, x > 1)
    if (nrow(result) == 2) {
      cat("✓ Data manipulation functionality\n")
    } else {
      cat("✗ Data manipulation functionality failed\n")
    }
  }, error = function(e) {
    cat("✗ Data manipulation functionality failed\n")
  })
  
  # Test date handling
  tryCatch({
    test_date <- lubridate::ymd("2025-01-01")
    if (lubridate::year(test_date) == 2025) {
      cat("✓ Date handling functionality\n")
    } else {
      cat("✗ Date handling functionality failed\n")
    }
  }, error = function(e) {
    cat("✗ Date handling functionality failed\n")
  })
}

# Main execution
main <- function() {
  cat("AutoEpiBot Package Installation Script\n")
  cat("=====================================\n\n")
  
  # Check R version
  cat("R Version:", R.version.string, "\n")
  cat("Platform:", R.version$platform, "\n\n")
  
  # Install packages
  install_packages(required_packages)
  
  # Verify installations
  success <- verify_packages(required_packages)
  
  if (success) {
    # Test functionality
    test_functionality()
    
    cat("\n==================================================\n")
    cat("Installation completed successfully!\n")
    cat("You can now run AutoEpiBot with:\n")
    cat("Rscript main.R --mode rolling\n")
    cat("==================================================\n")
  } else {
    cat("\n==================================================\n")
    cat("Installation completed with warnings.\n")
    cat("Please resolve missing packages before running AutoEpiBot.\n")
    cat("==================================================\n")
  }
}

# Run if executed directly
if (!interactive()) {
  main()
} 
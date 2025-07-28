#!/usr/bin/env Rscript
# Test configuration loading

library(yaml)

# Load configuration
config <- read_yaml("config.yaml")

# Test basic configuration
cat("=== AutoEpiBot Configuration Test ===\n")
cat("Mode:", config$mode, "\n")
cat("API Base URL:", config$api$base_url, "\n")
cat("Number of syndromes:", length(config$syndromes), "\n")

# Test syndrome configuration
cat("\nSyndromes:\n")
for (i in 1:length(config$syndromes)) {
  cat("  ", i, ".", config$syndromes[[i]]$name, "\n")
}

# Test email configuration
cat("\nEmail Configuration:\n")
cat("  Enabled:", config$email$enabled, "\n")
cat("  From:", config$email$from_address, "\n")
cat("  To:", paste(config$email$to_addresses, collapse = ", "), "\n")

# Test validation settings
cat("\nValidation Settings:\n")
cat("  Historical days:", config$validation$historical_days, "\n")
cat("  Min alert level:", config$validation$min_alert_level, "\n")
cat("  False positive threshold:", config$validation$false_positive_threshold, "\n")

cat("\n=== Configuration Test Complete ===\n") 
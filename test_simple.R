#!/usr/bin/env Rscript
# Simple test script to isolate the argument parsing issue

cat("Testing argument parsing...\n")

# Test 1: Basic argument parsing
args <- commandArgs(trailingOnly = TRUE)
cat("Arguments received:", paste(args, collapse = " "), "\n")
cat("Number of arguments:", length(args), "\n")

# Test 2: Parse arguments manually
config <- list(
  mode = "rolling",
  startDate = NULL,
  endDate = NULL,
  dry_run = FALSE
)

i <- 1
while (i <= length(args)) {
  arg <- args[i]
  cat("Processing argument:", arg, "\n")
  
  if (arg == "--mode") {
    if (i + 1 <= length(args)) {
      config$mode <- args[i + 1]
      cat("Set mode to:", config$mode, "\n")
      i <- i + 1
    }
  } else if (arg == "--dry-run") {
    config$dry_run <- TRUE
    cat("Set dry_run to TRUE\n")
  }
  i <- i + 1
}

cat("Final config:\n")
cat("  mode:", config$mode, "\n")
cat("  dry_run:", config$dry_run, "\n")

cat("Test completed successfully!\n") 
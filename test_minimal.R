#!/usr/bin/env Rscript
# Minimal test to isolate the error

cat("Starting minimal test...\n")

# Test 1: Load yaml
cat("Testing yaml loading...\n")
library(yaml)
config <- read_yaml("config.yaml")
cat("YAML loaded successfully\n")

# Test 2: Initialize logging
cat("Testing logging initialization...\n")
source("scripts/helpers/logging.R")
init_logging(config)
cat("Logging initialized successfully\n")

# Test 3: Test log functions
cat("Testing log functions...\n")
log_info("Test message")
cat("Log functions work\n")

cat("All tests passed!\n") 
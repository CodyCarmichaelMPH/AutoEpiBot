#!/usr/bin/env Rscript
# Simplified main.R for testing

cat("Starting simplified main.R...\n")

# Test 1: Load libraries
cat("Loading libraries...\n")
suppressPackageStartupMessages({
  library(yaml)
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(lubridate)
  library(rmarkdown)
  library(blastula)
  library(ggplot2)
  library(knitr)
})
cat("Libraries loaded successfully\n")

# Test 2: Parse arguments
cat("Parsing arguments...\n")
args <- commandArgs(trailingOnly = TRUE)
cat("Arguments:", paste(args, collapse = " "), "\n")
cat("Number of arguments:", length(args), "\n")

# Test 3: Load config
cat("Loading config...\n")
config <- read_yaml("config.yaml")
cat("Config loaded successfully\n")

# Test 4: Source logging
cat("Sourcing logging...\n")
source("scripts/helpers/logging.R")
cat("Logging sourced successfully\n")

# Test 5: Initialize logging
cat("Initializing logging...\n")
init_logging(config)
cat("Logging initialized successfully\n")

cat("Simplified main.R completed successfully!\n") 
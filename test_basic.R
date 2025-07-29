# Basic test without shebang
cat("Basic test starting...\n")

# Test command line arguments
args <- commandArgs(trailingOnly = TRUE)
cat("Arguments:", paste(args, collapse = " "), "\n")

# Test yaml loading
library(yaml)
cat("YAML library loaded\n")

# Test config loading
config <- read_yaml("config.yaml")
cat("Config loaded successfully\n")

cat("Basic test completed!\n") 
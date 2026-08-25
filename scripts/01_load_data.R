# 01_load_data.R
# Load the raw Venmo transaction CSV and do a first-pass inspection.
# Owner: Alexandra (Data Preparation & Network Construction)

library(readr)
library(dplyr)

# Adjust filename once you've downloaded + unzipped the dataset into data/raw/
venmo_raw <- read_csv("data/raw/venmo_transactions.csv")

# First look
glimpse(venmo_raw)
head(venmo_raw)
nrow(venmo_raw)

# TODO once columns are confirmed:
# - check for missing sender/recipient values
# - check timestamp format / range
# - confirm which fields are actually present (memo, emoji, audience setting, etc.)

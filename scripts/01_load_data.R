# 01_load_data.R
# Load the raw Venmo transaction CSV and do a first-pass inspection.
# Owner: Alexandra (Data Preparation & Network Construction)

library(readr)
library(dplyr)
library(data.table)

venmo_raw <- fread(
  "data/raw/venmo.csv",
  select = c(
    "payment.id",
    "payment.date_created",
    "payment.actor.username",
    "payment.actor.id",
    "payment.actor.date_joined",
    "payment.target.user.username",
    "payment.target.user.id",
    "payment.target.user.date_joined",
    "payment.note",
    "payment.audience",
    "payment.action"
  )
)

glimpse(venmo_raw)

venmo_clean <- venmo_raw %>%
  filter(
    !is.na(payment.actor.username), payment.actor.username != "",
    !is.na(payment.target.user.username), payment.target.user.username != "",
    payment.actor.username != payment.target.user.username
  ) %>%
  rename(
    sender = payment.actor.username,
    sender_id = payment.actor.id,
    sender_joined = payment.actor.date_joined,
    recipient = payment.target.user.username,
    recipient_id = payment.target.user.id,
    recipient_joined = payment.target.user.date_joined,
    timestamp = payment.date_created,
    memo = payment.note,
    audience = payment.audience,
    action = payment.action
  )

nrow(venmo_clean)
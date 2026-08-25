# 03_build_network.R
# Build the ERGM-ready network object: aggregate transactions into dyads,
# binarize ties, attach basic node attributes, and export.
# Owner: Alexandra (Data Preparation & Network Construction)

library(dplyr)
library(network)

# sampled_data <- ... (loaded from data/processed/)

# TODO:
# - aggregate transactions into dyads (sender, recipient, count)
# - decide tie threshold (e.g. 2+ transactions = tie)
# - decide directed vs undirected
# - build `network` object with set.vertex.attribute() for node attributes
# - save as outputs/network_object.RData for handoff to Yas'lyn / Yunai

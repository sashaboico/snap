# 02_sample_network.R
# Sample the full transaction data down to a feasible node set for ERGM
# (target: ~200-400 nodes). Strategy TBD: snowball sample from a seed set,
# a dense connected component, or a restricted time window.
# Owner: Alexandra (Data Preparation & Network Construction)

library(dplyr)
library(igraph)

# venmo_raw <- ... (loaded from 01_load_data.R)

# TODO:
# - pick sampling strategy (snowball / time window / component)
# - filter venmo_raw down to the sampled set of users
# - save intermediate result to data/processed/

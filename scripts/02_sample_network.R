# 02_sample_network.R
# Sample the full transaction data down to a feasible node set for ERGM
# (target: ~200-400 nodes). Strategy TBD: snowball sample from a seed set,
# a dense connected component, or a restricted time window.
# Owner: Alexandra (Data Preparation & Network Construction)

library(dplyr)
library(igraph)

# Aggregate to unique dyads with transaction counts (we need this for the network anyway)
edge_list <- venmo_clean %>%
  count(sender, recipient, name = "n_transactions")

nrow(edge_list)  # how many unique sender-recipient pairs exist

# Build the full graph
g_full <- graph_from_data_frame(edge_list, directed = TRUE)

# Find connected components (treating ties as undirected for this check)
comp <- components(as.undirected(g_full))
comp_sizes <- sort(table(comp$membership), decreasing = TRUE)
head(comp_sizes, 10)

giant_comp_id <- names(comp_sizes)[1]  # "1" in your output
giant_nodes <- names(comp$membership[comp$membership == giant_comp_id])

length(giant_nodes)

seed_user <- "Nick-Zeng"

sampled_ids <- ego(g_undirected, order = 2, nodes = seed_user)[[1]]
sampled_nodes <- names(sampled_ids)
length(sampled_nodes)

# Filter the full edge list down to just our sampled nodes
venmo_sample <- venmo_clean %>%
  filter(sender %in% sampled_nodes, recipient %in% sampled_nodes)

nrow(venmo_sample)          # transactions within our sample
n_distinct(c(venmo_sample$sender, venmo_sample$recipient))  # should be <= 206
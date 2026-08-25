# 03_build_network.R
# Build the ERGM-ready network object: aggregate transactions into dyads,
# binarize ties, attach basic node attributes, and export.
# Owner: Alexandra (Data Preparation & Network Construction)

library(dplyr)
library(network)

# Aggregate into dyads with transaction counts
dyads <- venmo_sample %>%
  count(sender, recipient, name = "n_transactions")

# Check the distribution before picking a threshold
table(dyads$n_transactions)

# Every dyad becomes a tie; keep transaction count as an edge attribute
edge_list_final <- dyads  # sender, recipient, n_transactions — already what we need

nrow(edge_list_final)  # should be 289

library(network)

net <- network(
  edge_list_final[, c("sender", "recipient")],
  matrix.type = "edgelist",
  directed = TRUE  # preserves who paid whom; can be symmetrized later if needed
)

# Attach transaction count as an edge attribute
set.edge.attribute(net, "n_transactions", edge_list_final$n_transactions)

net  # quick summary

# Get each node's earliest known account join date, whichever role they appeared in
node_attrs <- venmo_sample %>%
  select(user = sender, joined = sender_joined) %>%
  bind_rows(venmo_sample %>% select(user = recipient, joined = recipient_joined)) %>%
  distinct(user, .keep_all = TRUE)

# Make sure node_attrs is in the SAME order as network()'s vertex names
vertex_order <- network.vertex.names(net)
node_attrs <- node_attrs[match(vertex_order, node_attrs$user), ]

# Sanity check — this should be TRUE
all(node_attrs$user == vertex_order)


# Attach account join date as a node attribute
set.vertex.attribute(net, "date_joined", as.character(node_attrs$joined))

# Also attach degree (how many people each node transacted with) — useful for Yas'lyn/Yunai
deg_in_sample <- sna::degree(net, gmode = "digraph")
set.vertex.attribute(net, "degree", deg_in_sample)

net  # confirm attributes attached


save(net, file = "outputs/network_object.RData")
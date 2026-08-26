# 04_descriptive_ergm_analysis.R
# Prepare ERGM and descriptive relationship measures from the existing
# ERGM-ready network object. This script reads outputs/network_object.RData
# only; it does not modify data preparation, sampling, or network construction.

suppressPackageStartupMessages({
  library(network)
  library(sna)
  library(igraph)
  library(ergm)
  library(ggplot2)
})

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

safe_dir_create <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
}

write_text <- function(path, lines) {
  writeLines(as.character(lines), con = path, useBytes = TRUE)
}

capture_text <- function(path, expr) {
  lines <- capture.output(expr)
  write_text(path, lines)
  invisible(lines)
}

skewness_simple <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 3 || stats::sd(x) == 0) {
    return(0)
  }
  mean(((x - mean(x)) / stats::sd(x))^3)
}

edge_matrix_from_network <- function(net) {
  edge_mat <- as.matrix(net, matrix.type = "edgelist")
  if (is.null(dim(edge_mat)) || nrow(edge_mat) == 0) {
    return(data.frame(tail = integer(), head = integer()))
  }

  edge_mat <- as.data.frame(edge_mat[, 1:2, drop = FALSE], stringsAsFactors = FALSE)
  names(edge_mat) <- c("tail", "head")
  vertex_names <- network::network.vertex.names(net)

  tail_id <- suppressWarnings(as.integer(edge_mat$tail))
  head_id <- suppressWarnings(as.integer(edge_mat$head))

  if (anyNA(tail_id) || anyNA(head_id)) {
    tail_id <- match(as.character(edge_mat$tail), vertex_names)
    head_id <- match(as.character(edge_mat$head), vertex_names)
  }

  if (anyNA(tail_id) || anyNA(head_id)) {
    stop("Could not map edge endpoints to vertex ids.")
  }

  data.frame(tail = tail_id, head = head_id)
}

coef_table_from_fit <- function(fit, model_name) {
  coef_mat <- tryCatch(coef(summary(fit)), error = function(e) NULL)
  if (is.null(coef_mat)) {
    return(data.frame(
      model = model_name,
      term = names(stats::coef(fit)),
      estimate = as.numeric(stats::coef(fit)),
      std_error = NA_real_,
      p_value = NA_real_,
      odds_ratio = exp(as.numeric(stats::coef(fit)))
    ))
  }

  estimate_col <- grep("Estimate", colnames(coef_mat), value = TRUE)[1]
  se_col <- grep("Std", colnames(coef_mat), value = TRUE)[1]
  p_col <- grep("^Pr|p-value", colnames(coef_mat), value = TRUE)[1]

  data.frame(
    model = model_name,
    term = rownames(coef_mat),
    estimate = as.numeric(coef_mat[, estimate_col]),
    std_error = if (!is.na(se_col)) as.numeric(coef_mat[, se_col]) else NA_real_,
    p_value = if (!is.na(p_col)) as.numeric(coef_mat[, p_col]) else NA_real_,
    odds_ratio = exp(as.numeric(coef_mat[, estimate_col])),
    row.names = NULL
  )
}

fit_ergm_safe <- function(model_name, formula, out_dir) {
  message("Fitting ", model_name, " ...")
  warning_messages <- character()
  fit <- tryCatch(
    withCallingHandlers({
      set.seed(108)
      ergm(
        formula,
        estimate = "MPLE",
        control = control.ergm(
          MPLE.samplesize = 50000
        )
      )
    }, warning = function(w) {
      warning_messages <<- unique(c(warning_messages, conditionMessage(w)))
      invokeRestart("muffleWarning")
    }),
    error = function(e) e
  )

  if (inherits(fit, "error")) {
    failure <- data.frame(
      model = model_name,
      status = "failed",
      message = conditionMessage(fit),
      stringsAsFactors = FALSE
    )
    write.csv(failure, file.path(out_dir, paste0(model_name, "_status.csv")), row.names = FALSE)
    return(list(status = failure, coefficients = data.frame()))
  }

  saveRDS(fit, file.path(out_dir, paste0(model_name, ".rds")))
  capture_text(file.path(out_dir, paste0(model_name, "_summary.txt")), summary(fit))

  status <- data.frame(
    model = model_name,
    status = "fit",
    message = paste(
      "Fit with MPLE for preparation and screening; use MCMLE for final inferential claims.",
      if (length(warning_messages) > 0) {
        paste("Warnings suppressed during fit:", length(warning_messages), "unique warning type(s).")
      } else {
        "No warnings."
      }
    ),
    stringsAsFactors = FALSE
  )
  write.csv(status, file.path(out_dir, paste0(model_name, "_status.csv")), row.names = FALSE)
  list(status = status, coefficients = coef_table_from_fit(fit, model_name), fit = fit)
}

run_snap_analysis <- function(repo_root = ".", fit_models = TRUE) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  out_dir <- file.path(repo_root, "outputs", "analysis")
  fig_dir <- file.path(out_dir, "figures")
  safe_dir_create(out_dir)
  safe_dir_create(fig_dir)

  network_path <- file.path(repo_root, "outputs", "network_object.RData")
  if (!file.exists(network_path)) {
    stop("Expected network object not found: ", network_path)
  }

  loaded_names <- load(network_path)
  if (!"net" %in% loaded_names || !exists("net")) {
    stop("network_object.RData must contain an object named net.")
  }
  if (!inherits(net, "network")) {
    stop("Object net is not a network package network object.")
  }

  n_nodes <- network::network.size(net)
  n_edges <- network::network.edgecount(net)
  is_directed <- isTRUE(network::get.network.attribute(net, "directed"))
  if (n_nodes <= 0 || n_edges <= 0) {
    stop("Network must have positive node and edge counts.")
  }

  edge_df <- edge_matrix_from_network(net)
  network::set.vertex.attribute(net, "vertex.names", paste0("v", seq_len(n_nodes)))
  edge_counts <- network::get.edge.attribute(net, "n_transactions")
  if (is.null(edge_counts)) {
    edge_counts <- rep(1, nrow(edge_df))
  }
  edge_counts <- suppressWarnings(as.numeric(edge_counts))
  edge_counts[is.na(edge_counts)] <- 1
  edge_df$n_transactions <- edge_counts[seq_len(nrow(edge_df))]

  adj <- matrix(FALSE, nrow = n_nodes, ncol = n_nodes)
  adj[cbind(edge_df$tail, edge_df$head)] <- TRUE
  diag(adj) <- FALSE

  out_degree <- rowSums(adj)
  in_degree <- colSums(adj)
  total_degree <- rowSums(adj | t(adj))
  sym_adj <- adj | t(adj)
  common_neighbors <- sym_adj %*% sym_adj

  edge_df$reciprocated <- adj[cbind(edge_df$head, edge_df$tail)]
  edge_df$common_neighbors <- as.numeric(common_neighbors[cbind(edge_df$tail, edge_df$head)])
  frequency_cutoff <- max(2, as.numeric(stats::quantile(edge_df$n_transactions, 0.75, names = FALSE)))
  embedded_positive <- edge_df$common_neighbors[edge_df$common_neighbors > 0]
  embedded_cutoff <- if (length(embedded_positive) > 0) {
    max(1, as.numeric(stats::median(embedded_positive)))
  } else {
    1
  }
  edge_df$high_frequency <- edge_df$n_transactions >= frequency_cutoff
  edge_df$embedded <- edge_df$common_neighbors >= embedded_cutoff
  edge_df$relationship_strength_score <-
    as.integer(edge_df$high_frequency) +
    as.integer(edge_df$reciprocated) +
    as.integer(edge_df$common_neighbors > 0)
  edge_df$relationship_strength_proxy <- edge_df$relationship_strength_score >= 2

  analysis_net <- network::network.initialize(n_nodes, directed = is_directed)
  network::set.vertex.attribute(analysis_net, "vertex.names", paste0("v", seq_len(n_nodes)))
  network::add.edges(analysis_net, tail = edge_df$tail, head = edge_df$head)
  network::set.edge.attribute(analysis_net, "n_transactions", edge_df$n_transactions)

  g_dir <- graph_from_data_frame(
    edge_df[, c("tail", "head")],
    directed = is_directed,
    vertices = data.frame(name = seq_len(n_nodes))
  )
  g_undir <- igraph::as_undirected(g_dir, mode = "collapse")
  weak_components <- components(g_undir)
  giant_size <- max(weak_components$csize)
  density_directed <- if (is_directed) n_edges / (n_nodes * (n_nodes - 1)) else
    (2 * n_edges) / (n_nodes * (n_nodes - 1))
  mutual_edges <- sum(edge_df$reciprocated)
  mutual_dyads <- mutual_edges / 2

  network_summary <- data.frame(
    metric = c(
      "nodes",
      "directed_edges",
      "density",
      "reciprocated_directed_edges",
      "mutual_dyads",
      "reciprocity_edge_share",
      "weak_components",
      "largest_weak_component_nodes",
      "isolates_weak_degree_zero",
      "mean_in_degree",
      "mean_out_degree",
      "max_in_degree",
      "max_out_degree",
      "degree_skew_total",
      "global_transitivity_undirected",
      "frequency_cutoff_high_tie",
      "embedded_cutoff_common_neighbors"
    ),
    value = c(
      n_nodes,
      n_edges,
      density_directed,
      mutual_edges,
      mutual_dyads,
      mutual_edges / n_edges,
      length(weak_components$csize),
      giant_size,
      sum(total_degree == 0),
      mean(in_degree),
      mean(out_degree),
      max(in_degree),
      max(out_degree),
      skewness_simple(total_degree),
      transitivity(g_undir, type = "global", isolates = "zero"),
      frequency_cutoff,
      embedded_cutoff
    )
  )

  attribute_summary <- data.frame(
    attribute_type = c(rep("vertex", length(network::list.vertex.attributes(net))), rep("edge", length(network::list.edge.attributes(net)))),
    attribute = c(network::list.vertex.attributes(net), network::list.edge.attributes(net)),
    stringsAsFactors = FALSE
  )

  node_summary <- data.frame(
    anon_node_id = seq_len(n_nodes),
    in_degree = as.numeric(in_degree),
    out_degree = as.numeric(out_degree),
    total_weak_degree = as.numeric(total_degree),
    date_joined_present = !is.na(network::get.vertex.attribute(net, "date_joined")),
    stringsAsFactors = FALSE
  )

  degree_values <- function(x) {
    qs <- stats::quantile(x, probs = c(0, .25, .5, .75, 1), names = FALSE)
    as.numeric(c(qs[1], qs[2], qs[3], mean(x), qs[4], qs[5]))
  }
  degree_summary <- data.frame(
    statistic = c("min", "p25", "median", "mean", "p75", "max"),
    in_degree = degree_values(in_degree),
    out_degree = degree_values(out_degree),
    total_weak_degree = degree_values(total_degree)
  )

  relationship_summary <- data.frame(
    measure = c(
      "high_frequency_ties",
      "reciprocated_ties",
      "embedded_ties",
      "relationship_strength_proxy_ties"
    ),
    rule = c(
      paste0("n_transactions >= ", frequency_cutoff),
      "edge has a reverse-direction partner",
      paste0("common_neighbors >= ", embedded_cutoff),
      "at least two of high-frequency, reciprocated, embedded"
    ),
    tie_count = c(
      sum(edge_df$high_frequency),
      sum(edge_df$reciprocated),
      sum(edge_df$embedded),
      sum(edge_df$relationship_strength_proxy)
    ),
    edge_share = c(
      mean(edge_df$high_frequency),
      mean(edge_df$reciprocated),
      mean(edge_df$embedded),
      mean(edge_df$relationship_strength_proxy)
    )
  )

  edge_export <- edge_df
  names(edge_export)[1:2] <- c("tail_anon_id", "head_anon_id")

  write.csv(network_summary, file.path(out_dir, "network_summary.csv"), row.names = FALSE)
  write.csv(attribute_summary, file.path(out_dir, "attribute_summary.csv"), row.names = FALSE)
  write.csv(node_summary, file.path(out_dir, "node_summary_anonymized.csv"), row.names = FALSE)
  write.csv(degree_summary, file.path(out_dir, "degree_summary.csv"), row.names = FALSE)
  write.csv(relationship_summary, file.path(out_dir, "relationship_proxy_summary.csv"), row.names = FALSE)
  write.csv(edge_export, file.path(out_dir, "edge_relationship_measures_anonymized.csv"), row.names = FALSE)

  p_degree <- ggplot(node_summary, aes(x = total_weak_degree)) +
    geom_histogram(binwidth = 1, fill = "#356859", color = "white", boundary = -0.5) +
    labs(x = "Weak degree", y = "Number of nodes", title = "Degree distribution") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "degree_distribution.png"), p_degree, width = 7, height = 4.5, dpi = 180)

  p_transactions <- ggplot(edge_export, aes(x = n_transactions)) +
    geom_histogram(binwidth = 1, fill = "#C67C4E", color = "white", boundary = 0.5) +
    scale_x_continuous(breaks = scales::pretty_breaks()) +
    labs(x = "Transactions per directed dyad", y = "Number of directed dyads", title = "Tie frequency distribution") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "transaction_count_distribution.png"), p_transactions, width = 7, height = 4.5, dpi = 180)

  relationship_plot_df <- relationship_summary
  relationship_plot_df$label <- c(
    "High-frequency ties",
    "Reciprocated ties",
    "Embedded ties",
    "Combined proxy ties"
  )
  relationship_plot_df$label <- factor(
    relationship_plot_df$label,
    levels = relationship_plot_df$label
  )
  p_relationship <- ggplot(relationship_plot_df, aes(x = label, y = edge_share)) +
    geom_col(fill = "#5B6C9D", width = 0.68) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    coord_flip() +
    labs(x = NULL, y = "Share of directed edges", title = "Relationship-strength proxy prevalence") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "relationship_proxy_prevalence.png"), p_relationship, width = 7, height = 4.5, dpi = 180)

  model_status <- data.frame()
  model_coefficients <- data.frame()
  fit_results <- list()

  if (fit_models) {
    model_specs <- list(
      m1_edges = analysis_net ~ edges,
      m2_edges_mutual = analysis_net ~ edges + mutual,
      m3_degree = analysis_net ~ edges + mutual + gwidegree(0.5, fixed = TRUE) + gwodegree(0.5, fixed = TRUE),
      m4_closure = analysis_net ~ edges + mutual + gwidegree(0.5, fixed = TRUE) + gwodegree(0.5, fixed = TRUE) + gwesp(0.5, fixed = TRUE)
    )

    for (model_name in names(model_specs)) {
      result <- fit_ergm_safe(model_name, model_specs[[model_name]], out_dir)
      fit_results[[model_name]] <- result
      model_status <- rbind(model_status, result$status)
      if (nrow(result$coefficients) > 0) {
        model_coefficients <- rbind(model_coefficients, result$coefficients)
      }
    }

    write.csv(model_status, file.path(out_dir, "ergm_model_status.csv"), row.names = FALSE)
    write.csv(model_coefficients, file.path(out_dir, "ergm_coefficients.csv"), row.names = FALSE)

    successful_names <- names(fit_results)[vapply(fit_results, function(x) !is.null(x$fit), logical(1))]
    if (length(successful_names) > 0) {
      best_name <- tail(successful_names, 1)
      best_fit <- fit_results[[best_name]]$fit
      capture_text(file.path(out_dir, paste0(best_name, "_diagnostics_note.txt")), {
        cat("Diagnostics note\n")
        cat("Models are fit with MPLE for preparation/screening in this assignment pass.\n")
        cat("For final inferential claims, refit preferred specifications with MCMLE,\n")
        cat("then run mcmc.diagnostics() and gof() with adequate simulation size.\n")
      })
      gof_result <- tryCatch(
        gof(best_fit, GOF = ~ idegree + odegree + distance, control = control.gof.ergm(nsim = 20)),
        error = function(e) e
      )
      if (inherits(gof_result, "error")) {
        write_text(
          file.path(out_dir, paste0(best_name, "_gof_status.txt")),
          c("GOF failed for screening fit:", conditionMessage(gof_result))
        )
      } else {
        saveRDS(gof_result, file.path(out_dir, paste0(best_name, "_gof.rds")))
        png(file.path(fig_dir, paste0(best_name, "_gof.png")), width = 1200, height = 900, res = 160)
        plot(gof_result)
        dev.off()
      }
    }
  }

  session_lines <- capture.output(sessionInfo())
  write_text(file.path(out_dir, "session_info.txt"), session_lines)

  invisible(list(
    network_summary = network_summary,
    attribute_summary = attribute_summary,
    degree_summary = degree_summary,
    relationship_summary = relationship_summary,
    model_status = model_status,
    model_coefficients = model_coefficients,
    output_dir = out_dir
  ))
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- if (length(args) >= 1) args[[1]] else "."
  fit_models <- !("--no-models" %in% args)
  result <- run_snap_analysis(repo_root = repo_root, fit_models = fit_models)
  message("Analysis outputs written to: ", result$output_dir)
}

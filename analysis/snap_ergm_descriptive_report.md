# ERGM Preparation and Descriptive Relationship Measures

This report prepares the **Inferential Modeling & Analysis (ERGM)** and **Relationship Measures & Descriptive Analysis** part of the SNAP Track 1 Venmo project. It uses the GitHub repo's existing `outputs/network_object.RData` as the only data input.

The current work deliberately does **not** modify raw data, sampling, or network construction. The upstream data and network logic remain owned by the earlier pipeline scripts.

## Scope and Interpretation

The proposal's broader intuition is that public Venmo transactions may leak private relationship information through network position and neighbors' activity. For this assignment pass, the scope is narrower:

- Use the existing ERGM-ready directed network.
- Prepare descriptive network measures and relationship-strength proxies.
- Fit and document staged ERGM screening models.
- Exclude ALAAM, SAOM, REM, raw-data recoding, and new network construction.

Because the committed network object does not include raw memo text, emoji, timestamps, or audience fields, this analysis cannot directly label romantic relationship status. Instead, it uses **structural and behavioral proxies** for relationship strength: repeated transactions, reciprocity, and shared-neighbor embeddedness. These proxies support a privacy-risk argument, but they are not ground-truth relationship labels.

## Existing Network

The existing network object is directed and contains 206 nodes and 289 directed edges. It is a tractable ERGM dataset, satisfying the course requirement that the analysis not try to model the full 7M-transaction graph directly.

Key descriptive results from `outputs/analysis/network_summary.csv`:

| Measure | Value |
|---|---:|
| Nodes | 206 |
| Directed edges | 289 |
| Density | 0.0068 |
| Reciprocated directed edges | 48 |
| Mutual dyads | 24 |
| Reciprocity edge share | 16.6% |
| Weak components | 1 |
| Largest weak component | 206 nodes |
| Global transitivity, undirected projection | 0.0522 |
| Maximum in-degree | 64 |
| Maximum out-degree | 11 |

The network is sparse but connected in weak-component terms. The in-degree distribution is highly skewed, which matters for ERGM specification because simple edge and triangle terms alone are likely to underfit degree heterogeneity.

![Degree distribution](../outputs/analysis/figures/degree_distribution.png)

## Relationship Measures

The relationship-strength proxy is designed to stay faithful to what is actually present in `network_object.RData`.

| Proxy | Rule | Count | Share of directed edges |
|---|---|---:|---:|
| High-frequency ties | `n_transactions >= 2` | 50 | 17.3% |
| Reciprocated ties | Reverse-direction edge exists | 48 | 16.6% |
| Embedded ties | At least 1 common neighbor | 122 | 42.2% |
| Relationship-strength proxy ties | At least two of high-frequency, reciprocated, embedded | 60 | 20.8% |

Logic:

- **Frequency** captures repeated interaction rather than one-off payments.
- **Reciprocity** captures two-sided exchange, which is closer to an ongoing relationship than a single directional payment.
- **Embeddedness** captures whether a dyad is situated in a local social neighborhood.
- The combined proxy avoids overclaiming from any single signal by requiring at least two forms of evidence.

These measures are descriptive; they are not used as endogenous predictors in the ERGM because they are computed from the same observed network being modeled.

![Tie frequency distribution](../outputs/analysis/figures/transaction_count_distribution.png)

![Relationship proxy prevalence](../outputs/analysis/figures/relationship_proxy_prevalence.png)

## ERGM Specification Logic

The ERGM setup follows the lecture's MTML framing: the observed network is the dependent variable, and model terms represent hypothesized network-generating mechanisms.

Staged models:

| Model | Formula | Purpose |
|---|---|---|
| M1 | `edges` | Baseline tie propensity / network sparsity |
| M2 | `edges + mutual` | Tests reciprocity in directed payments |
| M3 | `edges + mutual + gwidegree + gwodegree` | Screens degree heterogeneity |
| M4 | `edges + mutual + gwidegree + gwodegree + gwesp` | Screens shared-partner closure |

The committed vertex attribute `degree` is not used as a predictor because it is derived from the same network. Using it as an exogenous covariate would create circular interpretation. The `date_joined` attribute is available for future modeling, but this preparation pass does not use it because the substantive relationship between join date and tie formation has not been justified yet.

The models are currently fit with MPLE for fast preparation and screening. Final inferential claims should refit the selected stable model with MCMLE, then report convergence diagnostics and goodness-of-fit simulations.

## ERGM Screening Results

All four staged MPLE screening models fit successfully.

| Model | Key interpretation |
|---|---|
| M1 | Baseline edge log-odds are strongly negative, consistent with a sparse network. |
| M2 | `mutual` has a large positive coefficient; reciprocated ties are far more likely than random independent directed ties. |
| M3 | Degree heterogeneity matters, especially for in-degree concentration. |
| M4 | Shared-partner closure is positive, meaning ties are more likely when endpoints are locally embedded. |

In the full closure model, the screening odds ratios are approximately:

| Term | Estimate | Odds ratio |
|---|---:|---:|
| `edges` | -5.235 | 0.005 |
| `mutual` | 2.683 | 14.626 |
| `gwideg.fixed.0.5` | -1.299 | 0.273 |
| `gwodeg.fixed.0.5` | 0.768 | 2.156 |
| `gwesp.OTP.fixed.0.5` | 1.410 | 4.095 |

These coefficients should be read as model-screening evidence, not final causal or inferential claims. The next step is to choose a stable final specification and estimate it with MCMLE.

## To-Do List for Final Analysis

- Decide whether M4 is the preferred final ERGM specification or whether a simpler M2/M3 model is more defensible.
- Refit the preferred model using MCMLE.
- Run `mcmc.diagnostics()` and inspect trace/mixing behavior.
- Run ERGM GOF checks for in-degree, out-degree, distance, and shared-partner structure.
- Report how the sampled 206-node network makes ERGM tractable while limiting generalizability to the full Venmo graph.
- Keep the interpretation focused on structural privacy leakage and relationship-strength inference, not verified relationship status.

## Reproducibility

Run the analysis with the project conda R environment:

```powershell
& 'C:\Users\15989\anaconda3\Scripts\conda.exe' run -p 'C:\Users\15989\Documents\New project\snap\.conda-r-ergm' Rscript scripts/04_descriptive_ergm_analysis.R .
```

Primary outputs:

- `outputs/analysis/network_summary.csv`
- `outputs/analysis/relationship_proxy_summary.csv`
- `outputs/analysis/ergm_model_status.csv`
- `outputs/analysis/ergm_coefficients.csv`
- `outputs/analysis/figures/degree_distribution.png`
- `outputs/analysis/figures/transaction_count_distribution.png`
- `outputs/analysis/figures/relationship_proxy_prevalence.png`

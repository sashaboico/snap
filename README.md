# Public By Default: Inferring Relationship Status from Venmo's Transaction Network

SNAP Track 1 Project — [Team Name]

## Project Overview

Client: Venmo/PayPal's Trust & Safety and Privacy Team

Core question: Can relationship status be predicted purely from a user's
position in the transaction network and their neighbors' public activity,
even for users who never explicitly reveal it themselves?

Primary method: ERGM (Exponential Random Graph Model)

## Team & Roles

| Person     | Role                                    |
|------------|------------------------------------------|
| Alexandra  | Data Preparation & Network Construction   |
| Yunai      | Inferential Modeling & Analysis (ERGM)    |
| Yas'lyn    | Relationship Measures & Descriptive Analysis |
| Ayaan      | Privacy Context & Client Implications     |

Shared: validation, interpretation, visualizations, final deliverables.

## Repo Structure

```
data/
  raw/          -> original unzipped CSV from the dataset (NOT committed — see .gitignore)
  processed/    -> cleaned/sampled data ready for network construction
scripts/
  01_load_data.R        -> load and inspect the raw CSV
  02_sample_network.R   -> sample down to a feasible node set
  03_build_network.R    -> build the tie list / network object
outputs/
  network_object.RData  -> final ERGM-ready network object (handoff to Yunai/Yas'lyn)
docs/
  data_dictionary.md    -> notes on dataset fields
```

## Data Source

Public Venmo Transaction Dataset (Salmon, 2019)
https://github.com/sa7mon/venmo-data

Note: raw data files are NOT committed to this repo (too large, and contains
pseudonymous usernames — see privacy note below). Each team member should
download the dataset separately and place it in `data/raw/` locally.

## Privacy Note

This dataset contains real (pseudonymous) usernames. Per our proposal, all
identifiers will be anonymized before any analysis, visualization, or
deliverable leaves this pipeline. Do not commit raw usernames or raw data
files to this repository.

## Pipeline Status

- [ ] Download & inspect raw data
- [ ] Sample down to feasible node set (~200-400 nodes)
- [ ] Build tie list / edge list
- [ ] Construct node-level attributes
- [ ] Assemble ERGM-ready network object
- [ ] Handoff to Yas'lyn (relationship-signal variable) and Yunai (ERGM)

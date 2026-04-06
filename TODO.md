# Altimeter Pipeline — TODO

## Pipeline architecture improvements

- [ ] **Move bed level computation from L3 to L2** — `altitude_to_bedlevel` is a coordinate transform on QC'd altitude, not a derived product. Full-resolution bed level belongs with the QC'd data at L2.
- [ ] **Make L3 purely burst-averaged** — once bed level moves to L2, L3 contains only burst-averaged products (bed level, IQR, dz/dt, backscatter mean/max). This cleanly separates "QC'd measurements" (L2) from "science-ready products" (L3).
- [ ] **Add deployment metadata to L1** — save instrument type, site, MOP, depth, sampling config alongside the raw data for provenance.
- [ ] **SIO echosounder .log reader optimization** — `read_echosounder_log.m` takes hours on 4-5 GB text files. Options: chunk-based reading, pre-filtering with grep, or convert to binary equivalent. Low priority since SIO altimeter data is the primary bed level measurement.

## QC refinements

- [ ] **Cross-deployment baseline anchoring** — consecutive deployments at the same location start with independent baselines (bed_level = 0 at first valid burst). For multi-deployment time series, anchor to survey elevations so absolute level is consistent across instrument swaps.
- [ ] **Settling period auto-detection** — the first N hours after deployment often have transient tilt/altitude. Could auto-detect and flag based on tilt convergence rate.

## Validation

- [ ] **Run `run_survey_validation.m` on full processed dataset** — currently only tested on SOL25 (4 surveys, 2 pairs, RMSE=22mm). Should also validate TP25 at multiple depths where surveys reach.
- [ ] **Cross-instrument validation at SIO** — SIO has co-deployed altimeter + echosounder. Compare their bed level time series for consistency (requires processing SIO echosounder data — blocked by .log reader speed).

## Science analysis (after pipeline is stable)

- [ ] **PUV correlation (L4)** — merge burst-averaged bed level with PUV L2 wave stats (Hs, Tp, Ub, tau_b, Ef). Both at ~17-min resolution. Start with SIO (continuous PUV + altimeter) and TP 5m (co-deployed PUV + echosounder).
- [ ] **Initiation of motion thresholds** — correlate dz/dt onset with bed shear stress tau_b to find critical Shields parameter at each depth.
- [ ] **Transport rate relationships** — dz/dt vs energy flux, orbital velocity, Dean Omega parameter.
- [ ] **Storm event case studies** — Dec 28 2023 (TP 5m accretion, Solana pipe damage), Dec 22 2024 (all sites affected).
- [ ] **Seasonal morphological cycle** — SIO 2-year record shows clear seasonal erosion/accretion. Quantify amplitude, timing, depth dependence.

## Longer-term (Paper 3): Interpolated seabed reconstruction

- [ ] **Merged survey + instrument interpolant** — combine periodic survey profiles with continuous altimeter/echosounder records into a best-estimate time-varying seabed surface. Instrument data provides temporal resolution; surveys provide spatial context and absolute elevation ground truth.
- [ ] **Quality-weighted fusion** — use burst IQR, pctValid, and firmware flags as uncertainty weights so corrupted periods (e.g., TP 5m Apr 2024) receive less weight than clean data. Survey points serve as hard constraints.
- [ ] **Gap filling approaches** (increasing sophistication):
  - Simple convolution / temporal interpolation between survey + instrument anchors
  - Equilibrium profile model driven by PUV wave data + sediment budget
  - ML approaches for full profile prediction from forcing + boundary conditions
- [ ] **Design note**: Keep instrument records and survey elevations as independent data sources — do NOT force-align instruments to surveys in the pipeline. The anchoring in `chain_deployments.m` is for visualization; for modeling, preserve both sources with their native uncertainties.

## Site-specific validation notes

- **SIO Pier (MOP511 6m)**: Sequential anchoring works well (<30mm offsets). 2-year continuous record. No survey validation possible (permit restrictions).
- **Torrey Pines 7m/10m/15m**: Survey-anchored records show good agreement. 10m is the cleanest site (~150mm total range). 15m very stable, no surveys reach that depth.
- **Torrey Pines 5m**: Good except April 2024 (~700mm discrepancy) — firmware Error-3 corruption period. Don't force-align; let uncertainty metadata propagate.
- **Solana Beach 7m**: Pipe physically relocated during re-jetting, so cross-deployment survey anchoring has spatial aliasing. Within-deployment validation is good (RMSE=22mm). Between deployments, treat as independent records.

## Ruled out

- [x] **SSC from echosounder backscatter** — tested, no detectable correlation between water column backscatter and wave energy (energetic/calm ratio = 1.00). The 450 kHz EA400 backscatter is useful for bed detection and qualitative visualization only, not quantitative sediment concentration.

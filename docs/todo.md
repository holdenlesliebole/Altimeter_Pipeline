# Altimeter Pipeline — TODO

## Pipeline architecture improvements

- [x] **Move bed level computation from L3 to L2** — DONE. `altitude_to_bedlevel` now computed in L2 after QC. Full-resolution bed level saved in L2 .mat alongside QC flags.
- [x] **Make L3 purely burst-averaged** — DONE. L3 now saves only `BA_alt`, `BA_echo`, and `dep` metadata. No full-resolution TTa/Eall (those are in L2).
- [x] **Add deployment metadata to L1** — DONE. `dep` struct saved in L1 .mat alongside raw data for provenance.
- [ ] **SIO echosounder .log reader optimization** — `read_echosounder_log.m` takes hours on 4-5 GB text files. Low priority since SIO altimeter data is the primary bed level measurement.

## QC refinements

- [x] **Cross-deployment baseline anchoring** — DONE. `chain_deployments.m` supports survey anchoring (TP, SOL) and sequential anchoring (SIO).
- [ ] **Settling period auto-detection** — the first N hours after deployment often have transient tilt/altitude. Could auto-detect and flag based on tilt convergence rate.

## Validation

- [x] **Run `run_survey_validation.m` on full processed dataset** — DONE. SOL 7m (27 surveys, RMSE=92mm cross-dep), TP 5m (11 surveys), TP 10m (9 surveys, RMSE=61mm).
- [x] **SIO survey validation** — DONE. Found 14 jetski GPS surveys at MOP 511 reaching -11.5m. SIO now uses survey anchoring (mopNumber=511 override, since auto-detection maps to MOP513).
- [ ] **Cross-instrument validation at SIO** — SIO has co-deployed altimeter + echosounder. Blocked by .log reader speed.
- [ ] **Fix SIO bed level y-axis** — survey anchoring may have shifted baseline; diagnostic plot shows -4000 to 0 mm range. Investigate offset interpolation for early deployments without survey matches.

## Science analysis

- [x] **PUV correlation (L4)** — DONE. `build_L4_site.m` + `run_L4.m` build merged products for SIO 6m (8190 PUV matched), TP 5/10/15m. MOP Hs gap-fills to 100% coverage at all sites.
- [ ] **Initiation of motion thresholds** — correlate dz/dt onset with bed shear stress tau_b to find critical Shields parameter at each depth. SIO shows all bursts mobilized at 6m; TP 10m/15m should show threshold behavior.
- [ ] **Transport rate relationships** — test 8 functional forms from reconciled plan. SIO binned |dz/dt| vs Ub already shows clear increasing trend (4→10 mm/hr). Fit power law, compare across depths.
- [ ] **Storm event case studies** — Dec 28 2023 (TP 5m +700mm accretion), Dec 22 2024 (all sites affected). Use L4 for simultaneous wave forcing + bed response.
- [ ] **Seasonal morphological cycle** — SIO 2-year record shows clear seasonal erosion/accretion. Quantify amplitude, timing, depth dependence.
- [ ] **TP 15m tau_b outliers** — suspicious values up to 35 Pa at 15m. Investigate: PUV QC issue or real extreme event?
- [ ] **Equilibrium model testing** — compute Dean disequilibrium from L4 Hs/depth/Tp, test whether dz/dt is proportional. Compare against Yates/Ludka at Torrey Pines.

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

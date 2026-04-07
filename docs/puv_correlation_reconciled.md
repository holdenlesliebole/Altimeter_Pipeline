# PUV–Altimeter Correlation: Reconciled Plan

Reconciliation of perspectives from:
- Altimeter side: `Altimeter_Pipeline/docs/puv_correlation_plan.md`
- PUV side: `PUV_Pipeline/docs/altimeter_correlation_plan.md`

## Areas of full agreement

Both sides agree on:

1. **±5 min nearest-neighbor matching** — both are integrated quantities, interpolation is meaningless
2. **Altimeter timestamps as backbone** — response variable drives the structure
3. **All 5 original transport relationships** — with PUV side's refinement to use bottom energy flux Fb instead of total Ef
4. **Implementation priority** — SIO first for prototyping, then TP multi-depth for the science

## PUV side additions incorporated

The PUV side proposed 5 additions that strengthen the plan:

### 1. Undertow transport (adopted)
`L3.subtidal.u` captures wave-driven return flow. During storms, undertow intensifies and drives offshore transport — a distinct mechanism from wave-orbital transport. Include in L4 struct.

### 2. Swell vs sea decomposition (adopted)
Test whether dz/dt correlates better with `L3.Ef_swell` or `L3.Ef_sea`. If swell dominates (longer waves reach the bed), this has implications for which wave model products are useful for morphology prediction. Important for the equilibrium model critique.

### 3. Cumulative forcing between survey dates (adopted)
Integrate both sides: cumulative Fb between surveys vs net Δz. Reduces noise from individual events and tests the bulk transport relationship. This bridges the "instantaneous" L4 analysis with the "survey-interval" validation.

### 4. Tidal phase flag (adopted)
Same Shields can produce different bed change at different tidal stages due to depth-dependent nonlinearity. Include `L3.tidal.depth_pred` in L4.

### 5. Time-varying doffp correction (adopted — high value)
The altimeter literally measures what the PUV pipeline assumes is constant (sensor height above bed). Using altimeter bed level to update PUV doffp would improve bed velocity and stress estimates, especially for deployments with >10 cm bed change. Implementation: optional reprocessing of PUV L2 with time-varying doffp from altimeter L3.

**This is potentially the most valuable cross-pipeline insight** — the two instruments correct each other's weaknesses.

## Pitfalls noted by both sides

| Issue | Altimeter perspective | PUV perspective | Resolution |
|-------|----------------------|-----------------|------------|
| Clock drift | Altimeter has no drift measurement | PUV drift is measured and corrected | ±5 min tolerance covers this; limits lag analysis to ~minutes |
| Spatial offset at SIO | Noted as open question | Quantified: ~2m between pipes | Flag in L4; will decorrelate small bedform signals |
| Storm data gaps | Both instruments fail during storms | MOP gap-fills PUV forcing; altimeter gaps unobserved | Flag storm periods; distinguish "no change" from "no data" |
| Direction conventions | Bed level is scalar (no direction issue) | Shore-normal rotation may fail (check L2.shorenormal) | Verify rotation before computing velocity moments |
| Pipe bending | Handled by tilt correction cos(α) | PUV tilt data could cross-check | Co-located instruments provide mutual validation |

## Revised L4 struct design

Merged from both perspectives. Fields marked with * are PUV-side additions:

```matlab
L4.time              % datetime — altimeter burst timestamps (backbone)
L4.deploymentID      % string — altimeter deployment ID

% Bed response (altimeter L3)
L4.bedlevel_mm       % burst-median bed level (mm)
L4.bedlevel_iqr_mm   % within-burst IQR (mm)
L4.dzdt_mm_hr        % bed level change rate (mm/hr)
L4.altitude_mm       % raw distance to bed (mm)
L4.pctValid          % % valid samples in burst

% Wave forcing — bulk (PUV L2)
L4.Hs                % significant wave height (m)
L4.Tp                % peak period (s)
L4.Ef                % total energy flux (W/m)
L4.Fb                % * bottom energy flux (W/m) — use instead of Ef for transport
L4.Fb_cum            % * cumulative bottom flux (J/m)
L4.depth             % total water depth (m)
L4.meanDir           % wave direction (deg)

% Wave forcing — bed level (PUV L2/L3)
L4.Ub                % near-bed orbital velocity (m/s)
L4.tau_b             % bed shear stress (Pa)
L4.Aw                % orbital amplitude (m)
L4.shields           % * Shields parameter (dimensionless)
L4.mobilized         % * boolean: is sand moving?

% Wave forcing — moments (PUV L2)
L4.skewness          % velocity skewness
L4.asymmetry         % acceleration asymmetry
L4.u_abs3            % |u|³ moment (m³/s³)
L4.u_uabs2           % u|u|² moment (m³/s³)

% Currents (PUV L2/L3)
L4.uMean             % mean cross-shore current (m/s)
L4.vMean             % mean alongshore current (m/s)
L4.subtidal_u        % * subtidal cross-shore = undertow (m/s)

% Spectral decomposition (PUV L3)
L4.Ef_swell          % * swell energy flux (W/m)
L4.Ef_sea            % * sea energy flux (W/m)

% Turbulence (PUV L2)
L4.TKE               % turbulent kinetic energy (m²/s²)

% Context
L4.tidal_depth       % * NOAA tidal prediction (m)
L4.storm_flag        % * boolean: during detected storm event

% Quality
L4.puv_match_min     % time offset to nearest PUV segment (min)
L4.puv_valid         % boolean: PUV segment was valid
L4.alt_quality       % composite quality from IQR + pctValid

% Metadata
L4.site, L4.mop, L4.depth_m
L4.puv_deployment, L4.alt_deployment
L4.D50               % * grain size used for Shields
L4.doffp             % * PUV sensor height above bed (could be time-varying)
```

## Revised analysis plan (8 approaches)

| # | Relationship | Key PUV fields | Notes |
|---|---|---|---|
| 1 | Excess Shields stress | shields, mobilized | Use θ - θ_cr for universality |
| 2 | Bottom energy flux | Fb | Not total Ef — Fb is bed-relevant |
| 3 | Velocity cubed | u_abs3 | Bailard energetics (unsigned) |
| 4 | Velocity moments | u_uabs2, skewness | Captures directional asymmetry |
| 5 | Equilibrium disequilibrium | Hs, depth, Tp | Test empirically, don't prescribe form |
| 6 | * Undertow transport | subtidal_u | Distinct storm-driven offshore mechanism |
| 7 | * Swell vs sea | Ef_swell, Ef_sea | Which band drives morphology? |
| 8 | * Cumulative forcing | Fb_cum vs net Δz | Bulk relationship between survey dates |

## Implementation priority (confirmed)

1. **SIO Pier 6m** — prototype the merge (continuous, simple)
2. **Torrey Pines 5m TOR25S** — co-located, cleanest period for method development
3. **Torrey Pines 10m/15m TOR25S** — cross-shore extension
4. **Torrey Pines full record** — chain NN24 + TOR24S + TOR24W + TOR25S
5. **Solana Beach** — last (pipe relocation issues)

PUV side also suggested **starting with TOR24S** (spring 2024, 3 co-located depths with good storm coverage). This is a reasonable alternative to SIO for the first implementation — TP has co-located instruments and beach surveys, while SIO has the 2m spatial offset.

**Recommendation**: Prototype the merge function with SIO (simpler), then do the science with TP (richer dataset).

## Action items

- [ ] Build `merge_puv_altimeter.m` — nearest-neighbor matching, L4 struct construction
- [ ] Test on SIO (prototype)
- [ ] Apply to TP25S 5m/10m/15m (science dataset)
- [ ] Explore time-varying doffp correction (reprocess PUV L2 with altimeter feedback)
- [ ] Generate correlation figures (scatter plots, binned threshold analysis)

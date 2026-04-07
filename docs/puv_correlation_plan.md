# PUV–Altimeter Correlation Plan

## Perspective: from the Altimeter Pipeline side

This document outlines how to merge burst-averaged bed level products from the Altimeter Pipeline with wave spectral products from the PUV Pipeline to create an L4 dataset suitable for sediment transport analysis.

## What we have

### Altimeter Pipeline (L3 products)
- **Burst-averaged bed level** at ~17 min cadence (burst median, with IQR uncertainty)
- **Bed level change rate** dz/dt (mm/hr) between consecutive bursts
- **Burst-averaged backscatter** mean/max profiles (echosounder only)
- Quality metadata: pctValid, burst IQR, deployment ID per burst
- Cross-deployment chaining via survey anchoring or sequential method

### PUV Pipeline (L2 products)
- **17-minute spectral segments** (2048 samples at 2 Hz = 17.07 min)
- **Bulk wave parameters**: Hs, Tp, Tm02, mean direction, energy flux Ef
- **Bed-level forcing**: orbital velocity Ub, bed shear stress tau_b, friction factor, orbital amplitude Aw
- **Velocity moments**: skewness, asymmetry (critical for net transport direction)
- **Reynolds stresses**: TKE, u'w', vertical momentum flux
- **Water column**: mean velocities, temperature, depth

## Temporal overlap

| Site | PUV deployments | Altimeter deployments | Overlap period | Co-located depths |
|------|-----------------|----------------------|----------------|-------------------|
| **SIO Pier** | SIO24A-C, SIO25A-E | SIO24-26 (23 deployments) | Apr 2024 – Mar 2026 | **6m** |
| **Torrey Pines** | NN24, TOR24S, TOR24W, TOR25S | TP24, TP25 | Nov 2023 – Jun 2025 | **5, 7, 10, 15m** |
| **Solana Beach** | SOL24, SOL25A, SOL25B | SOL24-26 | Dec 2024 – Feb 2026 | **7m** |

SIO is the strongest dataset: near-continuous coverage at one depth for 2 years with both instruments.
Torrey Pines is the richest: 4 cross-shore depths with PUV + altimeter/echosounder for ~18 months.

## The merge: L4 product design

### Goal
One struct per site/depth with matched timestamps containing both wave forcing and bed response.

### Timestamp alignment

Both pipelines produce ~17-minute averaged values, but timestamps won't align exactly because:
1. PUV L2 segments are index-based (every 2048 samples from deployment start)
2. Altimeter bursts are gap-detected (from physical sampling pauses)
3. Independent clocks (no synchronization between instruments)

**Approach: nearest-neighbor matching with tolerance**

For each altimeter burst timestamp, find the nearest PUV L2 segment within ±5 minutes. If no match within tolerance, set PUV fields to NaN. This preserves the altimeter's temporal coverage while flagging gaps in PUV data.

Why nearest-neighbor over interpolation: wave parameters (Hs, tau_b) represent 17-minute spectral averages — they're already integrated quantities. Interpolating between two 17-minute averages doesn't add information; it just smooths. The nearest segment within ±5 min represents the same physical conditions.

### L4 struct fields

```matlab
L4.time              % datetime — from altimeter burst timestamps (primary)
L4.deploymentID      % string — altimeter deployment ID

% Bed response (from altimeter/echosounder L3)
L4.bedlevel_mm       % burst-median bed level (mm, relative to baseline)
L4.bedlevel_iqr_mm   % within-burst IQR (mm, uncertainty estimate)
L4.dzdt_mm_hr        % bed level change rate (mm/hr)
L4.altitude_mm       % burst-median altitude (mm, raw distance to bed)
L4.pctValid          % % valid samples in burst

% Wave forcing (from PUV L2, matched by nearest neighbor)
L4.Hs                % significant wave height (m)
L4.Tp                % peak period (s)
L4.Ef                % energy flux (W/m)
L4.Ub                % near-bed orbital velocity (m/s)
L4.tau_b             % bed shear stress (Pa)
L4.Aw                % orbital amplitude (m)
L4.depth             % total water depth (m)
L4.meanDir           % wave direction (deg)
L4.skewness          % velocity skewness (dimensionless)
L4.asymmetry         % velocity asymmetry (dimensionless)
L4.TKE               % turbulent kinetic energy (m²/s²)
L4.uMean             % mean cross-shore current (m/s)

% Quality
L4.pvuMatch_min      % time offset to nearest PUV segment (min)
L4.pvuValid          % boolean — PUV segment was valid (segValid)
L4.altQuality        % composite quality: pctValid * (1 - IQR/IQR_p99)

% Metadata
L4.site              % string
L4.mop               % string
L4.depth_m           % nominal depth (m)
L4.pvuDeployment     % PUV deployment name
L4.altDeployment     % altimeter deployment name
```

### Handling deployment gaps

PUV and altimeter deployments don't always overlap perfectly:
- PUV might have a gap (battery died) while altimeter continues → NaN in wave fields
- Altimeter might have a gap while PUV continues → those PUV segments are not in L4 (altimeter timestamps are primary)
- Both might have gaps → no data at that time

The L4 product preserves the altimeter's temporal backbone and fills in PUV fields where available. Completeness statistics should be reported per deployment.

## Analysis plan with L4 data

### 1. Threshold identification

**Question**: At what tau_b does |dz/dt| become systematically non-zero?

**Method**:
- Bin dz/dt by tau_b (e.g., 0.1 Pa bins)
- For each bin, compute mean |dz/dt| and its 95% confidence interval
- The threshold tau_cr is where the mean |dz/dt| first exceeds the background noise level (estimated from the burst IQR)
- Convert to Shields parameter: θ_cr = tau_cr / ((ρ_s - ρ) g D50)
- Compare against Soulsby (1997) threshold curves

**Expected depth dependence**: deeper sites should have higher tau_b thresholds (coarser lag deposits, less wave energy reaching bed) or lower thresholds (finer mobile sediment at depth).

### 2. Transport rate relationships

**Question**: What's the functional form of dz/dt vs forcing?

**Candidates to test**:
- dz/dt ~ (tau_b - tau_cr) — linear excess shear stress (Meyer-Peter Müller style)
- dz/dt ~ (tau_b - tau_cr)^1.5 — power law (Bagnold/Engelund-Hansen style)
- dz/dt ~ Ef — energy flux (simple wave power approach)
- dz/dt ~ Ub³ — cubic velocity (Bailard 1981)
- dz/dt ~ skewness × Ub³ — velocity moments approach (Hoefel & Elgar 2003)

**Method**: Fit each model to the L4 data, compare R², AIC, residual structure. Do separately for each site/depth.

### 3. Equilibrium model testing

**Question**: Does the bed respond like Dean/Yates/Ludka predict?

**Method**:
- Compute the "disequilibrium" Ω - Ω_eq for each burst (using Hs, Tp from PUV)
- Test whether dz/dt is proportional to the disequilibrium
- Examine whether the relationship is the same at all depths
- Check post-storm relaxation: does bed level decay exponentially toward equilibrium?
- Compare equilibrium model skill against the transport-rate models above

### 4. Storm event decomposition

**Question**: How does the cross-shore bed response vary during a storm?

**Method**:
- Identify storm events (Hs > threshold for > 6 hours)
- For each event at Torrey Pines: plot synchronized time series of Hs, tau_b, Ef and dz/dt at 5, 10, 15m
- Quantify depth-dependent response: total Δz per event, peak dz/dt, lag relative to peak Hs
- Test whether deeper sites respond later (lag increases with depth)

### 5. Seasonal decomposition

**Question**: What wave parameters control the seasonal morphological cycle?

**Method**:
- Low-pass filter L4.bedlevel_mm to extract seasonal signal (cutoff ~30 days)
- Similarly filter wave parameters
- Cross-correlation between seasonal bed level and seasonal Hs, Ef, Omega
- Phase analysis: does the seasonal bed level lag the wave forcing? By how much?

## Implementation approach

### Function: `merge_puv_altimeter.m`

```matlab
function L4 = merge_puv_altimeter(BA, L2, opts)
% Inputs:
%   BA : burst-averaged struct from altimeter L3
%   L2 : PUV L2 struct
%   opts.matchTolerance_min : max time offset for nearest-neighbor match (default 5)
%
% For each burst in BA, find nearest L2 segment within tolerance.
% Copy wave fields from L2 to L4, set to NaN if no match.
```

### Function: `build_L4_site.m`

```matlab
function L4 = build_L4_site(L3root, L2root, siteName, depth_m, opts)
% Chain all altimeter L3 files for this site/depth.
% Load all PUV L2 files for matching deployments.
% Call merge_puv_altimeter for each overlapping period.
% Return single L4 struct spanning the full record.
```

### Script: `run_L4_correlation.m`

```matlab
% Build L4 for each site/depth.
% Generate diagnostic plots.
% Save L4 .mat files.
```

## Open questions

1. **Clock drift**: PUV instruments have measured clock drift (corrected in L1). Altimeters do not (no clock drift measurement at recovery). Could there be a systematic time offset that degrades the correlation? Probably negligible at 17-min averaging, but worth checking.

2. **Spatial offset**: At Torrey Pines, the PUV and altimeter are on the same pipe mount, so truly co-located (<0.5m separation). At SIO, they're on separate pipes — how far apart? Need to verify from deployment notes.

3. **Water depth from PUV vs altimeter**: PUV computes depth from pressure; altimeter measures distance to bed. These should be consistent (sum to instrument height) — good cross-check.

4. **Which PUV deployment to match?** Some altimeter periods span PUV deployment boundaries (PUV battery dies, gets swapped, altimeter keeps running). Need to handle multi-L2-file matching per altimeter deployment.

5. **Direction convention**: PUV L2 shore-normal velocity may use different sign conventions depending on deployment (ENU vs XYZ, rotated vs unrotated). Need to standardize before computing velocity moments.

## Priority order for implementation

1. **SIO Pier 6m** — simplest case: one depth, one MOP, near-continuous coverage from both instruments. Good for prototyping the merge.
2. **Torrey Pines 5m (TOR25S)** — co-located PUV + echosounder, clean 3-month record. Tests the merge at the most morphologically active depth.
3. **Torrey Pines 10m/15m (TOR25S)** — same period, deeper sites for cross-shore comparison.
4. **Torrey Pines multi-period** — chain NN24 + TOR24S + TOR24W + TOR25S for the full 18-month record at each depth. Needs careful handling of PUV deployment boundaries.
5. **Solana Beach** — last priority due to pipe relocation issues.

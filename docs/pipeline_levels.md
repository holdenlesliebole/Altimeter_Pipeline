# Altimeter Pipeline Processing Levels

## Design Philosophy

Each level transforms data from the previous level into higher-order products. Levels L1–L3 are **universal** — they produce the same outputs regardless of the scientific question. L4 is **analysis-specific** — it merges altimeter products with PUV wave data.

The pipeline handles two instrument types (AA400 altimeter and EA400 echosounder) with shared altitude QC and instrument-specific extensions (tilt correction, backscatter masking).

---

## L0: Raw Data (on server)

**Location:** `/Volumes/group/Altimeter_data/{SouthSIOPier,TorreyPines,SolanaBeach}/`

| Instrument | Format | Size | Reader |
|---|---|---|---|
| AA400 Altimeter | RangeLogger .log (ASCII CSV) | 20-40 MB | `read_rangelogger_log.m` |
| EA400 Echosounder | .BIN (proprietary binary) | 100-525 MB | `read_echosounder_bin.m` |
| EA400 Echosounder | .log (ASCII text, legacy) | 1-5 GB | `read_echosounder_log.m` (slow) |

**Local caching:** `copy_raw_to_local.m` copies server files to `raw_cache/` with byte-size skip check.

---

## L1: Read + Concatenate (COMPLETE)

**Input:** Raw .log or .BIN files
**Output:** `{DeploymentID}_L1.mat` — raw timetable (altimeter) and/or struct (echosounder)

### AA400 Altimeter
- Parse CSV with device header skip and burst summary line handling
- Output timetable: `Time, Altitude_mm, Temperature_C, Battery_mV, Amplitude_pctFS`

### EA400 Echosounder
- Parse binary: 128-byte header + repeating records (DATA + backscatter + STAT)
- Vectorized reshape extraction for performance on 500+ MB files
- Output struct: `time, altitude_mm, pitch_deg, roll_deg, backscatter (NxM), temperature_C`

Multiple files per deployment are concatenated and sorted chronologically.

**Status:** Complete. All 47 deployments read successfully.

---

## L2: Quality Control (COMPLETE)

**Input:** L1 .mat files
**Output:** `{DeploymentID}_L2.mat` — QC'd data with quality flags

### Shared (both instruments)
- **Invalid value removal** (bit 1): zeros, out-of-range (>5000 mm for firmware Error-3), NaN
- **Phase-space despiking** (bit 2): Goring & Nikora (2002), parameter-free
  - Auto-detects burst mode (gaps >10 sec) and applies per-burst independently
  - Continuous mode: full time series in one pass
- Quality flag: uint16 bitmask per sample

### EA400 Echosounder additions
- **Geometric tilt correction**: `altitude_corrected = altitude * cos(totalTilt)`. Median correction stored in QF struct.
- **Tilt deviation mask**: flags pings where |pitch - median_pitch| or |roll - median_roll| > 2°. Preserves data from instruments with static tilt up to 13°.
- **Below-bed backscatter mask**: NaN all bins at range > altitude. Pings with no echo (altitude = NaN) have entire profile masked.

**Status:** Complete. Phase-space despike validated on all instrument types. Two-level despiking (per-ping + burst-level) handles firmware-corrupted records.

---

## L3: Burst-Averaged Products (COMPLETE)

**Input:** L2 .mat files
**Output:** `{DeploymentID}_L3.mat` — burst-averaged bed level + backscatter

### Burst averaging
- **Auto-detects sampling mode**: burst (gaps >10 sec → physical burst boundaries) vs continuous (fixed 2048-sample windows matching PUV L2 segment length)
- **Per-burst products**: median altitude, IQR (measurement uncertainty), percent valid
- **Iterative burst-level despike**: phase-space on burst medians, up to 5 passes until convergence. Catches entire corrupted bursts (firmware errors, acoustic artifacts).
- **Bed level**: `Δz = -(altitude - baseline)`, baseline = first fully valid burst median
- **dz/dt**: bed level change rate (mm/hr) between consecutive bursts, NaN across large gaps

### Echosounder additions
- Burst-mean and burst-max backscatter profiles
- Mean pitch/roll per burst

### Output struct BA:
```
.time, .bedlevel_mm, .bedlevel_iqr_mm, .altitude_mm
.pctValid, .dzdt_mm_hr, .nBursts, .burstSamples, .mode
(echosounder: .backscatter_mean, .backscatter_max, .pitch_mean, .roll_mean)
```

**Status:** Complete. Validated across 5 test deployments (altimeter continuous, altimeter burst 60-sample, altimeter burst 300-sample, echosounder BIN, echosounder tilted). All 47 deployments processed successfully.

---

## L4: PUV-Merged Products (PROTOTYPE)

**Input:** Altimeter L3 + PUV L2/L3 .mat files
**Output:** Merged struct with bed response + wave forcing per matched timestamp

### Timestamp matching
- Nearest-neighbor within ±5 min tolerance
- Altimeter burst timestamps as backbone (response variable)
- PUV fields set to NaN where no match exists

### L4 struct (reconciled from both pipeline perspectives):
```
% Bed response (altimeter)
.bedlevel_mm, .bedlevel_iqr_mm, .dzdt_mm_hr, .altitude_mm, .pctValid

% Wave forcing — bulk (PUV L2)
.Hs, .Tp, .Ef, .depth, .meanDir

% Wave forcing — bed level (PUV L2/L3)
.Ub, .tau_b, .Aw, .Fb, .Fb_cum, .shields, .mobilized

% Velocity moments (PUV L2)
.skewness, .asymmetry, .u_abs3, .u_uabs2

% Currents (PUV L2/L3)
.uMean, .vMean, .subtidal_u, .TKE

% Context
.tidal_depth, .storm_flag, .Ef_swell, .Ef_sea

% Quality
.puv_match_min, .puv_valid, .alt_quality
```

**Status:** Prototype working on SIO24A (131 matched bursts). Full-site products to be built.

---

## Cross-Deployment Tools

These operate across deployment boundaries:

| Tool | Purpose |
|---|---|
| `chain_deployments.m` | Anchor consecutive deployments into continuous time series (survey or sequential method) |
| `plot_chained_timeseries.m` | Plot chained bed level with survey markers and deployment boundaries |
| `validate_against_surveys.m` | Compare instrument bed level against jetski GPS survey profiles |
| `plot_site_timeseries.m` | Multi-depth time series per site |
| `run_all_and_plot.m` | Batch process all 47 deployments + generate site plots |

---

## Design Principles

1. **Same altitude QC for both instruments** — shared `qc_altitude.m` with instrument-specific extensions in `qc_echosounder.m`
2. **Burst-mode auto-detection** — pipeline works for continuous (SIO), burst-60 (TP altimeter), and burst-300 (SIO/TP/SOL echosounder) without manual configuration
3. **Independence of instruments and surveys** — both are kept as separate data layers with native uncertainties for downstream modeling
4. **Config-driven** — deployment metadata in code (PUV_Pipeline pattern), not spreadsheets
5. **Local caching** — copy from server once, process from fast local disk
6. **Batch-safe** — no interactive figures, all outputs saved via `exportgraphics`

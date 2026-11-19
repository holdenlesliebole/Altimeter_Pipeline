# Altimeter & Echosounder Processing Pipeline

## Where the processed products live

`outputs/` is gitignored (12 GB), so the repo carries code only. A mirror of the processed
products is on reefbreak at:

    /Volumes/group/Altimeter_data/Processed_HLB/

with `L1_L2_L3/`, `L4/`, `provenance/` (pre-rebuild L4 snapshots), `diagnostics/`, a `README.md`
and `MANIFEST.sha256`. First published 2026-08-24 from commit `bed28a7`. The raw `.log` / `.dat`
files in the parent `Altimeter_data/` directories remain the source of record; the mirror is a
cache of a reproducible computation, not a substitute.

**Before trusting `L4.tau_b_combined` or `L4.shields_combined`, run
`CODES/check_L4_grainsize_current.m`.** Grain size is resolved at BUILD time from
`PUV_Pipeline/shared/site_grain_size.m` and stamped into the L4; nothing forces a rebuild when
that table changes, and it has changed silently before (see `docs/audit.md` and commit `bed28a7`).

**L4 rebuilt 2026-11-16 and pushed to reefbreak 2026-11-16 (server sha256 = local, 11/11).** The
six L4 files (`L4_TP_{5,7,10,15}m`, `L4_SIO_6m`, `L4_SOL_7m`) were rebuilt with `run_L4.m` from the
PUV_Pipeline beam-step rebuild of all 66 PUV records, PUV catalog 2026-11-17.1 (L1 beam-step
correction, T_b, Swart; see `PUV_Pipeline/docs/SPEC_L1_beam_step_correction_2026-11-13.md` sec. 12).
The August build was stale against PUV L2 (`docs/DIAGNOSIS_L4_stale_PUV_L2_2026-11-13.md`). Each L4
now stamps the PUV L2 and L3 it read (`L4.prov_parents`: path, build_id, file_sha256). **Before
trusting an L4, run `CODES/check_L4_parents_current.m`** beside `check_L4_grainsize_current.m`; on
2026-11-16 it read 42/42 parent stamps current, and its break test (`breakTest=true`) flags 1/42
STALE as it must. Pre-rebuild hashes:
`PUV_Pipeline/docs/archive_snapshot_manifests/pre_beamstep_altimeter_L4_2026-11-16_manifest.csv`.

**L4 rebuilt again 2026-11-18 and pushed to reefbreak 2026-11-18 (server sha256 = manifest,
11/11: six L4 files and five diagnostic figures).** Built on PUV catalog 2026-11-17.2, which switched
12 PUV records to the diver-logged mount heading (`PUV_Pipeline/docs/catalog_changes/
2026-11-18_logged_headings.md`); three of them feed L4 (SIO25E -> `L4_SIO_6m`, TOR24W -> `L4_TP_10m`,
TOR25S -> `L4_TP_15m`). Before the rebuild `check_L4_parents_current` read 36/42 current, the six
stale stamps being exactly those three records' L2 and L3; after it, 42/42, break test 41/42;
grain size current at 6/6. Changes against the 2026-11-16 files:
- `storm_flag` now set (it was false everywhere; fix 3f46686): SIO 6 m 289 of 33,846 bursts, SOL 7 m
  1,442 of 24,697, TP 5 m 873 of 32,486, TP 7 m 1,443 of 23,098, TP 10 m 1,610 of 25,696, TP 15 m
  1,578 of 24,092. New field `storm_flag_nEvents`.
- At SIO 6 m, TP 10 m and TP 15 m the direction-dependent PUV fields moved with the heading:
  `meanDir` by up to 11.3, 12.4 and 11.9 deg; `uMean`, `vMean`, `subtidal_u` by up to 0.057 m/s;
  `skewness`, `asymmetry`, `u_abs3`, `u_uabs2`. Ub, Aw, TKE, tau_b and Shields changed only at
  rounding (below 3e-15).
- **TP 5 m: the 2026-11-16 file had no MOP gap-fill.** `mop_Hs`, `mop_Tp` and `mop_Ub` were NaN at
  all 32,486 bursts, so `Hs_combined`, `Ub_combined`, `tau_b_combined` and `shields_combined`
  existed only at the 6,307 PUV-matched bursts (19%), and `Ub_calibration` was 1 instead of 1.065.
  The cause was not found (the MOP read failed without an error in that build; the other five
  files were filled). The 2026-11-18 file is filled at 32,486/32,486. Anything computed from
  `L4_TP_5m` combined fields between 2026-11-16 and 2026-11-18 saw only PUV-matched bursts.
Pre-rebuild hashes:
`PUV_Pipeline/docs/archive_snapshot_manifests/pre_heading_altimeter_L4_2026-11-18_manifest.csv`.


Processing pipeline for subaqueous bed-level instruments deployed on the inner shelf at three sites in San Diego County. These instruments measure changes in sand bed elevation in response to wave forcing, providing a direct record of erosion and accretion at the deployment location.

Most altimeter/echosounder deployments were done simultaneously with PUV (pressure-velocity) wave instruments, giving a paired dataset of wave forcing (from PUVs) and immediate bed-level + sediment suspension response (from altimeters/echosounders).

## Instruments

Two instruments are used, both manufactured by **Echologger** (EofE Ultrasonics Co., Ltd):

### AA400 Altimeter ("altimeter" in code)
- Autonomous acoustic altimeter operating at 450 kHz
- Measures **distance from sensor to bed** (altitude) only
- Sampling rate: 2 Hz (configurable)
- Powered by 3x AA alkaline batteries
- Data format: Nortek RangeLogger `.log` files (ASCII CSV)
- Key output: `Altitude_mm`, `Temperature_C`, `Battery_mV`, `Amplitude_pctFS`

### EA400 Echosounder ("echosounder" in code)
- Autonomous precision echosounder operating at 450 kHz
- Measures **distance to bed** plus a full **acoustic backscatter profile** through the water column, showing sediment suspension
- Sampling rate: configurable (typically 2 Hz within bursts, hourly burst cycle)
- Data formats:
  - `.log` text files (older deployments, SouthSIOPier): ASCII with `#TimeLocal` headers, `##DataStart`/`##DataEnd` backscatter blocks
  - `.BIN` binary files (newer deployments, all sites): 128-byte file header + repeating binary records with backscatter + metadata
- Key output: `altitude_mm`, `pitch_deg`, `roll_deg`, `temperature_C`, `backscatter` (N x M matrix of depth bins)

## Deployment Sites

| Site | MOP | Depths | Period | Altimeter | Echosounder Format |
|------|-----|--------|--------|-----------|-------------------|
| South SIO Pier | MOP511 | 6 m | Apr 2024 -- Mar 2026 | AA400 | `.log` (text) |
| Torrey Pines | MOP586 | 5, 7, 10, 15 m | Nov 2023 -- Jun 2025 | AA400 | `.BIN` (binary) |
| Solana Beach | MOP654 | 7 m | Nov 2024 -- Feb 2026 | AA400 | `.BIN` (binary) |

Raw data lives on the lab server at: `/Volumes/group/Altimeter_data/`

Subdirectories: `SouthSIOPier/data/`, `TorreyPines/`, `SolanaBeach/`

**Torrey Pines coverage note (verified 2026-05-20):** the TP24 "Phase 1"
altimeter deployment at all four depths (5/7/10/15 m) records continuously
from **~13 November 2023** through June 2024, despite the raw `.log` files
being named with Jan--Feb 2024 dates (the filename reflects the service /
download date, not the data start). Fall 2023 (pre-Jan 2024) has ~2,100--2,800
valid burst-median samples per depth; the 7 m channel additionally has a sparse
window in Jan--Mar 2024. After a Jul--Nov 2024 echosounder-only phase, altimeter
+ echosounder coverage resumes Nov 2024 -- Jun 2025. The 15 m channel was
deployed only during Phase 1 (pulled Aug 2024) plus a short Nov--Dec 2024
redeployment.

**Source of truth (important):** the canonical deployment registry that
produces the current `outputs/` is the **config registry**
(`config/deployment_registry.m` → `TP24_config.m` etc.), run via
`run_all_and_plot.m`. The flat `metadata/deployments.csv` is a *legacy*
parallel registry consumed by the older `run_altimeter_pipeline.m`
orchestrator; it does not group the multi-depth Phase 1 altimeters into
deployments the way the config does. The CSV has been reconciled (depths
assigned from sensor IDs) for documentation accuracy, but the config
registry remains authoritative.

## Pipeline Stages

### L0: Raw data on server
RangeLogger `.log` files (altimeter) and echosounder `.log` or `.BIN` files. Not modified by this pipeline.

### L1: Read and concatenate
- `read_rangelogger_log.m` -- reads AA400 altimeter `.log` files into a MATLAB timetable with variables: `Altitude_mm`, `Temperature_C`, `Battery_mV`, `Amplitude_pctFS`
- `read_echosounder_log.m` -- reads EA400 echosounder `.log` text files into a struct with fields: `time`, `altitude_mm`, `pitch_deg`, `roll_deg`, `backscatter`
- `read_echosounder_bin.m` -- reads EA400 echosounder `.BIN` binary files into the same struct format (plus `temperature_C`)

Multiple files per deployment are concatenated and time-sorted.

### L2: Quality control
- `qc_altitude.m` -- two-pass despiking using moving mean with configurable thresholds, neighbor jump filter, optional Hampel filter. Returns quality flag bitmask:
  - bit 1: removed (zero/invalid range)
  - bit 2: moving-mean despike
  - bit 3: jump/neighbor spike
  - bit 4: Hampel outlier
- `qc_echosounder.m` -- applies `qc_altitude` to echosounder altitude, then masks rows where |pitch| or |roll| exceeds tilt threshold (default 2 deg). Masks corresponding backscatter rows.

### L3: Derived products
- `altitude_to_bedlevel.m` -- converts distance-to-bed (altitude) to relative bed level change:
  ```
  BedLevel_mm = -(Altitude_mm - Altitude_mm(baseline))
  ```
  Convention: **accretion is positive, erosion is negative**. Baseline defaults to first non-NaN value.

## Quick Start

### 1. Verify deployment table
Open `metadata/deployments.csv` and confirm file paths and metadata are correct. Each row is one deployment period. Key columns:

| Column | Description |
|--------|-------------|
| `DeploymentID` | Unique identifier, e.g. `SouthSIOPier_MOP511_6m_20240402` |
| `Site` | `SouthSIOPier`, `TorreyPines`, or `SolanaBeach` |
| `MOP` | MOP transect number |
| `Depth_m` | Nominal deployment depth |
| `AltimeterFiles` | Pipe-separated paths to AA400 `.log` files (relative to server root) |
| `EchosounderFiles` | Pipe-separated paths to EA400 `.log` or `.BIN` files (relative to server root) |
| `TZ_offset_hours` | Hours to add to echosounder local time (7 = PDT, 8 = PST) |
| `Active` | Set to `0` to skip a deployment |

### 2. Mount the server
Ensure `/Volumes/group/Altimeter_data/` is accessible.

### 3. Run the pipeline
```matlab
cd('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES')
run_altimeter_pipeline
```

The pipeline reads `deployments.csv`, processes each active row, and saves:
- `processed/<Site>/<DeploymentID>_L1.mat` -- raw timetable + echosounder struct
- `processed/<Site>/<DeploymentID>_L2.mat` -- QC'd data with quality flags
- `processed/<Site>/<DeploymentID>_L3.mat` -- L2 + `BedLevel_mm` variable + deployment metadata
- `processed/<Site>/<DeploymentID>_ql.png` -- quicklook figure

Set `cfg.overwrite = true` to reprocess deployments that already have L3 output.

### 4. Regenerate deployment table (optional)
If new files have been added to the server:
```matlab
cd('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES')
build_deployment_table
```
Then edit the generated CSV to pair altimeter files with echosounder files.

## QC Parameters

Default parameters in `run_altimeter_pipeline.m`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `winMovMean` | 15 min | Moving-mean window for despike passes |
| `thr1_mm` | 200 mm | First-pass spike threshold |
| `thr2_mm` | 100 mm | Second-pass spike threshold |
| `jump_mm` | 10 mm | Neighbor-jump threshold |
| `useHampel` | false | Enable Hampel robust outlier filter |
| `tilt_deg` | 2 deg | Echosounder pitch/roll masking threshold |

## EA400 .BIN Binary Format

The `.BIN` format was reverse-engineered from instrument files (no public documentation exists from the manufacturer).

**File header**: 128 bytes (config parameters, timer name, sound speed)

**Repeating records** (one per ping):
1. **DATA sub-record** (64-byte header + N x uint16 backscatter):
   - `"DATA"` marker, version, ping number, num_samples, unix timestamp
   - Backscatter values (0--1023) in `num_samples` depth bins
2. **STAT sub-record** (64 bytes): authoritative metadata for the ping
   - Temperature (C), altitude (m), pitch (deg), roll (deg)

Record sizes vary by instrument configuration:
- 272 depth bins: 672 bytes/record (SouthSIOPier, SolanaBeach)
- 400 depth bins: 928 bytes/record (TorreyPines)

Depth bin spacing: 7.5 mm (default `RangeResolution_m = 0.0075`).

## Connection to PUV Pipeline

The PUV processing pipeline lives at `Beach_Change_Observation/Vector/PUVs/PUV_Processing-main/`. PUV instruments were typically co-deployed with altimeters/echosounders at the same cross-shore locations, providing simultaneous measurements of:

- **PUV**: wave height, period, direction, energy flux, velocity spectra
- **Altimeter**: bed level change (erosion/accretion)
- **Echosounder**: bed level change + sediment suspension through the water column

Linking the two datasets by time enables analysis of wave-driven morphological change at event to seasonal timescales.

## Known Limitations

- **Echosounder timezone**: `TZ_offset_hours` is static per deployment. Deployments spanning a DST transition have a ~1 hour offset at the boundary.
- **Early deployments**: Some TorreyPines (Jan--Aug 2024) and SolanaBeach (Jan 2024) altimeter files lack depth metadata in filenames. Cross-reference with `EchologgerCheckout*.xlsx` on the server.
- **SouthSIOPier echosounder matching**: Deployments after May 2025 have `EchosounderFiles` left blank in the CSV -- echosounder data exists on the server but needs manual date-range matching.
- **No NetCDF export**: Outputs are `.mat` only. A `write_altimeter_netcdf.m` function could be added for long-term archival.

## Repository Structure

```
Altimeter_Pipeline/
├── NOTES.md                 # This file
├── .gitignore               # Ignores processed/ and MATLAB temp files
├── CODES/                   # All processing functions
│   ├── run_altimeter_pipeline.m      # Main entry point
│   ├── process_deployment.m          # Single-deployment processor
│   ├── build_deployment_table.m      # CSV generator from server scan
│   ├── read_rangelogger_log.m        # AA400 .log reader
│   ├── read_echosounder_log.m        # EA400 .log reader
│   ├── read_echosounder_bin.m        # EA400 .BIN reader
│   ├── qc_altitude.m                 # Despike + quality flags
│   ├── qc_echosounder.m             # Altitude QC + tilt masking
│   ├── altitude_to_bedlevel.m        # Altitude → bed level change
│   ├── plot_altimeter_echosounder.m  # Quicklook visualization
│   └── run_mop511_pipeline.m         # Legacy single-site example (reference only)
├── metadata/
│   └── deployments.csv               # Deployment table (all sites)
└── processed/                        # Output directory (gitignored)
    ├── SouthSIOPier/
    ├── TorreyPines/
    └── SolanaBeach/
```

> **`outputs/` is a symlink** to `~/LocalData/Scripps/Research/Altimeter_Pipeline/outputs` (outside iCloud sync, excluded from Time Machine; 2026-09-22). Paths resolve normally; the canonical copy is on reefbreak.

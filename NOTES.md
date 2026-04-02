# Altimeter & Echosounder Processing Pipeline

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
| Torrey Pines | MOP586 | 5, 7, 10 m | Jul 2024 -- Jun 2025 | AA400 | `.BIN` (binary) |
| Solana Beach | MOP654 | 7 m | Nov 2024 -- Feb 2026 | AA400 | `.BIN` (binary) |

Raw data lives on the lab server at: `/Volumes/group/Altimeter_data/`

Subdirectories: `SouthSIOPier/data/`, `TorreyPines/`, `SolanaBeach/`

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

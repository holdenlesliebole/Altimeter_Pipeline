# Altimeter Pipeline — Deployment Database Overview

**Prepared for:** Brian Woodward, Bill O'Reilly
**Date:** April 6, 2026
**Purpose:** Document all altimeter and echosounder deployments processed through the pipeline.

---

## What This Document Covers

The Altimeter Pipeline ingests raw data from Echologger AA400 altimeters (RangeLogger .log files) and EA400 echosounders (.BIN binary files), applies phase-space despiking, tilt correction, and burst averaging to produce quality-controlled bed level time series. This document summarizes **every deployment** processed so far: **47 instrument-deployments across 3 sites and 8 deployment groups**.

---

## Master Instrument Table

### South SIO Pier (MOP511, 6m depth) — AA400 Altimeter Only

Monthly swaps, continuous 2 Hz or burst-mode sampling. Sequential baseline anchoring (same-day swaps, offsets typically <30 mm).

| Config | Label | Sensor ID | Date Range | Sampling | Bursts | Valid | IQR (mm) | Notes |
|---|---|---|---|---|---|---|---|---|
| SIO24 | MOP511_6m_20240402 | 0208 | Mar 28 -- Apr 23, 2024 | Continuous 2 Hz | 257 | 223 | 4.6 | First deployment (test params) |
| SIO24 | MOP511_6m_20240423 | 0208 | Apr 23 -- May 31, 2024 | 300 samp/30 min | 1531 | 1525 | 5.1 | |
| SIO24 | MOP511_6m_20240531 | 0208 | May 31 -- Jul 11, 2024 | 300 samp/30 min | — | — | — | |
| SIO24 | MOP511_6m_20240711 | 0208 | Jul 11 -- Aug 13, 2024 | 300 samp/30 min | — | — | — | |
| SIO24 | MOP511_6m_20240813 | 0207 | Aug 13 -- Sep 19, 2024 | 300 samp/30 min | — | — | — | |
| SIO24 | MOP511_6m_20240919 | 0127 | Sep 19 -- Oct 28, 2024 | 300 samp/30 min | — | — | — | |
| SIO24 | MOP511_6m_20241028 | 0207 | Oct 28 -- Nov 19, 2024 | 300 samp/30 min | — | — | — | |
| SIO24 | MOP511_6m_20241119 | 0127 | Nov 19 -- Dec 20, 2024 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20241220 | 0207 | Dec 20, 2024 -- Jan 23, 2025 | 300 samp/30 min | — | — | — | PST |
| SIO25 | MOP511_6m_20250123 | 0130 | Jan 23 -- Mar 10, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250310 | 0060 | Mar 10 -- Apr 17, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250417 | 0130 | Apr 17 -- May 21, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250521 | 0127 | May 21 -- Jun 25, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250625 | 0130 | Jun 25 -- Jul 21, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250721 | 0207 | Jul 21 -- Aug 21, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250821 | 0130 | Aug 21 -- Sep 24, 2025 | 300 samp/30 min | — | — | — | |
| SIO25 | MOP511_6m_20250924 | 0207 | Sep 24 -- Oct 31, 2025 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20251031 | 0130 | Oct 31 -- Nov 26, 2025 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20251126 | 0207 | Nov 26 -- Dec 22, 2025 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20260105 | 0130 | Jan 5 -- Jan 22, 2026 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20260122 | 0207 | Jan 22 -- Feb 26, 2026 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20260226 | 0130 | Feb 26 -- Mar 26, 2026 | 300 samp/30 min | — | — | — | |
| SIO26 | MOP511_6m_20260326 | 0207 | Mar 26 -- present | 300 samp/30 min | — | — | — | Most recent |

*23 deployments, all processed successfully. 2-year continuous record.*

### Torrey Pines (MOP586) — Multi-Depth, AA400 + EA400

| Config | Label | Depth | Type | Sensor ID | Date Range | Bursts | Valid | Notes |
|---|---|---|---|---|---|---|---|---|
| TP24 | MOP586_5m_20240214 | 5m | AA400 | 0127 | Nov 13, 2023 -- Feb 14, 2024 | 11941 | 8491 | Firmware Error-3 after ~113 days. 1472 burst-level spikes removed. Dec 28 storm: +700mm accretion. |
| TP24 | MOP586_7m_20240213 | 7m | AA400 | 0128 | Nov 13, 2023 -- Jan 19, 2024 | — | — | Recovered early |
| TP24 | MOP586_10m_20240213 | 10m | AA400 | 0130 | Nov 13, 2023 -- Feb 13, 2024 | — | — | Clean record |
| TP24 | MOP586_15m_20240213 | 15m | AA400 | 0131 | Nov 13, 2023 -- Feb 13, 2024 | — | — | Very stable (±50mm) |
| TP24 | MOP586_5m_20240725 | 5m | EA400 | — | Jul 25 -- Nov 5, 2024 | — | — | Echosounder .BIN |
| TP24 | MOP586_7m_20240725 | 7m | EA400 | — | Jul 25 -- Nov 7, 2024 | — | — | Echosounder .BIN |
| TP24 | MOP586_10m_20240725 | 10m | EA400 | — | Jul 25 -- Aug 18, 2024 | 1719 | 1649 | Stopped after ~1 month |
| TP24 | MOP586_15m_20241122 | 15m | AA400 | 0208 | Nov -- Dec 2024 | — | — | Altimeter only at 15m |
| TP25 | MOP586_5m_20241122 | 5m | EA400 | — | Nov 22, 2024 -- Jan 14, 2025 | — | — | Pipe bent 12/22/2024 storm |
| TP25 | MOP586_7m_20241122 | 7m | EA400 | — | Nov 22, 2024 -- Jan 14, 2025 | — | — | |
| TP25 | MOP586_5m_20250114 | 5m | EA400 | — | Jan 14 -- Feb 21, 2025 | — | — | |
| TP25 | MOP586_7m_20250114 | 7m | EA400 | — | Jan 14 -- Feb 21, 2025 | — | — | |
| TP25 | MOP586_10m_20241122 | 10m | AA400 | 0127 | Nov 2024 -- Feb 2025 | — | — | Sensor reassigned from 5m |
| TP25 | MOP586_15m_20241122 | 15m | AA400 | 0128 | Nov 2024 -- Feb 2025 | — | — | Sensor reassigned from 7m |
| TP25 | MOP586_5m_20250325 | 5m | EA400 | — | Mar 25 -- Jun 24, 2025 | 6640 | 6160 | 4 concatenated .BIN files |
| TP25 | MOP586_10m_20250305 | 10m | AA400 | 0207 | Mar 5 -- Jun 9, 2025 | 6883 | 6608 | IQR = 3.8mm (cleanest) |
| TP25 | MOP586_15m_20250305 | 15m | AA400 | 0208 | Mar 5 -- Jun 10, 2025 | — | — | |

*17 deployments across 4 depths, all processed successfully.*

### Solana Beach (MOP654, 7m) — EA400 Echosounder Only

| Config | Label | Type | Date Range | Bursts | Valid | Tilt | Notes |
|---|---|---|---|---|---|---|---|
| SOL24 | MOP654_0m_20240119 | AA400 | Jan 19, 2024 | — | — | — | Early test, depth unknown |
| SOL24 | MOP654_7m_20241122 | EA400 | Nov 22, 2024 -- Jan 14, 2025 | — | — | — | .BIN |
| SOL24 | MOP654_7m_20250114 | EA400 | Jan 14 -- Feb 21, 2025 | — | — | — | .BIN |
| SOL25 | MOP654_7m_20250304 | EA400 | Mar 4 -- Apr 9, 2025 | 2600 | 2110 | 13.2° | Pipe tilted; tilt-deviation QC preserves data |
| SOL25 | MOP654_7m_20250409 | EA400 | Apr 9 -- May 16, 2025 | 2600 | — | — | |
| SOL25 | MOP654_7m_20250516 | EA400 | May 16 -- Jun 21, 2025 | 2600 | — | — | |
| SOL25 | MOP654_7m_20250621 | EA400 | Jun 21 -- Jun 24, 2025 | 348 | — | — | Very short (~3 days) |
| SOL26 | MOP654_7m_20251205 | EA400 | Dec 5, 2025 -- Jan 10, 2026 | — | — | — | |
| SOL26 | MOP654_7m_20260111 | EA400 | Jan 11 -- Feb 16, 2026 | — | — | — | |
| SOL26 | MOP654_7m_20260216 | EA400 | Feb 16 -- Feb 18, 2026 | — | — | 7.7° | Pipe tilted from Feb 7 storm |

*10 deployments, all processed successfully. Pipe physically relocated during re-jetting, creating cross-deployment spatial offsets.*

---

## Summary

| | Count |
|---|---|
| Total deployment groups | 8 |
| Total instrument-deployments | 50 |
| Successfully processed | 47 |
| Skipped (no data / too short) | 3 |
| Sites | 3 (SIO, Torrey Pines, Solana Beach) |
| AA400 altimeter deployments | 31 |
| EA400 echosounder deployments | 19 |
| Unique sensor IDs (AA400) | 8 (0060, 0127, 0128, 0130, 0131, 0207, 0208) |

### Validation Against Beach Surveys

| Site | Surveys at depth | Within-deployment RMSE | Notes |
|---|---|---|---|
| SIO Pier 6m (MOP511) | 14 | — | Survey-anchored (10/23 deployments directly anchored). Note: LatLon2MopxshoreX maps to MOP513; must override to MOP511. |
| Torrey Pines 10m | 9 | 61 mm | Best-validated depth |
| Solana Beach 7m | 27 | 22 mm (within deployment) | Pipe relocation inflates cross-deployment RMSE |
| Torrey Pines 5m | 11 | Poor in Apr 2024 (firmware) | Good elsewhere |
| SIO Pier | 0 | N/A | No subaqueous surveys (permit restrictions) |

### Known Data Issues

1. **Torrey Pines 5m, Apr 2024**: Firmware Error-3 corrupted ~30% of bursts. Two-level phase-space despike recovers most of the signal but survey validation shows ~700mm discrepancy during this period.
2. **Solana Beach pipe relocation**: Echosounder pipe re-jetted multiple times, causing cross-deployment spatial offsets. Within-deployment accuracy is good (22mm RMSE).
3. **SIO echosounder .log files**: Multi-GB text format too slow for current reader. Altimeter data is primary at SIO; echosounder data not processed.
4. **EA400 backscatter**: SSC inversion assessed and ruled out (no correlation with wave energy). Backscatter useful for bed detection and qualitative visualization only.

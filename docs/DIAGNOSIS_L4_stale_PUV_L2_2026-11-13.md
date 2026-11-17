# DIAGNOSIS (2026-11-13): Torrey L4 carries PUV values from the pre-October L2

Status: diagnosis only. Nothing was rebuilt, nothing on reefbreak was read or changed, and the
proposed fix below is not applied. The decision is HLB's.

## Finding

`L4_TP_{5,7,10,15}m.mat` were built on 2026-08-24. The PUV L2 they copy from was rebuilt on
2026-10-12/14 (PUV_Pipeline combined rebuild, `docs/catalog_changes/2026-10-13_combined_rebuild.md`).
That rebuild included PUV_Pipeline commit `d95012c` (2026-10-09), which changed every L2 gap fill
from `fillmissing(x,'linear')` to `fillmissing(x,'linear','EndValues','nearest')`. The old default
(`EndValues='extrap'`) extended a straight line through the last two good samples across a NaN run
at a segment edge. After `detrend`, that ramp dominated the segment's velocity.

`build_L4_site.m` does no arithmetic on these fields. `getL2` and `getL2sub` (lines 198 to 214)
copy `L2.(field)(matchSegIdx)`, and lines 246 and 266 to 269 write `Ub` and the `vmom` moments. The
merge is correct for the L2 it read. The mismatch is staleness: L4 holds the August L2 values, and
nothing in L4 records which L2 build it read, so nothing flags the difference.

## Reproduction on one row

Row: TP 15 m, TOR25S, L4 time 2025-04-06 09:18:14 UTC, matched to L2 segment 761 (midpoint
09:29:59). The segment has 636 NaN samples of 7200, with a trailing NaN run of 614 samples (307 s)
and no leading run.

The segment was rebuilt from `PUV_Pipeline/outputs/L1/TOR25S/MOP586_15m_processed.mat` with the L2
steps: hour alignment, shore-normal rotation at 264.5 deg (from the L2 `prov.json`), fill,
`detrend`, `bed_velocity_ifft`, `compute_velocity_moments`. Only the fill rule changes between the
two runs.

| fill rule | Ub (m/s) | u_uabs2 (m³/s³) | max abs detrended u (m/s) |
|---|---|---|---|
| `'linear'` (pre-2026-10-09) | 13.5387 | 6776.83 | 72.75 |
| `'linear','EndValues','nearest'` (current) | 0.0556 | -3.06e-5 | 0.19 |
| L4 as stored | 13.5387 | 6776.83 | |
| current L2 as stored | 0.0556 | -3.06e-5 | |

Both runs match their target to every printed digit. The script (`repro_one_row.m`) and the count
script below are in the shared session notes folder
(`~/Library/Application Support/Claude/side-session-notes/local_f160b547-2a7c-43e5-b542-d5f5139a6eba/L4_stale_L2_diagnosis/`),
which is not durable. The recipe above is enough to rebuild them.

## Affected rows

Each L4 row with `puv_valid` and a finite `Ub` was compared with the current L2 `Ub` of the same
deployment's nearest segment (15 min tolerance, as in the build). The criterion was set before
running: moved if the relative difference exceeds 1 %, gross if L4/L2 exceeds 2. `Ub` is used
because it is rotation-invariant. The October heading and declination changes therefore cannot
move it, while they can move `u_uabs2` and `skewness`.

Altimeter bursts are about 20 min apart, so most PUV hours appear in two L4 rows.

| station | deployment | L4 rows checked | rows moved > 1 % | rows gross > 2x | L2 hours moved | max L4/L2 |
|---|---|---|---|---|---|---|
| 5 m | TOR23W | 2177 | 2 | 0 | 1 | 1.22 |
| 5 m | TOR24S | 2944 | 2 | 0 | 1 | 1.07 |
| 7 m | TOR23W, TOR24S, TOR24W | 3463 | 0 | 0 | 0 | 1.00 |
| 10 m | TOR23W, TOR24S | 2581 | 0 | 0 | 0 | 1.00 |
| 10 m | TOR24W | 1382 | 1 | 0 | 1 | 1.03 |
| 10 m | TOR25S | 3130 | 30 | 20 | 15 | 30.8 |
| 15 m | TOR23W | 1190 | 4 | 2 | 4 | 28.7 |
| 15 m | TOR24W | 1582 | 0 | 0 | 0 | 1.00 |
| 15 m | TOR25S | 3132 | 12 | 10 | 6 | 244 |

In total, 51 L4 rows (28 PUV hours) moved, and 32 rows are gross. Every moved row is in a deployment
and depth where the October rebuild changed L2. All other rows agree within 1 %, most to rounding.

Against the morphology_ml altimeter screen (`morphology_ml/experiments/deep_transport_map/altimeter.py`,
line 47), 37 of the 51 rows fail the screen and are dropped. These are the 20 merge-made rows of
`spike_origin.csv`, which lists one row per PUV hour. The other 14 rows pass the screen and enter
that analysis with a stale Ub between 1.01 and 1.78 times the current L2 value:

- 5 m: 4 rows
- 10 m: 7 rows
- 15 m: 3 rows

Their moments are stale too.

Only the 15 m 2025-04-06 row was rebuilt from L1. That the other 50 rows have the same cause is an
inference: they are the rows that moved, the 20 in `spike_origin.csv` have 130 to 660 NaN samples
per segment in L1, and no other change in the October rebuild touches a rotation-invariant
velocity statistic. The edge-gap run length of each segment was not checked one by one.

## What else inherits the stale values

Each field below is copied or derived from the same matched segment, so it is stale on the same
rows:

- L2 copies: `Ub`, `tau_b`, `Aw`, `skewness`, `asymmetry`, `u_abs3`, `u_uabs2`, `TKE`, `uMean`,
  `vMean`
- Derived from `L4.Ub`: `Ub_combined`, `tau_b_combined`, `Aw_combined`, `shields_combined`
- `Ub_calibration`: the per-site MOP fit includes the stale rows. Its effect on the gap-filled
  MOP rows was not measured.
- `Hs`, `Fb` and the other L3 copies: by the PUV changelog, the fill fix moved L2 Hs by at most
  3.5 cm on this catalog. These were not checked here.

Not checked: `L4_SIO_6m.mat` and `L4_SOL_7m.mat`, which were built the same night and read L2
rebuilt in the same release; and the reefbreak copy of these L4 files, which `NOTES.md` names as
canonical.

## Proposed fix (not applied)

1. **Rebuild the six L4 files** with `run_L4.m` against the current L2. One choice comes first. The
   PUV code has changed since the October L2 build: `T_b` replaced the bed-stress period
   (2026-11-05), and the Swart amplitude correction landed (2026-11-11). The TOR L2 files on disk
   are still the October build, and `build_L4_site` calls `bed_stress_ks` itself for
   `tau_b_combined`. HLB needs to decide whether the TOR L2 is rebuilt before L4, so that L4 is not
   rebuilt twice.
2. **Stamp the parent L2 into L4.** For each PUV deployment read, store the L2 `prov.build_id` and
   `file_sha256`, using PUV_Pipeline's `read_prov`, in an L4 provenance field.
3. **Add a staleness check,** next to `check_L4_grainsize_current.m`. It would compare those stamps
   against the live L2 sidecars and fail on any mismatch, with a break test: point one stamp at a
   wrong `build_id` and watch it fire. This is the check whose absence let the August L4 outlive
   its L2 by a month.
4. **Until the rebuild,** L4 consumers should not use L4's PUV fields where a current L2 or L1 is
   available, as the deep_transport_map step 2 already does. If they must use L4 values, they
   should drop the 51 rows listed by `count_stale.m`.

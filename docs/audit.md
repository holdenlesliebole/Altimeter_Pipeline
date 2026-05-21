# Altimeter_Pipeline — Audit / Known Issues

## ISSUE-001: Timezone inconsistency between altimeter (.log) and echosounder (.BIN) bed-level times

**Status:** OPEN — diagnosed 2026-05-20, fix pending (next focused effort).
**Severity:** HIGH. Corrupts the PUV–altimeter merge (L4) wherever the two
instrument types are chained together; affects all sites (SIO/TP/SOL).
Bed-level / elevation values themselves are unaffected (they come from the
altimeter chain); the damage is to the PUV-derived wave fields and their
time alignment.

### Symptom

The chained L3→L4 bed-level record mixes two inconsistent time bases.
`outputs/L4/L4_SOL_7m.mat` matched **2,683 bursts to deployment `NN24`**
(a non-Solana site) and **zero bursts to `SOL23`** (the actual co-located
PUV for the Jan-2024 Solana altimeter). The echosounder portions matched a
UTC-ish PUV; the altimeter portion was mis-routed.

### Evidence (temperature cross-correlation vs co-located PUV)

Method: cross-correlate instrument temperature (naive) against co-located
PUV `Tmean` (UTC, tz-stripped) on an hourly grid. Same physical quantity,
so the lag at peak correlation is a pure clock offset. (Reusable; the
scripts were `/tmp/verify_alt_tz.m` and `/tmp/verify_echo_tz2.m`.)

| Instrument | Deployment | vs PUV | Peak lag | r | Implied frame |
|---|---|---|---|---|---|
| AA400 altimeter (.log) | Solana MOP654 Jan 2024 | SOL23 | **+8 h** | 0.995 | local PST (UTC−8) |
| EA400 echosounder (.BIN) | Solana MOP654 Mar 2025 | SOL25A | **−7 h** | 0.975 | ≈ UTC+7 |

The two are ~15 h apart. PUV L2 times are tz-aware UTC.

### Root cause (code-verified)

- **`read_echosounder_bin.m`** (line 117) reads the `.BIN` timestamps with
  `datetime(..., 'ConvertFrom','posixtime','TimeZone','UTC')` — correct,
  posix is UTC by definition. But lines 120–121 then do
  `t = t + hours(opts.TimeOffsetHours)` (offset = 7/8 from the config),
  **double-counting** — the already-UTC times get pushed to UTC+offset.
  Line 125 strips the zone. Result: echosounder output ≈ UTC+7/+8.
- **`read_rangelogger_log.m`** (lines 93–94) reads the `.log` timestamp
  string and sets `t.TimeZone = ""` with **no offset applied**. The `.log`
  string is in local Pacific (instrument clock), so output stays local.
  No conversion to UTC is ever done.

So the two readers err in *opposite* directions: the echosounder adds an
offset it shouldn't (its source is already UTC), and the altimeter omits
the offset it needs (its source is local).

### Key clarification (re: "were the instruments set to the same clock?")

The deployment notes do not record the clock convention, so a full
verification sweep was run (2026-05-20): for every altimeter/echosounder
L1 deployment with a co-located PUV, cross-correlate instrument
temperature vs the highest-correlation PUV `Tmean` (UTC). Results below.

- **EA400 `.BIN` is UTC intrinsically** — posix timestamps are UTC
  regardless of the instrument's display-clock setting; the reader then
  wrongly adds the offset.
- **AA400 `.log` clock convention CHANGED over time** — the Nov-2023
  campaign set clocks to local Pacific; 2024-onward deployments used UTC.
  So there is no single altimeter rule; the fix is per-deployment.

#### Verified PER-FILE offset map (cross-correlation, r > 0.6; finalized 2026-05-20)

The shift is BETWEEN raw files (clock reset at the Feb-2024 service), not
within a file — confirmed by reading the TP 5m raw files separately
(file1 Nov2023–Feb13 = local; file2 Feb27–May = UTC). So the correction is
**per raw `.log` file**. The complete map (offset = hours to ADD to raw →
UTC):

**Local PST → +8 (the 5 original Nov-2023 files only):**
- `20240214_162515_..._0127.log` (TP 5m)   — lag +8, r 0.99
- `20240119_151750_..._0128.log` (TP 7m)   — lag +8, r 0.88
- `20240213_150935_..._0130.log` (TP 10m)  — lag +8, r 0.99
- `20240213_164124_..._0131.log` (TP 15m)  — lag +8, r 0.99
- `20240119_162029_..._0207.log` (Solana 7m) — lag +8, r 1.00

**UTC → 0 (every other altimeter `.log` file):** all post-service TP
file-2's (`20240513/0813/0814`, lag 0 r 0.59–0.98), all TP 2024+
(`2025*`), and all SIO (lag 0, r up to 0.99 where a PUV overlaps;
no-PUV files are all 2024+ and follow the same UTC pattern → 0).

**Echosounders:**
- `.BIN` (EA400, SOL + TP Phase 2+): posix is UTC → **0** (the reader was
  wrongly adding +7/+8). Set all `.BIN` deployment offsets to 0.
- `.log` (EA400, SIO text): raw is `#TimeLocal` → keep **+7/+8** (the reader
  correctly adds it). Not currently in processed outputs (Eall empty), but
  set correctly for any future reprocess.

NOTE: TP Phase 1 deployment labels each chain TWO files with DIFFERENT
offsets (`[+8, 0]`), so `tz_offset_hours` must be per-FILE, not a single
scalar per deployment.

Caveats: (1) Deployments with no co-located/overlapping PUV could not be
verified directly; infer their offset from the same-instrument pattern
(e.g. SIO gaps → UTC; un-paired `.BIN` echosounders → over-offset).

#### TODO-1 RESOLVED (2026-05-20): SIO `.log` echosounders are tz-correct
`read_echosounder_log.m` parses a `#TimeLocal` header (raw = local) and
**does** add `TimeOffsetHours` (lines 108-109) → local + offset = UTC.
So the `.log` echosounder path is correct, unlike the `.BIN` path.
Separately, **0 of 23 SIO L1 files actually contain echosounder data**
(`Eall` empty) despite the config listing `.log` files — the SIO
echosounders are not in the current processed outputs (a processing gap
to flag, but not a tz issue and not corrupting any L4).

#### TODO-2 finding (2026-05-20): altimeter clock shifts WITHIN the Nov-2023 records
The DST check revealed something bigger than DST: the Nov-2023 altimeter
records read **local PST in winter and UTC from ~spring on**. Confirmed
two independent ways on the TP 5m Nov-2023 record:
- Cross-correlation vs UTC PUV: winter +8 (r 0.99), summer 0 (r 0.98).
- PUV-independent diurnal temperature peak (naive hour): winter peaks at
  18h (local afternoon → local clock); summer peaks at 23h (local
  afternoon +~8h → UTC clock; strong 1.26°C signal).
A single clock cannot drift 8 h, so this is a **mid-deployment clock
reset**: these "deployments" are two concatenated `.log` files (original
+ a spring/summer post-service redeployment), and the clock was evidently
reset to UTC at the service to match the new 2024+ convention.

**Consequence:** the altimeter correction is **per raw `.log` file**, not
per deployment-label. Each original Nov-2023 file = local (+8); each
post-service file = UTC (0). The per-deployment table above is therefore
necessary but not sufficient — the `MOP586_*_20240213/14` rows must be
split at their file boundary. Needs the individual `.log` file date
ranges and (ideally) Holden's service/clock-reset logs to pin the split.
The verify sweep should be re-run **per raw file** (not per chained
deployment) to map every file's convention before reprocessing.

### Fix plan (for the next focused effort)

1. **Per-deployment verification.** [DONE 2026-05-20 — see "Verified
   offset table" above.] Confirmed the altimeter convention is NOT
   uniform (Nov-2023 = local PST, 2024+ = UTC) and all `.BIN`
   echosounders are over-offset. Still TODO: the SIO `.log` echosounders
   and the post-March tail of the Nov-2023 altimeters (DST check).
2. **Adopt one canonical convention:** define `tz_offset_hours` as
   "hours to ADD to the raw instrument time to get UTC," and make BOTH
   readers apply it (currently `read_rangelogger_log` ignores it and the
   echosounder readers apply it). Then set each deployment's value from
   the verified table:
   - Nov-2023 local altimeters → **+8**
   - 2024+ UTC altimeters (SIO, TP redeploys) → **0**
   - all `.BIN` echosounders (posix already UTC) → **0**
   This makes `read_echosounder_bin.m` stop double-offsetting and
   `read_rangelogger_log.m` correctly convert the local Nov-2023 clocks.
   (Earlier idea of America/Los_Angeles DST-aware tagging is rejected:
   fixed per-deployment offsets are correct because the instrument clocks
   were set once and don't auto-DST. The only residual risk is a Nov-2023
   deployment whose span crosses the Mar-2024 DST change being ~1 h off
   in its post-March tail; the DST check in step 1's TODO settles it.)
3. **Decide one canonical frame: UTC throughout** (matches the PUV
   pipeline, which now emits tz-aware UTC).
4. **Reprocess** all deployments (L1→L3) and **rebuild** all L4 products
   (SIO/TP/SOL) via `run_L4.m`.
5. **Verify** the rebuilt L4 matches each altimeter/echosounder burst to
   its correct co-located PUV (e.g., Solana bursts → SOL23/24/25, never
   NN24), and that PUV match counts rise sharply.

### Related items to fix in the same pass

- **`run_L4.m` has no Solana section** — `L4_SOL_7m.mat` was built by a
  manual `build_L4_site` call that isn't in the codebase. Recovered params:
  `siteName='SolanaBeach'`, `depths=7`, `pvuLabel="MOP654_7m"`,
  `anchorMethod='survey'`, `instrumentLat=32.99064`,
  `instrumentLon=-117.27897`, `mopStation="D0654"`,
  `pvuDeployments={'SOL23','SOL24','SOL25A','SOL25B'}` (explicit list
  avoids a separate latent bug — see next item). Codify this so Solana L4
  is reproducible.
- **`build_L4_site.m` PUV auto-discovery is unsafe.** With an empty
  `pvuDeployments`, it scans *all* PUV deployments (all sites) and matches
  by time only — which is how Solana bursts got matched to `NN24`. Once
  times are consistent, still prefer explicit per-site `pvuDeployments`
  lists (or filter by site/location) so cross-site mismatches can't happen.
- **`metadata/deployments.csv` is a legacy parallel registry.** The
  config registry (`config/deployment_registry.m` → `TP24_config.m` etc.,
  via `run_all_and_plot.m`) is authoritative and produced the current
  outputs. Either retire the CSV or keep it generated from the configs.

### Resolved sub-items (2026-05-20, committed `bad8066`)

- Solana Jan-2024 altimeter depth confirmed **7 m** (field notes
  `DeploymentNotes2023-2024.xls` row 73, S/N 207, MOP654.5; co-located
  SOL23 PUV) — was logged as depth-0/"unknown". Config/CSV/NOTES corrected.
- TP24 Phase 1 depths (5/7/10/15 m from sensor IDs 0127/0128/0130/0131)
  and the Nov-2023 start date confirmed against the same field notes.

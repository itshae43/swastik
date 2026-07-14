# Why the Hostinger server spikes to ~100% (and how to fix it)

> Diagnosis of the CPU/load spikes seen when **both** the Admin and Staff devices
> are running. Ranked by impact. Each item has the **file + line**, the **reason**,
> why **two devices make it worse**, and the **fix**.
>
> Generated: 2026-07-14

---

## TL;DR

There are two kinds of load stacking on top of each other:

1. **A constant background hum** — both apps poll several endpoints every few
   seconds, forever. Two devices ≈ double the hum.
2. **A giant CPU spike on every transaction write** — saving/editing/deleting a
   transaction triggers a balance recalculation that loops **~7,000 times**, each
   doing a database write. This is what pushes an already-busy server to 100%.

The spike (cause #1 below) is the real problem. Fix that first.

---

## 🔴 Cause #1 (critical): Balance recalc loops ~7,000× on every write

**File:** `Backend/src/server.ts`
**Function:** `recalculateDailyBalances()` — line **731**
**The bug:** lines **814–818**

```ts
const current = new Date(Date.UTC(yyyy, mm - 1, dd)); // starts at the OLDEST txn date
const end = new Date(new Date().getTime() + istOffset); // ← wall-clock "today"
end.setUTCHours(0, 0, 0, 0);

while (current.getTime() <= end.getTime()) {   // loops ONE DAY at a time
  ...
  await DailyClosingBalance.findOneAndUpdate(  // ← a DB write EVERY iteration
    { date: dateStr }, { ... }, { upsert: true, new: true }
  );
  current.setUTCDate(current.getUTCDate() + 1);
}
```

### Why it's so expensive
Your app stores every transaction date in **year 2007** (an intentional
time-shift — see `TimeUtils.to2007` in the mobile app; the notification code
converts it back with `toRealWorld`). So:

- `current` (oldest transaction) ≈ **2007-xx-xx**
- `end` (`new Date()`) ≈ **2026-xx-xx**

The loop therefore walks **every single day from 2007 to today ≈ 7,000 days**,
and does **one `await` database upsert per day → ~7,000 sequential DB writes.**

This runs:
- **on every** `POST /api/transactions` (line **1134**)
- **on every** `PUT /api/transactions/:id` (line **1166**)
- **on every** `DELETE /api/transactions/:id` (line **1189**)
- **on every server startup** (line **105**, `await recalculateDailyBalances()`)

So a single "save transaction" tap = ~7,000 round-trips to MongoDB. Node is
single-threaded; while it serialises/deserialises 7,000 writes and waits on the
DB, the event loop and the DB connection pool are saturated → **CPU 100%**.

### Why two devices make it dramatically worse
While that 7,000-write storm is running (a few seconds), **both** apps keep
firing their every-12s polls. Those requests **queue up behind the storm**,
each also hitting the DB, so the spike is amplified and sustained instead of a
quick blip. One writer + two pollers = compounding.

### The fix (safe, high impact)
The loop only needs to produce balance rows **up to the last day that actually
has a transaction** — nothing changes after that, and the "latest row" (current
totals) is identical either way. So bound `end` to the newest transaction's
date instead of wall-clock now:

```ts
// Instead of end = new Date() (≈2026), stop at the latest transaction date.
// txsFromStart is already sorted ascending by date, so its last element is newest.
const lastTxDate = txsFromStart.length
  ? txsFromStart[txsFromStart.length - 1].date
  : startUTC;
const end = new Date(lastTxDate.getTime() + istOffset);
end.setUTCHours(0, 0, 0, 0);
```

That turns ~7,000 iterations into "only the days you actually traded" — for a
single incremental write it drops to a **handful**. Same correct result, ~1000×
less work. (I can make this change for you — it's ~3 lines.)

> Confirm the scale first with one query in the Mongo shell / Atlas:
> `db.dailyclosingbalances.countDocuments()` — if it's in the **thousands**,
> this is confirmed as your #1 cause.

---

## 🟠 Cause #2: Full balance history sent on every poll

**File:** `Backend/src/server.ts` — `GET /api/daily-balances` line **872**

```ts
const balances = await DailyClosingBalance.find().sort({ date: 1 }); // whole collection
```

Because of Cause #1, this collection has **~7,000 rows**, and the Statement /
Ledger screens re-download all of them every 12s per device. Fixing Cause #1
shrinks this collection dramatically. (The Home summary cards were already moved
to the lightweight `GET /api/daily-balances/latest`, which returns 1 row.)

**Fix:** do Cause #1 first (shrinks the data), then optionally have the Statement
screen request a date range instead of the full history.

---

## 🟠 Cause #3: The profile-list endpoint *writes* on every read — polled every 5 s

**File:** `Backend/src/server.ts` — `GET /api/user-profiles` (search `app.get('/api/user-profiles'`)

This endpoint runs **two `UserProfile.updateMany(...)` writes every time it is
read**, and the app polls it **every 5 seconds per logged-in device** (mobile:
`auth_providers.dart` ~line 150). With admin + staff that's ~24 write-bearing
reads/minute just for session housekeeping.

### Why two devices make it worse
It's per-device: 1 device ≈ 12 writes/min, 2 devices ≈ 24 writes/min — all doing
`updateMany` scans.

**Fix:** make the read read-only (delete the two `updateMany` calls). The exact
same cleanup already runs in the **60-second cron** at the bottom of the file
(`setInterval(... 60 * 1000)`). Optionally slow the 5 s poll to 15–30 s, or drive
it off the existing SSE `profiles_updated` event.

---

## 🟡 Cause #4: Everything is polling, and it never stops

**Files (mobile):**
- `core/services/transaction_service.dart` — `transactionsStream` (12 s)
- `core/services/party_service.dart` — `partiesStream` (12 s)
- `core/services/reminder_service.dart` — `getReminders` (12 s)
- `core/services/appointment_service.dart` — `getAppointments` (12 s)
- `features/auth/providers/auth_providers.dart` — session poll (5 s)

Each open screen keeps polling in an infinite loop, foreground or not. Two
devices = double the request count hitting `authenticate` (line **941**), which
runs a DB lookup on **every** request.

**Fixes (from `SERVER_LOAD_OPTIMIZATION_GUIDE.md`):**
- Pause polling when the app is backgrounded / the screen isn't visible
  (`autoDispose` providers + a `WidgetsBindingObserver`).
- Replace polling with the **SSE channel you already have** (`GET /api/events`):
  broadcast a `data_changed` event on writes so clients refetch only when
  something actually changed, instead of every 12 s.
- (Home was already moved to server-side windowed fetching, so it no longer
  pulls the whole transaction table every poll.)

---

## 🟡 Cause #5: Full recalc blocks server startup

**File:** `Backend/src/server.ts` — line **105**: `await recalculateDailyBalances();`

On every boot/restart the server runs the **full** ~7,000-iteration recalc before
it's fully ready. If Hostinger restarts the process (deploy, crash, memory
limit), you get a startup spike. Fixing Cause #1 makes this cheap; you could also
run it non-blocking (drop the `await`) or only when the collection is empty.

---

## Suggested order of attack

| Priority | Fix | Effort | Effect |
|----------|-----|--------|--------|
| 1 | **Bound the recalc loop** (Cause #1) | ~3 lines | Removes the 100% write-spike — the main event |
| 2 | **Make `GET /api/user-profiles` read-only** (Cause #3) | small | Removes ~24 write-reads/min |
| 3 | Pause polling when backgrounded (Cause #4) | medium | Cuts the idle hum |
| 4 | SSE-driven refetch instead of polling (Cause #4) | larger | Removes most polling entirely |
| 5 | Startup recalc non-blocking (Cause #5) | tiny | Smoother restarts |

**Doing #1 alone will most likely stop the 100% spikes.** Everything else lowers
the steady-state baseline.

---

## Quick reference — file + line

| Concern | Location |
|---------|----------|
| Recalc loop (the spike) | `Backend/src/server.ts:731`, loop bound at `:814–818`, DB write at `:847` |
| Recalc triggered on writes | `Backend/src/server.ts:1134`, `:1166`, `:1189` |
| Recalc on startup | `Backend/src/server.ts:105` |
| Full balance history endpoint | `Backend/src/server.ts:872` |
| Profile read-that-writes | `Backend/src/server.ts` — `GET /api/user-profiles` |
| Per-request auth DB lookup | `Backend/src/server.ts:941` |
| Expiry cron (already exists) | `Backend/src/server.ts:1315` |
| 5 s session poll (mobile) | `Mobileapp/lib/features/auth/providers/auth_providers.dart:~150` |
| 12 s list polls (mobile) | `Mobileapp/lib/core/services/*_service.dart` |

# Server Load Optimization Guide (Swastik)

> **Purpose:** A read-only analysis of every API call the mobile app makes, *why*
> the server is loaded, and *where* batch loading / pagination and other fixes
> apply. **No code was changed** — this is a map so you can decide what to do.
>
> Generated: 2026-07-14

---

## 1. TL;DR — The one thing that is killing your server

Your problem is **not really "everything loads at startup".** It is worse than
that: **every logged-in device downloads the *entire* database, over and over,
forever, every ~12 seconds** — even while the user is doing nothing.

There is **no pagination and no server-side filtering** anywhere. When you press
"Today" on the home page, the app still downloads **all** transactions ever made
and then throws away everything except today on the phone. The "Today / Week /
Month / All" buttons are a *client-side* filter over a full download.

So the fix you intuited — *"batch resize 10, 12, 15 entries, load the next
batch when I press something"* — is exactly right. Below is where and how.

---

## 2. How the app talks to the server (polling model)

Every list in the app is backed by an **infinite polling loop**, not a real-time
stream. Pattern (from `transaction_service.dart`, `party_service.dart`,
`reminder_service.dart`, `appointment_service.dart`):

```dart
Stream<...> xStream() async* {
  while (true) {
    final res = await http.get(Uri.parse('$baseUrl/<collection>')); // FULL collection
    yield parse(res);
    await Future.delayed(const Duration(seconds: 12));               // repeat forever
  }
}
```

Key consequences:
- The loop runs **as long as the provider is alive**, independent of whether the
  screen is visible or the app is in the foreground.
- Each cycle fetches the **whole collection** (no `limit`, no date range, no
  `partyId` filter on the server).
- Providers are **not `autoDispose`**, so once a screen is opened its loop tends
  to keep running in the background.

---

## 3. Full inventory of API calls

### 3.1 Continuous background polling (this is the load)

| # | Endpoint | Called from | Interval | Returns | Server work per call |
|---|----------|-------------|----------|---------|----------------------|
| 1 | `GET /api/transactions` | `transactionsStream` (home, ledger, statement) | **12 s** | **Entire** transactions collection, sorted | `Transaction.find().sort({date:-1})` — grows forever |
| 2 | `GET /api/transactions` | `partyTransactionsStream` (party detail) | **12 s** | **Entire** collection, then filtered **on the phone** by partyId | Same full scan, index unused |
| 3 | `GET /api/parties` | `partiesStream` (home, ledger, parties, entries) | **12 s** | Entire parties collection | `Party.find().sort({updatedAt:-1})` |
| 4 | `GET /api/daily-balances` | `dailyBalancesStream` (home, statement) | **12 s** | Entire daily-balance collection (1 row/day) | `DailyClosingBalance.find()` |
| 5 | `GET /api/reminders` | `remindersStream` + `getPartyReminders` | **12 s** | Entire reminders collection (party version filtered **on phone**) | `Reminder.find()` |
| 6 | `GET /api/appointments` | `appointmentsStream` | **12 s** | Entire appointments collection | `Appointment.find()` |
| 7 | `GET /api/user-profiles` | Auth session poll (`auth_providers.dart`) | **5 s** | All profiles | **Runs 2 `updateMany` WRITES on every read** (see §5) |

### 3.2 Short-burst polling

| Endpoint | Called from | Interval | Notes |
|----------|-------------|----------|-------|
| `GET /api/user-profiles` | Device verification screen | **2 s** | Only while the "waiting for approval" screen is open |
| `GET /api/events` (SSE) | Admin, after verify | persistent | **A real-time channel already exists** — but only used for `profiles_updated` |

### 3.3 On-demand writes (fine — not the problem)

`POST/PUT/DELETE /api/transactions`, `/parties`, `/reminders`, `/appointments`,
`/user-profiles/*` (request-access / approve / decline), `POST /api/verify`,
`DELETE /api/devices/:id`. These fire only on user action.

> Note: `POST/PUT/DELETE /api/transactions` each also kick off
> `recalculateDailyBalances()` in the background. That is already incremental
> (good), so writes are not your bottleneck.

---

## 4. The math (why it feels "loaded at start")

Per **logged-in device**, while idle, the continuous loops generate roughly:

| Loop | Requests/min |
|------|--------------|
| transactions (12 s) | 5 |
| parties (12 s) | 5 |
| daily-balances (12 s) | 5 |
| reminders (12 s) | 5 |
| appointments (12 s) | 5 |
| user-profiles (5 s) | 12 |
| **Total per device** | **≈ 37 requests/min, forever** |

With 5 active devices (admin + staff) that is **~185 requests/min continuously**,
and several of those (transactions especially) return the **entire growing
table** each time. Startup feels worst because **all loops fire their first
request at once** and each pulls a full collection — but the load never really
stops, it just becomes a steady flood.

---

## 5. Bonus bug worth fixing while you're here

`GET /api/user-profiles` (server.ts ~line 336) performs **two `updateMany`
writes on every single read**:

```ts
await UserProfile.updateMany({ status:'pending_approval', requestedAt:{$lt:...}}, ...);
await UserProfile.updateMany({ sessionActive:true, expiresAt:{$lt:now}}, ...);
```

This endpoint is polled **every 5 seconds per logged-in device**. So you are
doing write transactions ~12×/min/device just to *read* a profile list. **The
same cleanup already runs in the 60-second cron** at the bottom of `server.ts`
(`setInterval(... 60*1000)`). The per-read writes are redundant — the read
endpoint can be made read-only and rely on the cron.

---

## 6. The optimization plan (prioritized)

Ordered by **impact ÷ effort**. Each is independent — you can do them one at a
time.

### ⭐ Priority 1 — Paginate + server-filter `GET /api/transactions` (your "batch resize")

This is the change you described. Two halves:

**A. Server accepts filters and a batch size.** Add query params:
```
GET /api/transactions?partyId=<id>&from=<iso>&to=<iso>&limit=15&skip=0
```
Build the Mongo query from whatever params are present, e.g.:
- `partyId` → `{ partyId }`  (uses the existing `{partyId:1,date:-1}` index)
- `from`/`to` → `{ date: { $gte, $lte } }`  (uses the `{date:1}` index)
- `.limit(limit).skip(skip)` for batching
- Optionally return `{ items, total }` so the UI knows if more exist.

**B. Home page requests only what the filter needs.**
- "Today" → send `from=startOfToday&to=now` (tiny result).
- "This Week / Month" → send that date range.
- "All" → request in **batches of 10–15** with `skip`/`limit`, and load the
  next batch on scroll (infinite scroll) or a "Load more" button. This is
  literally the "press All → see a batch → next batch loads" behaviour you want.

Today the filter (`_selectedTableFilter` in `home_screen.dart`) runs *after* a
full download. Move that filter to the server URL and the payload collapses from
"whole table" to "one batch."

> The DB indexes for this already exist (`Transaction.ts` lines 42–43), so the
> server side is mostly query-building — the heavy lifting is already indexed.

### ⭐ Priority 2 — Give party views their own filtered endpoint

`partyTransactionsStream` and `getPartyReminders` currently download the **whole**
collection and filter on the phone. Add `?partyId=` support to
`GET /api/transactions` (done in P1) and `GET /api/reminders`, then have the party
screens request only that party. Instantly cuts payloads on every party detail
open, and finally uses the `{partyId:1,date:-1}` index.

### ⭐ Priority 3 — Stop polling when nothing is visible

- Make the list `StreamProvider`s **`autoDispose`** so leaving a tab kills its
  loop instead of polling in the background.
- Add a `WidgetsBindingObserver` to **pause all polling when the app is
  backgrounded** and resume/refetch on resume. Idle-in-pocket devices should
  send **zero** requests.
- Only the currently-open screen should poll. (Home shouldn't keep polling
  reminders + appointments + party lists that aren't on screen.)

### ⭐ Priority 4 — Replace polling with the SSE channel you already have

You already run an SSE endpoint (`GET /api/events`) and a
`broadcastProfilesUpdated()` helper. Extend the same pattern: when a transaction/
party/reminder/appointment is created/updated/deleted, `broadcast` a
`data_changed` event. Clients then **refetch only when something actually
changed**, instead of every 12 s. Combined with P1/P2, each refetch is also just
one small batch. This is the biggest structural win — most 12 s polls return
identical data and are pure waste.

If full SSE is too big a step, a cheaper interim version: a lightweight
`GET /api/changes?since=<ts>` that returns `{ changed: true/false }` (or just
the changed IDs), so the poll is a few bytes instead of a full table.

### ⭐ Priority 5 — Make `GET /api/user-profiles` read-only + slow its poll

- Remove the two `updateMany` writes from the read handler (see §5); the 60 s
  cron already covers expiry.
- The 5 s auth session poll can be driven by SSE (`profiles_updated` already
  exists) or slowed to 15–30 s. Session expiry is coarse-grained (8 PM IST /
  10 min), so 5 s precision is unnecessary.

### Priority 6 — Trim payloads (projection)

List views don't need every field. Use `.select(...)` / projection to return
only what the list renders (party name, amount, type, date). Smaller JSON =
less bandwidth and less parse time on the phone.

### Priority 7 — Align + jitter the intervals

If you keep any polling, stagger the loops so all devices don't hit at the same
instant, and consider a longer base interval (20–30 s) for slow-changing lists
(parties, appointments, daily-balances).

---

## 7. Quick reference — where each thing lives

| Concern | File |
|---------|------|
| All list/GET endpoints | `Backend/src/server.ts` |
| Transaction indexes | `Backend/src/models/Transaction.ts` (42–43) |
| Redundant writes on read | `Backend/src/server.ts` ~336–376 |
| Expiry cron (already exists) | `Backend/src/server.ts` ~1202 |
| SSE channel (already exists) | `Backend/src/server.ts` ~1186 + `broadcastProfilesUpdated` ~36 |
| Transactions polling loop | `Mobileapp/lib/core/services/transaction_service.dart` |
| Parties polling loop | `Mobileapp/lib/core/services/party_service.dart` |
| Reminders polling loop | `Mobileapp/lib/core/services/reminder_service.dart` |
| Appointments polling loop | `Mobileapp/lib/core/services/appointment_service.dart` |
| Auth 5 s session poll | `Mobileapp/lib/features/auth/providers/auth_providers.dart` (~150) |
| Home filter (client-side today) | `Mobileapp/lib/features/home/presentation/screens/home_screen.dart` (`_selectedTableFilter`) |
| Stream providers | `features/ledger/providers/transaction_providers.dart`, `features/parties/providers/party_providers.dart`, `features/reminders/providers/*` |

---

## 8. Suggested order of attack

1. **P1** — paginate/filter transactions (biggest payload, your batch idea). 
2. **P3** — autoDispose + background pause (stops idle floods, low effort). 
3. **P5** — fix the read-that-writes profile endpoint (easy, removes hidden writes). 
4. **P2** — party-scoped endpoints. 
5. **P4** — SSE-driven refetch (removes polling entirely; do last, biggest change).

Doing just **P1 + P3 + P5** will likely cut your steady-state server load by an
order of magnitude, because idle devices stop pulling full tables every few
seconds.
```

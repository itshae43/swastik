# Swastik — Senior Architecture & Optimization Review

**Reviewed by:** Senior Architect (Flutter / Backend / DB / DevOps / Security)
**Scope:** Full project read — `Backend/` (Node + Express + TypeScript + Mongoose) and `Mobileapp/` (Flutter + Riverpod).
**Context assumed:** Internal accounting app, 2–3 devices today, ~20 users future. Priority = simplicity, reliability, low maintenance. **NOT** public SaaS.

> This file is analysis + recommendations only. **No code was changed.** Everything below is optional guidance, ranked by real value for *your* scale. Where I say "avoid," it means adding it would be wasted effort for a 2–20 user internal app.

---

## 1. Overall Architecture Score: **6 / 10**

For a 2–3 device internal tool, this is a **working, shipped, reasonable** system — that alone earns a passing grade. It loses points on **three things that will actually bite you**, not on theoretical purity:

1. **3-second polling of entire collections** (transactions, parties, balances) from every device — wasteful and the root of most perf cost.
2. **Party balances mutated from the Flutter client** (read-all → compute → PUT) — this is a real correctness/race risk with 2+ devices and is the most dangerous thing in the codebase for an *accounting* app.
3. **Two sources of truth for money** (client-computed dashboard totals **and** the server `DailyClosingBalance` collection **and** stored `party.cashBalance`) that can silently drift.

The good news: your data model is basically sound, the app clearly works, and none of the fixes require a rewrite or any new infrastructure. This is a "tighten 5 things" situation, not a "redo the architecture" situation.

**What NOT to do:** Do not add Kubernetes, microservices, Kafka, Redis, GraphQL, a state-management migration, Clean Architecture layers, or a caching tier. At your scale every one of those is pure overhead. I explicitly recommend against all of them below.

---

## 2. Folder Structure Review

### Flutter — **Good, keep it**
```
lib/
  constants/        api_config.dart
  core/             models, services, utils, widgets   (shared)
  features/         auth, entries, home, ledger, navigation,
                    parties, reminders, settings        (feature-first)
```
This is **feature-first with a shared `core/`** — the correct, industry-standard Flutter layout. Keep it as-is.

**Problems (small):**
| Problem | Why it matters | Fix | Impact |
|---|---|---|---|
| Loose files at `lib/` root: `items_widget.dart`, `deviceinfo.dart` (27 & 41 lines, look like scratch/leftovers) | Clutter, unclear ownership | Move into a feature or `core/`, or delete if dead | Low |
| `constants/api_config.dart` **and** `core/utils/constants.dart` both define `baseUrl` | Two places to edit when the URL changes; easy to update one and miss the other | Keep `ApiConfig` as the single source; have `AppConstants.baseUrl` just append `/api` (it already does — fine, but document that `ApiConfig` is the *only* thing to edit) | Low |

### Backend — **Needs light structure**
```
Backend/src/
  server.ts         ← 1,203 lines: connection, seeding, ALL routes,
                       middleware, cron, balance engine — everything
  models/           (clean, good)
  *.ts scripts      (import/export/inspect one-offs)
```
**Problem:** `server.ts` is a single 1,200-line file holding every route, the auth middleware, the balance-recalculation engine, and a cron loop.

**Why it matters:** Not "unscalable" — it's *hard to navigate and easy to break*. Editing one endpoint means scrolling past everything.

**Suggested solution (simple, no framework):** Split into a handful of files by responsibility — this is a 1-hour refactor, no new dependencies:
```
src/
  server.ts          // connect + middleware + app.listen only
  routes/
    parties.ts  transactions.ts  userProfiles.ts  devices.ts  misc.ts
  middleware/auth.ts // authenticate + requireAdmin
  services/balances.ts // recalculateDailyBalances + helpers
  cron.ts            // the setInterval auto-logout
```
**Impact: Medium** (maintainability only — behavior identical). Do NOT introduce NestJS or a DI container to achieve this. Plain file splitting is enough.

---

## 3. Flutter Review

**Stack:** Flutter + **Riverpod 3** (`Notifier`/`StreamProvider`), `google_fonts`, `http`, `pdf`/`printing`, `flutter_local_notifications`. Sensible, minimal dependency set. Keep it.

**Architecture pattern:** Effectively **MVVM** — `StreamProvider`/`Notifier` (ViewModel) → `Service` (data) → screens (View). This is the right pattern for Flutter. Keep it.

### High-value issues

**3.1 — 3-second polling loops re-fetch entire collections (biggest issue)**
`transaction_service.dart`, `party_service.dart`, `reminder_service.dart`, `appointment_service.dart` all use:
```dart
Stream<...> ... async* {
  while (true) {
    final res = await http.get('.../transactions');  // fetches ALL
    yield list;
    await Future.delayed(Duration(seconds: 3));       // forever
  }
}
```
- **Problem:** Every device re-downloads *all* transactions, *all* parties, and *all* daily balances every 3 seconds, 24/7, whether or not anything changed, whether or not the screen is visible.
- **Why it matters:** Constant battery/data drain, constant server load, and it drives the expensive server-side recalculation below. At 3s it also feels laggy (up to 3s to see a change) *and* wasteful at the same time — worst of both.
- **Suggested solution (pick one, both simple):**
  - **Easiest:** raise the interval to **10–15s** and only poll the screens currently mounted (Riverpod `autoDispose` already stops the stream when no widget listens — make sure these providers are `autoDispose` so background screens stop polling). This alone cuts load ~4–5×.
  - **Better, still simple:** you already run an **SSE endpoint (`/api/events`)** on the backend for profile updates. Reuse that pattern: have the server emit a `data_changed` event on transaction/party writes, and have the client re-fetch **once** on that event instead of every 3s. This gives near-instant updates with almost zero idle traffic.
- **Impact: High.**
- **Avoid:** WebSockets library, Firebase, or a sync framework — SSE (which you already have) is enough.

**3.2 — Client computes and writes party balances (correctness risk)**
`transaction_service.dart` `createTransaction` does: `GET /parties` (all) → find party → recompute `cashBalance/goldBalance/diamondBalance` in Dart → `PUT /parties/:id` → then `POST /transactions`.
- **Problem:** This is a **read-modify-write with no atomicity**. If two devices post transactions for the same party close together, one update overwrites the other → **wrong balance**. Also, if the `POST /transactions` fails after the `PUT` succeeds, the balance is now wrong with no matching transaction (the code even swallows the PUT error and continues).
- **Why it matters:** This is accounting. A silently wrong party balance is the worst-case bug for this app, and it's *reachable today* with 2 active devices.
- **Suggested solution:** Move balance mutation to the **server**, inside the same request that creates the transaction, using an atomic operator:
  ```js
  // in POST /api/transactions, after saving the tx:
  await Party.updateOne({ _id: partyId }, { $inc: { cashBalance: delta, goldBalanceGrams: gDelta, ... } });
  ```
  `$inc` is atomic — no read-modify-write race, no full `/parties` download, no lost updates. The client just posts the transaction.
- **Impact: High.**

**3.3 — Two sources of truth for money**
The dashboard (`home_screen.dart` build) recomputes cash/online/gold/diamond by looping **all transactions on every rebuild**. Meanwhile the server maintains `DailyClosingBalance`, and each `Party` stores `cashBalance` etc.
- **Problem:** Three independent computations of the same numbers. They can disagree (e.g. `metalOut` handling differs between client dashboard, `transaction_service`, and the server recalc — the client `createTransaction` treats `sale/purchase/return_` types that the server's recalc does **not**). Divergence in an accounting app erodes trust in the whole tool.
- **Suggested solution:** Pick **one** authority. For your scale the simplest correct choice: **server computes, client displays.** Keep `DailyClosingBalance` (or a small `/api/summary` endpoint) as the single number source; delete the client-side dashboard loop. Ensure the credit/debit rules are defined in exactly one place.
- **Impact: High** (correctness + trust).

**3.4 — `home_screen.dart` is 6,402 lines**
- **Problem:** One file holds the dashboard, tablet layout, recent transactions, filters, entry sheets, and more. Hard to edit safely; large `build()` methods rebuild a lot.
- **Why it matters:** Maintenance risk and rebuild cost. The dashboard total loop (3.3) runs on *every* rebuild of this giant widget.
- **Suggested solution:** Extract widgets into `features/home/presentation/widgets/` (balance grid, recent list, each bottom sheet). Move the total calculation out of `build()` into a memoized provider so it doesn't recompute on unrelated rebuilds. Pure mechanical splitting — no logic change.
- **Impact: Medium.**

**3.5 — Two parallel data layers**
`lib/services/api_service.dart` (a clean centralized client) exists but is only used by `user_profiles_provider`; the other services (`transaction_service`, `party_service`, etc.) each re-implement `http` calls + `_getHeaders()`.
- **Problem:** Duplicated header logic and error handling; `ApiService` looks like an intended standard that was half-adopted.
- **Suggested solution:** Either route all services through `ApiService`, or delete `ApiService` and keep the per-service style — just pick one. Not urgent.
- **Impact: Low.**

**3.6 — Memory leaks / rebuilds:** The `while(true)` streams never terminate unless the provider is disposed. Confirm the stream providers are `autoDispose` (or `ref.onDispose` cancels the loop) so leaving a screen stops the polling. Otherwise streams accumulate. **Impact: Medium.**

---

## 4. Backend Review

**Stack:** Express 4 + Mongoose 8, plain TypeScript. Minimal, appropriate. Keep it. **Do not** migrate to Nest/Fastify/GraphQL.

### Issues

**4.1 — `GET /api/daily-balances` runs a FULL recalculation on every call**
```js
app.get('/api/daily-balances', async (req,res) => {
  await recalculateDailyBalances();   // deletes & rebuilds the WHOLE collection
  ...
});
```
And the client polls this every 3 seconds.
- **Problem:** Every 3s, per device, the server reads **all** transactions, loops day-by-day from the first transaction to today, and upserts every daily balance — then the *next* poll throws it away and does it again. This is by far the heaviest thing the backend does, and it's triggered constantly for no reason.
- **Why it matters:** Pure waste that grows with history. It also makes reads slow and can spike Mongo (Atlas free/shared tiers especially).
- **Suggested solution:** The `GET` should **just read** the collection:
  ```js
  const balances = await DailyClosingBalance.find().sort({ date: 1 });
  ```
  You already recalc **incrementally** on every transaction write (`recalculateDailyBalances(savedTx.date)` in POST/PUT/DELETE) — that keeps the collection correct. The GET does not need to recalc at all. Remove the `await recalculateDailyBalances()` from the GET.
- **Impact: High** (this is the single easiest big win).

**4.2 — Inconsistent authorization across endpoints**
Only `/api/transactions` uses the `authenticate` middleware. `/api/parties`, `/api/reminders`, `/api/appointments`, `/api/daily-balances`, `/api/user-profiles`, `/api/devices` are **wide open** — no auth at all.
- **Problem:** Anyone who can reach the server can read/modify all parties, balances, and profiles without any device check. Your ledger is protected; the customer list and balances are not.
- **Suggested solution:** Apply `authenticate` to all data routes (parties, reminders, appointments, daily-balances read). Keep `requireAdmin` only where you already have it (transaction edit/delete). One line per route.
- **Impact: Medium** (internal network lowers risk, but it's a cheap, real fix).

**4.3 — `setTimeout` for request expiry is lost on restart**
`request-access` schedules a `setTimeout(..., 300000)` to revert `pending_approval` → `inactive`.
- **Problem:** If the server restarts within those 5 minutes, the timer is gone and the request could hang as pending. (Your 1-minute cron and the on-read cleanup in `GET /user-profiles` mostly cover this — so it's belt-and-suspenders, not broken.)
- **Suggested solution:** Rely on the existing cron/on-read cleanup and drop the per-request `setTimeout`. Fewer moving parts.
- **Impact: Low.**

**4.4 — No input validation layer & inconsistent responses**
Endpoints trust `req.body` (e.g. `new Transaction(req.body)`, `new Party(req.body)`). Responses vary: sometimes `{error}`, sometimes the raw document, sometimes `{success, message}`.
- **Problem:** Bad/edge input can create malformed records; clients must handle several response shapes.
- **Suggested solution:** For your scale, skip a validation framework. Just add a few manual guards on the money endpoints (numbers are numbers, `type`/`paymentMode` are in an allowed set) — Mongoose `enum` on `type`, `paymentMode`, `metalType` gives you most of this for free in the schema. **Avoid** Zod/Joi/class-validator unless you find yourself writing lots of manual checks.
- **Impact: Medium** (data integrity).

**4.5 — Dead code / drift**
- `seedAdmin()` is defined but never called (comment says seeding disabled) — safe to delete.
- Unreachable `res.json(...)` after `return res.status(404)` in `DELETE /api/devices/:id`.
- The Flutter `TransactionModel` sends `createdBy`/`updatedBy`, but the Mongoose `Transaction` schema has no such fields → **Mongoose silently drops them**. Your "who created this entry" audit data is being thrown away. If you want it, add `createdBy`/`updatedBy` to the schema.
- **Impact: Low–Medium** (the audit-field drop is worth fixing if you rely on it).

---

## 5. MongoDB Review

**Collections:** `Party`, `Transaction`, `UserProfile`, `Admin`, `Reminder`, `Appointment`, `DailyClosingBalance`. For an accounting app this normalization is **correct and appropriately simple**. Nothing needs merging or splitting for your scale.

### Recommendations

**5.1 — Missing indexes (do this)**
| Collection | Add index | Why |
|---|---|---|
| `Transaction` | `{ partyId: 1, date: -1 }` | Ledger/party views and the balance recalc filter by party & sort by date. Without it, every party ledger is a full collection scan. |
| `Transaction` | `{ date: 1 }` | `recalculateDailyBalances` queries `date >= X` and sorts by date. |
- **Impact: Medium now, High as history grows.** Two `schema.index(...)` lines. Cheap.

**5.2 — `DailyClosingBalance` value is questionable**
- **Problem:** It's a materialized daily summary, but (a) the dashboard doesn't even use it — the client recomputes totals itself (3.3), and (b) the GET was recomputing it every call (4.1). So it's currently *cost without benefit*.
- **Suggested solution:** Decide its role. If you adopt **4.1 + 3.3** (server is the single authority, client displays), then `DailyClosingBalance` becomes genuinely useful — keep it, read-only. Otherwise it's redundant and could be dropped. Don't keep it *and* compute on the client.
- **Impact: Medium.**

**5.3 — Duplicate / dead fields**
- `Party.silverBalanceGrams` exists but the app only handles gold & diamond — dead field. Remove or actually support silver.
- Party stores denormalized `cashBalance` etc. **and** every transaction stores `partyName`/`partyPhone` (denormalized copies). Denormalizing name/phone onto transactions is actually **fine and good** here (keeps historical statements stable if a party is renamed) — keep it. Just be aware `party.cashBalance` is a cache that must be kept correct (see 3.2).
- **Impact: Low.**

**5.4 — No duplicate-data problem otherwise.** Schema is clean. **Do not** introduce references/`populate` or aggregation pipelines you don't need. Your embedded/denormalized approach is right for this size.

---

## 6. Security Review

Your auth model is **device-identity based**: the client sends `x-android-id` + `x-device-brand` (+ `x-staff-id`) headers; the server matches them against the `Admin` / `UserProfile` collections. **There is no password, no JWT, no refresh token.**

**Verdict for your context:** For 2–3 known physical devices on an internal app, device-binding is a *defensible, simple* choice. You do **not** need JWT, OAuth, or refresh tokens — **avoid adding them**; they'd add real complexity for little gain here. But the current implementation has a few sharp edges worth closing:

| # | Problem | Why it matters | Fix | Impact |
|---|---|---|---|---|
| 6.1 | **Regex injection** — `new RegExp(\`^${androidId}$\`, 'i')` and same for `brand`/`id` put raw client input into a regex | A crafted `androidId`/`brand` can cause ReDoS or unintended matches; it's user input compiled as a pattern | You don't need case-insensitive regex — store IDs normalized (lowercase) and do an exact `$eq` match, or escape the input. Removes the whole class of bug. | **Medium** |
| 6.2 | **Spoofable headers over plain trust** — anyone who learns a valid `androidId`+`brand` can send those headers and *be* that device; nothing is signed | Low risk on an internal network, real risk if the API is internet-exposed (it is: `appapi.swastikjewel.in`) | Minimum: ensure **HTTPS only** (you're on https — good) so headers aren't sniffed. If you want more, add a single shared secret header (`x-api-key`) checked by middleware — one env var, no token infra. | **Medium** |
| 6.3 | **Most endpoints unauthenticated** (see 4.2) | Parties/balances/profiles readable & writable with no device check | Apply `authenticate` to all data routes | **Medium** |
| 6.4 | `.env` handling | `MONGO_URI` lives in `Backend/.env`; **correctly gitignored** (verified: `*.env` in `.gitignore`) — good. Just confirm it was never committed in history and that the deploy host has its own copy. | Rotate the Mongo password if the URI was ever shared/screenshotted | Low |
| 6.5 | `cors()` fully open | Fine for an internal API, but combined with 6.2 it means any origin can call it | Optionally restrict to your app's needs; low priority for a mobile client (mobile apps don't enforce CORS anyway) | Low |
| 6.6 | No rate limiting / `helmet` | A public endpoint with no throttle can be hammered | `express-rate-limit` (1 dependency) on `/api/verify` and `/api/*` is a reasonable, cheap add since the API is internet-facing | Low–Medium |

**Token storage / refresh:** Not applicable — you have no tokens. The "session" is the `UserProfile.expiresAt` window enforced server-side by the 1-minute cron. That's a clean, simple model. **Keep it. Do not add refresh tokens.**

---

## 7. Performance Review

Ranked by actual cost on your system:

| # | Hotspot | Problem | Fix | Impact |
|---|---|---|---|---|
| 7.1 | `GET /daily-balances` full recalc every 3s per device (§4.1) | Reads all tx + rewrites whole collection, constantly | Make GET read-only | **High** |
| 7.2 | 3s polling of full `transactions` + `parties` + `balances` (§3.1) | Constant full-collection downloads from every device | Longer interval + `autoDispose`, or SSE-triggered refetch | **High** |
| 7.3 | Client party-balance read-modify-write (§3.2) | `GET /parties` (all) on every single transaction create/edit/delete | Server-side `$inc`; client stops fetching parties | **High** |
| 7.4 | Missing `Transaction` indexes (§5.1) | Full scans for party ledgers & recalc | Add 2 indexes | **Medium**→High over time |
| 7.5 | Dashboard totals recomputed in `build()` over all tx (§3.3, §3.4) | O(all transactions) on every rebuild of a 6.4k-line widget | Memoize in a provider; or read server summary | **Medium** |
| 7.6 | No pagination on `GET /transactions` | Returns entire history every poll; grows unbounded | Add `?limit`/`?since` when history gets large (not yet urgent) | Low now, Medium later |

**Large payloads:** the transaction list is the main one and it's unbounded — 7.6 addresses it when needed. **Expensive loops:** the day-by-day balance loop is fine *once per write*; the problem is only that it also runs on every read (7.1).

---

## 8. Code Quality Review

**Strengths:** consistent naming, models are clean and typed, the Flutter feature-first layout is disciplined, `ApiException` and timeouts are used, there's an idempotency guard on transaction create (nice touch), and SSE is already wired for live profile updates.

**Weaknesses:**
- **God files:** `home_screen.dart` (6,402), `server.ts` (1,203), `party_detail_screen.dart` (2,564), `statement_screen.dart` (1,987). Split by responsibility (mechanical, no behavior change).
- **Duplicated logic:** credit/debit rules are implemented **three times** (Flutter dashboard, `transaction_service`, server `recalculateDailyBalances`) and they **don't fully agree** (client knows `sale/purchase/return_`; server only knows `receipt/payment/metalIn/metalOut`). This is a latent-bug factory. Centralize the rule in **one** place per side, ideally server-only.
- **Swallowed errors:** `catch (e) {}` in the polling streams and the balance-adjust blocks hides failures (e.g. a failed party PUT is ignored, then the transaction still posts → drift). At least log them.
- **Dead code:** `seedAdmin()`, unreachable `res.json` in device delete, `silverBalanceGrams`, `items_widget.dart`/`deviceinfo.dart` at root.
- **Fallback in-memory DB path** doubles the size of many handlers (every endpoint has an `if (isMongoConnected) {...} else {...}` twin). It's a nice dev convenience but it's ~40% of `server.ts` and a second code path to keep correct. Consider dropping it in production if Mongo is reliably available — big readability win.

---

## 9. Things to REMOVE (or stop doing)

1. **`await recalculateDailyBalances()` inside `GET /api/daily-balances`** — biggest waste. (High)
2. **Client-side party-balance read-modify-write** in `transaction_service.dart` — move to server `$inc`. (High)
3. **One of the three money-total computations** — keep the server one, drop the client dashboard loop. (High)
4. **3-second fixed polling** — replace with longer interval + `autoDispose`, or SSE-triggered refetch. (High)
5. Dead code: `seedAdmin()`, unreachable `res.json`, `Party.silverBalanceGrams`, root `items_widget.dart`/`deviceinfo.dart`. (Low)
6. **Do NOT add** (would be wasted effort at your scale): JWT/refresh tokens, Kubernetes, microservices, Kafka/queues, Redis cache, GraphQL, a DI container, a state-management migration, Clean-Architecture layering, Zod/Joi. Explicitly avoid all of these.

## 10. Things to KEEP

- Feature-first Flutter structure + Riverpod (MVVM). ✅
- Minimal dependency sets on both sides. ✅
- Mongoose models — clean and correctly normalized. ✅
- Device-identity auth model (no passwords/JWT) — right call for 2–3 internal devices. ✅
- Server-enforced session expiry via the 1-minute cron + `expiresAt`. ✅
- SSE `/api/events` for live updates — underused; lean on it more. ✅
- Idempotency guard on transaction create. ✅
- Denormalized `partyName`/`partyPhone` on transactions (stable historical statements). ✅
- The single Express monolith concept (just split the file; don't add a framework). ✅

## 11. Things to IMPROVE

- Split god files (`home_screen.dart`, `server.ts`) by responsibility.
- Centralize credit/debit rules in exactly one place (server).
- Add `Transaction` indexes on `{partyId, date}` and `{date}`.
- Apply `authenticate` to all data routes.
- Add Mongoose `enum`s on `type`/`paymentMode`/`metalType` for free validation.
- Replace regex matching with normalized exact matches (kills regex injection).
- Log swallowed errors instead of `catch {}`.
- Add `createdBy`/`updatedBy` to the `Transaction` schema if you want that audit trail (currently silently dropped).

---

## 12. Immediate Fixes (High Priority)

Do these first — each is small, none needs new tech:

1. **Make `GET /api/daily-balances` read-only** (remove the recalc). *→ instant server-load drop.* (§4.1)
2. **Move party-balance updates to the server with `$inc`**, inside `POST/PUT/DELETE /transactions`; stop the client from GET-all-parties + PUT. *→ fixes the accounting race.* (§3.2)
3. **Single money authority:** server computes totals; client displays. Remove the client dashboard loop; make sure one credit/debit rule set is used everywhere. (§3.3)
4. **Slow the polling** to 10–15s and make the stream providers `autoDispose` (or switch to SSE-triggered refetch using the endpoint you already have). (§3.1)
5. **Add the two `Transaction` indexes.** (§5.1)
6. **Put `authenticate` on all data routes.** (§4.2)

## 13. Future Improvements (Low Priority)

- Split `server.ts` into `routes/ middleware/ services/ cron.ts`.
- Extract widgets out of `home_screen.dart`.
- Add `?since`/`?limit` pagination to `GET /transactions` once history is large.
- Optional `x-api-key` shared secret + `express-rate-limit` on the public API.
- Drop the in-memory fallback DB path from production for readability (keep for local dev only if you like).
- Remove dead fields/files.

---

## 14. Final Architecture Recommendation

**Keep the architecture you have.** It is the *right shape* for an internal 2–20 user accounting app:

> **Flutter (feature-first + Riverpod/MVVM)  →  single Express + Mongoose API  →  MongoDB**, with **device-identity auth** and **SSE for live updates**.

Do not rewrite anything. The entire improvement plan is: **stop doing four wasteful/unsafe things** (read-time full recalc, client-side balance writes, triple total-computation, tight polling), **add two indexes**, and **tighten auth coverage**. That's it. After those changes this becomes a genuinely solid 8/10 system for your scale — simple, cheap to run, and correct.

**The one principle to hold onto:** in an accounting app, **money must have a single source of truth, computed in one place, mutated atomically on the server.** Right now it's computed in three places and mutated from the client. Fix that one thing and you've eliminated the only class of bug that actually matters here.

**Guiding rule for the future:** every time you're tempted to add a technology, ask "does this solve a problem 20 users actually have?" For almost everything on the trendy list, the answer here is no — and this review has told you exactly which ones to skip.

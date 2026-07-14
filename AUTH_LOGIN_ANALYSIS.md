# Swastik — Admin & Staff Login: Root-Cause Analysis & Fix Plan

**Scope:** Why the staff login is fragile (daily 9 PM logout, "shows Active but must re-request", server-restart wipes sessions, poor-internet admin blindness) and exactly how to fix each one — ranked, with a minimal patch vs a proper redesign.

**This document changes no code.** It is a reading brief so you can decide what to implement. Every claim below is traced to a specific file and function in your repo.

---

## 0. TL;DR — the 5 real bugs and their fixes

| # | Symptom you reported | Real root cause | Fix (short) |
|---|---|---|---|
| 1 | Staff logs out **every day at 9 PM**, must re-request daily | `expiresAt` is hard-set to **9 PM IST** on approval (and only **+10 min** if approved after 9 PM) | Decide the session policy on purpose: business-hours OR sliding/heartbeat expiry. Make re-login frictionless (see #2). |
| 2 | After app **restart / phone reboot**, staff sees **"Active"** but is forced to **Send Request again** | The UI computes `isMySession` but **never uses it** — there is no "Resume" button, only "Send Request", which resets the profile to `pending_approval`. Auto-restore also gets thrown away on transient errors. | Add a **Resume Session** path; stop discarding the saved session on network errors. |
| 3 | After **server (Hostinger) restart/crash**, staff must re-request **and admin sees no staff/requests** | The **in-memory fallback DB** silently serves a single hardcoded inactive profile whenever Mongo is momentarily disconnected (incl. every startup window). Clients treat that empty/inactive data as truth and log out. | Remove/neutralize the fallback in production; **return 503 while Mongo is down** so clients retry instead of "logging out". Await Mongo before serving. |
| 4 | **Poor internet → admin doesn't see staff or requests** | The admin's live updates come **only** from SSE (`profiles_updated`). The SSE listener has **no reconnect** and there is **no periodic poll fallback**. One dropped connection = admin is blind until app restart. | SSE **auto-reconnect with backoff + heartbeat**, plus a slow **poll fallback**. |
| 5 | (Underlying) sessions feel flaky / timing is off | Client mixes **server-synced time** (`TimeUtils.now`) with raw **device clock** (`DateTime.now()`); the client **fail-closed** logic + server **fail-open** fallback compound each other. | Use server-synced time everywhere for expiry; make the client fail-safe (only log out on an *explicit* server "invalid"). |

The single most important structural insight:

> **The server "fails open" (serves fake/empty data when the DB is down) while the client "fails closed" (logs out and erases its saved session on any hiccup).** Those two behaviors multiply each other. Every blip — a redeploy, a poor-signal moment, a slow query — becomes a forced logout that requires the admin to re-approve. Fixing that pairing (items #2, #3, #5) is what makes the whole thing feel solid.

---

## 1. How login works today

### 1.1 Two identities

- **Admin** = a physical device whose `androidId` + `brand` exist in the `Admin` collection. Verified by `POST /api/verify`. **Never expires** — the device stays admin until it presses Logout or the row is removed from the DB. *You said this is fine; we keep it.*
- **Staff** = a `UserProfile` row (name + mobile) that an admin **approves** onto a specific device. Governed by a small state machine and an **expiry clock**.

### 1.2 Staff state machine (server: `Backend/src/server.ts`)

```
 inactive ──(POST /request-access)──▶ pending_approval ──(POST /approve)──▶ approved (sessionActive, expiresAt set)
     ▲                                      │                                   │
     │                                      │ (5 min pass, on-read cleanup)     │ (expiresAt reached, 60s cron)
     └──────────────────────────────────────┴───────────────────────────────────┘
                                    back to inactive
```

Key fields on `UserProfile`: `status`, `sessionActive`, `requestedAt`, `lastApprovalTime`, `expiresAt`, `approvedDeviceId` (the device the session is bound to), `pendingDeviceId`.

Relevant server pieces:
- **Approve** (`POST /api/user-profiles/:id/approve`): sets `status='approved'`, `sessionActive=true`, binds `approvedDeviceId = pendingDeviceId`, and computes **`expiresAt`** (see §2.1).
- **Expiry cron** (`setInterval(..., 60*1000)`): every 60 s, any `approved` profile whose `expiresAt <= now` is set back to `inactive` / `sessionActive=false`, and `broadcastProfilesUpdated()` pushes an SSE `profiles_updated`.
- **On-read cleanup** (`GET /api/user-profiles`): also expires stale `pending_approval` (>5 min) and past-due sessions.
- **Session check** (`POST /api/user-profiles/verify-session`): returns `valid:true` only if `approvedDeviceId == androidId` **and** `status='approved'` **and** `sessionActive` **and** `expiresAt > now`.

### 1.3 Staff client flow (Flutter)

- **`AuthNotifier.verify()`** (`lib/features/auth/providers/auth_providers.dart`) runs on every app launch:
  1. Sync server time offset.
  2. If a **saved session** exists in `SharedPreferences` (`staff_session_profile_id` + `staff_session_android_id`) and the android id matches → call `verifyStaffSession()`. If valid → `loginAsStaff()` and done. **Otherwise it clears the saved session.**
  3. Else → `verifyDevice()` (admin check).
- **`loginAsStaff()`**: stores the session, sets a **local logout Timer** at `expiresAt`, and starts a **5-second poll** of all profiles. If that poll ever sees `sessionActive == false` or `status == 'inactive'`, it calls **`logoutLocal()`**, which **erases the saved session**.
- **Admin realtime**: `_startAdminSseListener()` opens `GET /api/events`. On any error it **closes and never reconnects**. There is no periodic re-fetch fallback.
- **Staff request screen** (`device_verification_screen.dart`, `_buildRequestAccessView`): computes `isOtherDeviceSession`, `isPending`, and **`isMySession`**, but the rendered branches only handle *other-device* and *pending*; everything else falls through to the **"Send Request to Access"** button.

---

## 2. Root-cause analysis (per problem)

### 2.1 "Every day at 9 PM the staff logs out / must re-request every day"

**This is by design in the current code — probably not the design you actually want.**

In `POST /api/user-profiles/:id/approve`:

```js
// Expiry Logic: "8 PM IST or 10 mins" (comment) — actually 21:00 IST in code
if (istTime.getUTCHours() < 21) {
  // approved before 9 PM  → expires TODAY at 9:00 PM IST
  expiresAt = today 21:00 IST;
} else {
  // approved at/after 9 PM → expires in 10 MINUTES
  expiresAt = now + 10 * 60 * 1000;
}
```

Consequences:
- **Every session dies at 9 PM IST**, so a staff approved in the morning is logged out at 9 PM → next day they must request again. That is the "logs out every day at 9 PM / re-request daily" behavior.
- **Approved after 9 PM → only 10 minutes.** So evening logins are extremely short-lived; a restart 11 minutes later forces a re-request. This is almost certainly surprising.
- The **comment says 8 PM, the code says 9 PM** — intent is ambiguous and undocumented.

**This is a policy question, not a bug per se.** You must decide the intended lifetime (three sane options in §3.1). Whatever you choose, the pain is mostly that re-login today requires a **full admin re-approval** — which #2 fixes.

---

### 2.2 "After app restart / phone reboot, the staff screen shows Active but they must press Request again"

This is the **worst UX bug** and it has two compounding causes.

**Cause A — the UI has no "Resume" path.** In `_buildRequestAccessView`:

```dart
final isMySession = currentProfile.sessionActive &&
    (currentProfile.approvedDeviceId == null ||
     currentProfile.approvedDeviceId == DeviceIdentity.androidId);
// ...isMySession is COMPUTED but never referenced again.
```

The render logic is: `if (isOtherDeviceSession) {...} else if (isPending) {...} else { Send Request }`.
So when the server still holds a **valid active session for *this very device*** (`sessionActive==true`, `approvedDeviceId==myAndroidId`, `status=='approved'`), the screen shows the green **"Active"** badge (from the profile list) **but the only button is "Send Request to Access."** Pressing it calls `POST /request-access`, which **resets `status` to `pending_approval`** — throwing away the perfectly good session and forcing the admin to approve again.

**Cause B — the automatic restore is too eager to give up.** `verify()` *should* silently resume via `verifyStaffSession()` on launch, so the user never sees the request screen. But it gets discarded in several ordinary situations:

1. **`verifyStaffSession()` swallows *all* errors and returns `null`** (`auth_service.dart`), and `verify()` treats `null` as "invalid" and **clears the saved session**. A single timeout / poor-signal moment on launch = saved session erased, even though the server session is still valid.
2. The **5-second poll inside `loginAsStaff()`** calls `logoutLocal()` (which erases the saved session) the instant it reads `sessionActive==false`. That reading can be a transient blip or the fallback DB (see #3), not a real logout.
3. Any prior forced logout already wiped `SharedPreferences`, so on reboot there is no saved pointer at all → straight to the request screen.

**Net effect:** the server still considers the device logged in, but the client has thrown away its handle and the UI refuses to reclaim it — so the staff is funneled into a re-request that needs admin approval. **Adding a Resume path (uses `isMySession`) + making restore fail-safe removes this entirely.**

---

### 2.3 "After the server restarts (Hostinger crash), staff must re-request and the admin sees no staff/requests"

**Root cause: the in-memory fallback database.** Throughout `server.ts` every handler is written as:

```js
if (isMongoConnected) { /* real DB */ } else { /* fallbackUserProfiles / fallbackAdmins */ }
```

`isMongoConnected` starts **`false`** and only flips true after `mongoose.connect()` resolves. Also, `app.listen()` is called immediately — **the server accepts requests before Mongo is connected.** So there is always a startup window (and any later disconnect) where:

- `GET /api/user-profiles` returns **`fallbackUserProfiles`** — a single hardcoded **inactive** "Shailendra" profile. → The admin's staff list collapses to one inactive row; **all real staff and all pending requests vanish.**
- `POST /verify-session` checks the fallback array → **returns `valid:false`** for a real staff device → the client clears its saved session and logs out.
- `POST /approve`, `/request-access`, etc. mutate the fallback array, and those writes are **lost** once Mongo connects (the real rows never saw them).

Because the client **trusts** this fake data (fail-closed), a redeploy or a brief Atlas hiccup produces exactly your symptom: everyone logged out, admin's staff/requests empty, and staff forced to re-request.

Secondary aggravator: the **per-request `setTimeout(...5min)`** used to revert `pending_approval` is lost on restart (already flagged in the architecture review). It's belt-and-suspenders — the on-read cleanup covers it — but it's one more moving part that behaves inconsistently across restarts.

> Important: MongoDB **does** persist sessions across a server restart. The reason a restart looks like "everything reset" is **not** data loss — it's the fallback serving fake data during the disconnected window, plus clients erasing their sessions in response.

---

### 2.4 "Poor internet: the admin can't see the staff / the requests"

**Root cause: fragile realtime with no fallback.** The admin gets live updates in exactly one way — the SSE stream:

```dart
void _startAdminSseListener() {
  _sseClient!.send(request).then((response) {
    response.stream... .listen(..., onError: (err) {
      _sseClient?.close();          // closes on error
    }, onDone: () { /* nothing */ });   // no reconnect
  }).catchError((err) { /* nothing */ });
}
```

Problems on a poor/unstable connection:
1. **No reconnect.** Mobile networks drop idle connections constantly. Once the SSE stream errors or ends, it is **never reopened** — the admin stops receiving `profiles_updated` forever (until app restart). New staff requests simply never appear.
2. **No heartbeat.** The server never sends keep-alive pings, so proxies (Hostinger/Cloudflare/mobile carrier) silently kill the idle stream and the client may not even notice promptly.
3. **No poll fallback.** `userProfilesNotifierProvider` fetches **once** at build and thereafter relies solely on SSE. If SSE is dead, the admin list is frozen.
4. **Requests can time out.** `getUserProfiles()` under poor signal may throw; the UI keeps the last (possibly empty) state.

So "poor internet" doesn't just slow things down — it **permanently disconnects** the admin from live updates for that app session.

---

### 2.5 Secondary issues worth fixing while you're here

- **Time inconsistency.** You sync a server offset into `TimeUtils.serverOffset`, but `loginAsStaff()` computes the logout timer with **`DateTime.now()`** (raw device clock), and the request countdown uses `DateTime.now()` too. A device with a skewed clock will log out early/late. Use `TimeUtils.now` (server-synced) for all expiry math.
- **`verifyStaffSession` cannot distinguish "invalid" from "unreachable."** Both become `null`. That's the core reason restore is fragile (see #2 Cause B).
- **Polling cost.** While pending, the request screen polls every **2 s**; a logged-in staff polls every **5 s** (full profile list each time). With SSE working, most of this can drop to a slow safety-net poll.

---

## 3. The engineering solution (target design)

Five independent changes. Each stands alone; do them in the order of your pain.

### 3.1 Decide the session-lifetime policy (fixes #1)

Pick one and document it:

- **Option A — Business-hours logout (closest to today).** Keep "expire at closing time," but **remove the 10-minute evening trap** (if approved after closing, expire at *tomorrow's* closing or give a fixed minimum like 2 h). Make closing time a single config constant, not a magic `21`. Re-login next morning is still needed — but #3.3 makes it a **one-tap Resume**, not an admin re-approval, as long as the device is remembered.
- **Option B — Sliding session + heartbeat (best for "don't log me out while I'm using it").** The device sends a heartbeat every N minutes; the server extends `expiresAt` on each heartbeat (e.g., `now + 30 min`). Idle > 30 min → expires. No fixed daily cliff; active users never get kicked. This is the standard "keep-alive session" pattern.
- **Option C — Long fixed session (simplest).** `expiresAt = now + 12h` (or 24h). Predictable, minimal moving parts. Combine with remembered-device Resume so re-login is trivial.

> Recommendation for your scale: **Option C or A** for simplicity, **plus** the Resume path (§3.3). Option B is the "nicest" but adds a heartbeat channel; only worth it if staff routinely stay logged in for long stretches and hate any expiry.

### 3.2 Add an explicit **Resume Session** path (fixes #2, Cause A)

- In `_buildRequestAccessView`, add a branch: **if `isMySession` → show a "Resume Session" button** (not "Send Request"). Tapping it calls `loginAsStaff(currentProfile)` directly — the server already considers this device authorized, so **no admin approval is needed.**
- This single change means: whenever the server still holds a valid session for this device, the staff gets back in with one tap and never resets themselves to `pending_approval`.

### 3.3 Make client session-restore **fail-safe** (fixes #2, Cause B)

- **`verifyStaffSession()` must return three states, not two:** `valid`, `invalid` (server explicitly said so), `unknown` (network/timeout/5xx). Only **clear the saved session on `invalid`.** On `unknown`, keep the saved session and **retry with backoff** (or optimistically restore and let the poll correct it).
- **`loginAsStaff()`'s watchdog poll** should only `logoutLocal()` when the server **explicitly** reports the session ended (an authoritative `sessionActive:false` from a real DB response), never on a fetch error, timeout, or a 503. Add a small **tolerance** (e.g., require two consecutive authoritative "inactive" reads) to survive single blips.
- **Persist enough to Resume without a network call**: keep `profileId`, `androidId`, and `expiresAt` locally. On launch, if `expiresAt` is still in the future, restore immediately and verify in the background.

### 3.4 Kill the fallback / make the server **fail-closed** (fixes #3)

Best (recommended):
- **Await Mongo before serving.** Move `app.listen()` into the `mongoose.connect().then(...)` so the API only accepts traffic once the DB is ready.
- **Remove the in-memory fallback in production** (the architecture review already flagged it as ~40% of `server.ts` and a second code path to keep correct). Keep it only behind an explicit `USE_IN_MEMORY_DB=true` dev flag if you like.
- **While Mongo is disconnected, return `503 Service Unavailable`** from data endpoints instead of fake data. Clients then **retry** instead of "logging out / emptying the list."
- Add Mongoose **reconnection** handling (`connection.on('disconnected'/'reconnected')`) and set `isMongoConnected` accordingly, so a mid-life Atlas blip flips to 503 rather than fake data.

Minimal (if you don't want to delete the fallback yet):
- At minimum, **don't seed a fake "Shailendra" profile** and **don't answer `verify-session`/`user-profiles` from fallback** — return 503 for those two so clients never mistake "DB down" for "you're logged out / no staff exist."
- Drop the per-request `setTimeout` for pending expiry; rely on the cron + on-read cleanup (survives restarts).

### 3.5 Reliable realtime (fixes #4)

- **SSE auto-reconnect with exponential backoff** on the client: on `onError`/`onDone`, wait `1s, 2s, 4s… capped`, then reopen `GET /api/events`. Never leave the stream permanently closed.
- **Server heartbeat:** have `/api/events` write a comment ping (`: keep-alive\n\n`) every ~20–25 s so proxies don't kill the idle stream and the client detects death quickly.
- **Poll fallback for the admin:** a slow timer (e.g., every 30–60 s) that calls `fetchProfiles()` regardless of SSE, so even with SSE dead the admin list refreshes. (You already accept polling elsewhere; this is cheap insurance.)
- **Immediate refetch on reconnect / app-resume:** when SSE reconnects or the app returns to foreground (`AppLifecycleState.resumed`), fetch once so the admin instantly catches up on anything missed while disconnected.
- Optional but ideal: use the standard **`EventSource` semantics** (the browser/`Last-Event-ID` model) — assign event IDs so a reconnect can say "give me what I missed." For your scale, "refetch-on-reconnect" is enough.

### 3.6 Time correctness (fixes #5)

- Replace `DateTime.now()` with `TimeUtils.now` (server-offset-adjusted) in `loginAsStaff()`'s expiry timer and in the request countdown, so a skewed device clock can't cause early/late logout.

---

## 4. Two implementation tiers

You can stop after Tier 1 and already feel most of the improvement.

### Tier 1 — Minimal, high-impact patch (a few hours, low risk)
1. **Resume button** for `isMySession` (§3.2). *Kills the "Active but must re-request" bug.*
2. **Fail-safe restore**: `verifyStaffSession` returns `unknown` on network error; `verify()` and the watchdog poll only log out on an **explicit** invalid (§3.3). *Stops spurious logouts.*
3. **Server: return 503 (not fake data) while Mongo is down**, and **`app.listen` after connect** (§3.4 minimal). *Stops restart from wiping everyone.*
4. **SSE reconnect + admin poll fallback** (§3.5). *Fixes poor-internet admin blindness.*
5. **Remove the evening 10-minute trap** in `approve` and pull the closing time into a named constant (§3.1 Option A). *Removes the surprise short sessions.*

### Tier 2 — Proper redesign (cleaner, more work)
6. **Delete the in-memory fallback** from production; guard behind a dev flag (§3.4 best).
7. Choose **sliding/heartbeat sessions** (§3.1 Option B) if you want "never logged out while active."
8. **SSE heartbeat + reconnect-with-catch-up** on both admin and staff; move staff session-invalidation from the 5 s poll onto SSE, with a slow poll only as a safety net (§3.5).
9. Use **server-synced time everywhere** (§3.6) and drop the per-request `setTimeout` (§3.4).
10. (Optional, security) issue an **opaque session token** on approval, stored on the profile and the device, sent as a header — replaces "trust the raw `androidId`." *Note: the earlier architecture review advises against JWT/refresh-token infrastructure at your scale; a single opaque token is the lightweight middle ground and is optional.*

---

## 5. Suggested order of work

1. **§3.4 server fail-closed** (503 while down + listen-after-connect) — biggest reliability win, backend-only, no app release needed.
2. **§3.2 Resume path** + **§3.3 fail-safe restore** — the daily staff pain; ship together in one app update.
3. **§3.5 SSE reconnect + poll fallback** — fixes poor-internet; app update (+ tiny server heartbeat).
4. **§3.1 lifetime policy** — decide the number; one-line server change.
5. **§3.6 time** and **Tier 2** cleanups when you have breathing room.

---

## 6. Things NOT to do (avoid over-engineering)

- ❌ **Don't add JWT / OAuth / refresh-token infrastructure.** Your device-bound session model is fine; fix its *lifecycle*, not its *shape*. (A single opaque token in §4-#10 is the most you'd want, and it's optional.)
- ❌ **Don't switch SSE to WebSockets / Firebase / a sync framework.** SSE + reconnect + heartbeat is sufficient and you already have the endpoint.
- ❌ **Don't add Redis or a job queue** to hold sessions. Mongo + the 60 s cron already persist and expire sessions correctly once the fallback stops lying.
- ❌ **Don't shorten polling further or add more timers.** The goal is *fewer, smarter* signals (SSE-driven + slow fallback), not more polling.

---

## 7. Reference map — where each fix lives

| Fix | File | Function / anchor |
|---|---|---|
| Session lifetime (§3.1) | `Backend/src/server.ts` | `POST /api/user-profiles/:id/approve` — the `expiresAt` block (`istTime.getUTCHours() < 21 … else now+10min`) |
| Listen-after-connect + 503 while down; remove/guard fallback (§3.4) | `Backend/src/server.ts` | `mongoose.connect().then(...)`, `app.listen(...)`, every `if (isMongoConnected) {…} else {…}`, `fallbackUserProfiles`, `seedUserProfile()` |
| Drop per-request pending timer (§3.4) | `Backend/src/server.ts` | `POST /api/user-profiles/:id/request-access` — the `setTimeout(..., 300000)` |
| SSE heartbeat (§3.5) | `Backend/src/server.ts` | `GET /api/events` |
| Resume path (§3.2) | `lib/features/auth/presentation/screens/device_verification_screen.dart` | `_buildRequestAccessView` — `isMySession` is computed but unused; add a Resume branch calling `authStateProvider.notifier.loginAsStaff(currentProfile)` |
| Fail-safe restore + explicit-invalid-only logout (§3.3) | `lib/features/auth/providers/auth_providers.dart` | `verify()` (saved-session block), `loginAsStaff()` (5 s watchdog poll → `logoutLocal`), `logoutLocal()` (clears prefs) |
| `verifyStaffSession` 3-state result (§3.3) | `lib/core/services/auth_service.dart` | `verifyStaffSession()` (currently returns `null` for both invalid and error) |
| SSE reconnect + poll fallback + resume-on-foreground (§3.5) | `lib/features/auth/providers/auth_providers.dart` | `_startAdminSseListener()` (no reconnect); admin fetch driven only by SSE |
| Server-synced time for expiry (§3.6) | `lib/features/auth/providers/auth_providers.dart` + `device_verification_screen.dart` | `loginAsStaff()` logout timer uses `DateTime.now()`; `_startTimers()` countdown uses `DateTime.now()` → use `TimeUtils.now` |

---

**Bottom line:** none of this needs a rewrite. The staff login is fragile because of one philosophy mismatch — **a server that fakes data when it's unhealthy vs. a client that logs itself out at the first sign of trouble** — plus a **missing "Resume" button** and a **non-reconnecting SSE**. Fix those four things (§3.2, §3.3, §3.4, §3.5) and set the session lifetime on purpose (§3.1), and both admin and staff login become predictable, restart-proof, and tolerant of bad networks.

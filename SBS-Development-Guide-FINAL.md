# 📋 SBS (Schedule Borrowing System) - Claude Development Guide (FINAL — v1)

*Same format as the AI WorkLog Development Guide, built from scratch with the lessons already learned there — decoupled writes, RLS from day one, nullable scoping instead of forced structure, human-confirmation before anything final.*

---

### ✅ Decisions locked in during review

- **Borrowers:** both LGU staff and public citizens, with different verification rules for each.
- **Approval:** always required — no self-serve borrowing, regardless of item.
- **Item ownership:** department scoping is optional (nullable) — unassigned items sit in one shared LGU-wide pool; specific items can be assigned to an owning office later without a schema change.
- **No formal inventory system.** Items are a lightweight, self-growing registry (name + optional distinguishing tag), not a stock-managed catalog — deliberately, since "items" include vehicles and locations, not just countable products.

Nothing here blocks starting Phase 1.

---

## Project Information

**Project Name:** SBS — Schedule Borrowing System
**Version:** v0.1.0
**Platform:** Android first (Flutter) — Windows/Web achievable later on the same codebase, not a v1 target
**Project Type:** Equipment/facility borrowing and reservation system for a Local Government Unit

---

# 🎯 Project Objective

Let LGU staff and the public reserve and borrow municipality-owned items (vehicles, venues, equipment) with a clear, auditable record of who borrowed what, when it's due back, and evidence of its condition at borrow and return. Prevent double-booking. Replace the current informal/paper-based tracking with something both sides can check anytime.

**Non-negotiable principle:** every borrow transaction has a photographic and textual record at both ends (borrow and return) — the system exists specifically to remove "he said, she said" disputes about who had what and what condition it was in.

---

# 👥 Target Users

**Borrowers:**
- LGU staff/employees — reuse their existing account, lower friction, faster approval.
- Public citizens (e.g., barangay residents) — self-register with basic ID verification, since there's no existing employee record to trust.

**LGU side:**
- Approvers/Custodians — LGU staff who review borrow requests, release items, confirm returns, and monitor overdue items. May be scoped to a specific office (the gym's custodian isn't necessarily the same person who manages the motor pool) or unscoped for smaller offices without that distinction yet.

---

# 👤 Roles

Two roles, mirroring AI WorkLog's pattern of keeping roles simple and not forcing structure the org doesn't have yet:

- **Borrower** — requests items, uploads their own photo + acknowledges liability terms at borrow time, sees their own request history and due dates.
- **Approver** — reviews pending requests, approves/rejects, captures evidence at release and return, manages the item registry. Optionally scoped to an owning department (see Items module) — if unscoped, an Approver can act on any unassigned item.

There is no third "Admin" tier for the same reason as AI WorkLog: the person managing items and the person approving requests is very often the same LGU staffer. If a future need arises for a management-only role that doesn't approve, that's a v2 addition — role lives on a membership-style row, not hardcoded, so it costs nothing to leave room for it now.

---

# 🏢 Items Module (no formal inventory — by design)

The explicit design constraint: items include vehicles, venues, and locations, not just countable products, so a rigid inventory (SKUs, stock counts, serial numbers) is the wrong tool and was deliberately excluded.

### items (lightweight, self-growing registry)
- id, name, distinguishing_tag (nullable — e.g. plate number, room number; just enough to tell "Van 1" from "Van 2"), category (free text, optional — no forced taxonomy), owning_department_id (nullable), reference_photo_url (nullable — a photo of the item itself for identification, not condition tracking), active, created_by, created_at

### How this stays lightweight in practice
- No stock counts, no quantities, no SKUs.
- First time an item is borrowed, the requester or approver just types its name. Autocomplete surfaces existing entries so "Multicab" and "multicab" don't become two separate items.
- The registry grows organically from actual use, not from a mandatory upfront cataloging exercise.

### departments (optional ownership — nullable, not required)
- id, name, active, created_at
- `items.owning_department_id` is nullable. Unassigned items are visible/manageable by any Approver. If an office wants exclusive control over its own items later (e.g., only the Motor Pool approves vehicle requests), assign `owning_department_id` — no migration needed, this was designed in from day one specifically because the answer was "not sure yet."

### department_members (only needed once departments are actually used)
- id, department_id, user_id, role (`approver`), joined_at
- Mirrors AI WorkLog's `department_members` pattern for consistency. An Approver with no department memberships can act on any unassigned item; an Approver tied to a department can only act on that department's items plus the unassigned pool (implementation detail to confirm once department scoping is actually turned on).

---

# 🔄 Borrowing Workflow

### Core state machine

```text
pending → approved → released → returned → closed
   ↓
rejected

(approved or released, past due_at, not yet returned) → overdue
```

Every request always requires explicit Approver action to move from `pending` to `approved` or `rejected` — no auto-approval path exists, regardless of item type. This was a deliberate simplification: one state machine, no conditional logic based on item value or borrower type.

### borrow_requests
- id, item_id, borrower_id, borrower_type (`staff` / `citizen`), purpose, requested_from, requested_to, status, approved_by (nullable), approved_at, rejected_reason (nullable), released_at, returned_at, due_at, created_at, updated_at

### Double-booking prevention — enforced at the database level, not just in the app

App-side checks are not enough under concurrent requests (two people tapping "reserve" at the same moment). Use a Postgres exclusion constraint so it's structurally impossible for two *approved* reservations to overlap on the same item:

```sql
create extension if not exists btree_gist;

alter table borrow_requests
add constraint no_overlapping_approved_reservations
exclude using gist (
  item_id with =,
  tsrange(requested_from, requested_to) with &&
) where (status in ('approved', 'released'));
```

**Important:** the constraint only applies to `approved`/`released` requests, not `pending` ones — multiple people can request the same item for overlapping windows, and the Approver resolves the conflict by approving one and rejecting the others. This matches real-world usage: pending requests are just expressions of interest, not locks.

### Citizen verification (first-time only)

Citizen borrowers self-register with: full name, contact number, ID type + ID number + a photo of the ID itself. This isn't checked against any external registry in v1 — an Approver manually verifies it visually against the borrower's photo the first time that citizen's request comes up for approval. Once verified once, subsequent requests from the same citizen move faster (the Approver already trusts the identity).

### citizen_profiles (separate from staff accounts, which reuse the auth system)
- id (user_id), full_name, contact_number, id_type, id_number, id_photo_url, verified (boolean), verified_by, verified_at, created_at

---

# 📸 Evidence & Accountability Module

This is the core value proposition of the whole system — closing the loop that a photo-at-borrow-only design leaves open.

### borrow_evidence
- id, borrow_request_id, stage (`release` / `return`), borrower_photo_url, item_photo_url, condition_notes, captured_by (the Approver present), captured_at

Two rows per completed transaction — one at release, one at return. This is what actually answers "was it damaged before or after I had it," which a single borrow-time photo can't.

### Why photo alone isn't identity

A face photo with no name attached is just "a person's face." Every `borrow_requests` row is already tied to a named, contactable borrower (`borrower_id` → `profiles` or `citizen_profiles`) — the photo is *corroborating* evidence of who physically showed up, not the sole identifier. Never treat the photo as the identity record on its own.

### liability_acknowledgments
- id, borrow_request_id, acknowledged (boolean), acknowledged_at, terms_version
- A simple digital acknowledgment ("I agree to return this item in its original condition by the stated date") captured at release, tied to a versioned terms text so changes to the policy don't retroactively alter what past borrowers agreed to.

### Data privacy note (Philippine Data Privacy Act)

Since this stores borrower photos and ID numbers, add — cheaply, now, rather than retrofitted after an audit:
- A one-line consent statement shown at registration/first borrow ("Your photo and ID will be used solely to verify borrowing transactions and will be retained for [X] months").
- A defined retention period (e.g., 6–12 months) with a scheduled deletion job, rather than indefinite storage.
- Photos stored in Supabase Storage with RLS-equivalent access policies — never publicly readable URLs.

---

# 🔔 Notifications Module

A due date sitting in a database does nothing on its own — this needs to be active, not passive, or SBS just becomes a digitized version of the same problem it's meant to fix.

### notifications
- id, borrow_request_id, type (`request_approved` / `request_rejected` / `due_soon` / `overdue`), sent_at, channel (`push` — v1 scope, SMS/email are later additions)

### Triggers (Supabase Edge Function on a scheduled job, e.g. pg_cron)
- **Approved/Rejected:** immediate push notification to the borrower when an Approver acts.
- **Due soon:** a reminder push (e.g., 24 hours before `due_at`) — configurable later, hardcode one sensible default for v1.
- **Overdue:** the day after `due_at` passes with no `returned_at`, notify both the borrower and the item's Approver(s), and flip `status` to `overdue` for clear visual flagging in both apps.

---

# 🛠 Technology Stack

Consistent with AI WorkLog's stack and the lessons already learned there — one backend to maintain, not two.

**Mobile:** Flutter (Latest Stable), Dart
**Backend:** Supabase (Auth, PostgreSQL, Storage for photos, Edge Functions, pg_cron for scheduled notification jobs)
**State Management:** Riverpod
**Local Storage:** Hive (for viewing cached data offline — see Offline note below)
**Networking:** Dio
**Routing:** GoRouter
**UI:** Material 3

### Offline note — different from AI WorkLog's

AI WorkLog's diary is "write anywhere, sync later" because a diary entry has no dependency on anyone else's state. **Borrowing is inherently a live-availability problem** — approving a reservation or confirming a return only makes sense against the current, real state of the system (is this item still available? has someone else already returned it?). So:
- **Viewing** your own requests, due dates, and history works offline (cached in Hive, same pattern as AI WorkLog).
- **Creating a request, approving, releasing, or returning an item requires connectivity** — these are not queued for later sync, because doing so risks exactly the double-booking and evidence-integrity problems this system exists to prevent. Show a clear "you're offline, these actions need a connection" state rather than silently queuing them.

---

# 🔐 Data Ownership & Security Policy

### Row Level Security

```sql
-- Borrowers can read their own requests
create policy "borrowers read own requests"
on borrow_requests for select
using (auth.uid() = borrower_id);

-- Borrowers can create requests for themselves only
create policy "borrowers create own requests"
on borrow_requests for insert
with check (auth.uid() = borrower_id);

-- Approvers can read/write requests for unassigned items or items in their department
create policy "approvers manage scoped requests"
on borrow_requests for all
using (
  exists (
    select 1 from items i
    where i.id = borrow_requests.item_id
      and (
        i.owning_department_id is null
        or exists (
          select 1 from department_members dm
          where dm.user_id = auth.uid()
            and dm.department_id = i.owning_department_id
            and dm.role = 'approver'
        )
      )
  )
);
```

**API keys / secrets:** no third-party AI provider is required for SBS v1, so this is lighter than AI WorkLog — but if AI-assisted features are added later (e.g., auto-suggesting likely return dates from historical patterns), the same rule applies: secrets live only in Edge Function environment variables, never client-side.

**Photo storage:** Supabase Storage buckets for `borrow_evidence` and `citizen_profiles.id_photo_url` must be private (not public read), accessed only via signed URLs generated server-side, scoped to the requesting user's own evidence or an Approver's scoped items.

---

# 📅 Development Roadmap

## ✅ Phase 1 — Project Foundation
Same as AI WorkLog's Phase 1: Flutter project setup, Riverpod, GoRouter, Dio, theme, folder structure, splash screen, app icon.

## ✅ Phase 2 — Authentication
Connect Supabase Auth. Two paths: staff login (existing account pattern) and citizen self-registration (name, contact, ID type/number, ID photo upload). RLS policies written and tested here, not left implicit.

## ✅ Phase 3 — Items Registry
- Create/search items with autocomplete (no forced categories)
- Optional department assignment per item
- Reference photo upload for an item (identification, not condition)

## ✅ Phase 4 — Borrow Request Flow
- Request form: item selection, date range, purpose
- Double-booking constraint (the Postgres exclusion constraint above) implemented and tested with concurrent request scenarios
- Pending request list for borrowers

## ✅ Phase 5 — Approval Flow
- Approver dashboard: pending requests scoped to their department or the unassigned pool
- Approve/Reject actions with reason capture on rejection
- Citizen identity verification step on first-time approval

## ✅ Phase 6 — Evidence Capture
- Release flow: borrower photo + item photo + liability acknowledgment, captured by the Approver at handoff
- Return flow: borrower photo + item photo + condition notes, captured by the Approver at return
- Evidence viewer: side-by-side release vs. return photos for a given request

## ✅ Phase 7 — Notifications
- Push notification setup (Supabase + a push provider, e.g., FCM)
- Scheduled job (pg_cron + Edge Function) for due-soon and overdue checks
- Overdue status auto-flip and dual notification (borrower + Approver)

## ✅ Phase 8 — Dashboard & History
- Borrower view: active/past requests, due dates, status
- Approver view: items under their scope, current borrow status per item, overdue flags
- Simple calendar view per item showing approved reservation windows

## ✅ Phase 9 — Settings & Data Policy
- Consent statement at registration
- Photo retention policy implementation (scheduled deletion job)
- Data export/deletion request handling, consistent with AI WorkLog's approach to the same requirement

---

# 📌 Milestone Tags

```
v0.1.0 — Initial Flutter Setup
v0.2.0 — Authentication (staff + citizen)
v0.3.0 — Items Registry
v0.4.0 — Borrow Request Flow + Double-Booking Constraint
v0.5.0 — Approval Flow
v0.6.0 — Evidence Capture (release + return)
v0.7.0 — Notifications
v0.8.0 — Dashboard & History
v0.9.0 — Data Policy & Settings
v1.0.0 — Production Release
```

---

# 🧠 Master Prompt for Claude

Use this at the start of every development session:

```
You are a Senior Flutter Software Engineer and Mobile Application Architect.

We are building a production-ready Android application named SBS (Schedule
Borrowing System) for a Local Government Unit — it lets LGU staff and the public
reserve and borrow municipality-owned items (vehicles, venues, equipment) with a
photographic and textual record of the borrow and return, and prevents
double-booking.

Technology Stack:
- Flutter (latest stable), Dart, Material 3
- Riverpod, GoRouter, Dio
- Supabase (Auth, PostgreSQL with RLS, Storage for photos, Edge Functions, pg_cron)
- Hive (for offline viewing of cached data only — see offline rule below)

Core Architectural Rules:
- Every table with user data enforces RLS: borrowers can only read/write their own
  requests; Approvers can only act on items that are unassigned or belong to their
  own department (owning_department_id is nullable — don't force department
  structure where none exists yet).
- Approval is always required for every borrow request. There is no
  self-serve/auto-approve path, regardless of item type.
- Items are a lightweight, self-growing registry — no stock counts, no SKUs, no
  forced categories. Do not build a formal inventory system.
- Double-booking is prevented at the database level with a Postgres exclusion
  constraint on approved/released requests (tsrange overlap check), not just
  app-side validation — this must hold under concurrent requests.
- Every completed borrow transaction has TWO evidence records: one at release
  (borrower photo + item photo + liability acknowledgment) and one at return
  (borrower photo + item photo + condition notes). Never treat a single photo
  as sufficient identity — photos are always paired with a named, contactable
  borrower record.
- Citizen borrowers self-register with ID verification (photo + type + number);
  an Approver manually verifies identity on the first approval only.
- Borrowing actions (create/approve/release/return) require connectivity —
  unlike a diary entry, these depend on live shared state and must not be queued
  offline, since that risks double-booking and evidence-integrity problems.
  Viewing cached history offline is fine.
- Photo storage buckets are private; access only via signed URLs, never public.
- Build one phase at a time. Do not skip steps. Explain your approach before
  writing code.
- Use meaningful commit messages; propose semantic version bumps at the end of
  each phase.
- When a phase is finished, stop and wait for approval before proceeding to the
  next phase.
```

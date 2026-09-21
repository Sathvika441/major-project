# ArecaSmart OTP Verification, Permission Workflow & Phased Onboarding Spec

## Problem Statement

ArecaSmart currently lacks:
1. Secure phone-based OTP verification during login and phone number updates
2. A structured permission request workflow for gallery/camera access tied to the post-auth lifecycle
3. A phased data collection flow that separates core farmer identity verification from detailed farm data entry
4. Karnataka-only location restriction (other states are selectable but irrelevant for this deployment)

## Users

- **Primary users**: Arecanut farmers registering on the platform and updating their profiles
- **Secondary users**: Admins/staff auditing data integrity flows

## Goals

1. Add time-limited (15-min), rate-limited OTP verification that gates login and any phone number change.
2. Prompt gallery + camera permissions with purpose explanation only after successful login/signup; handle grant/denial gracefully.
3. Split onboarding into two strictly ordered phases:
   - Phase A (Onboarding): Core farmer details (name, contact, location, primary agricultural role)
   - Phase B (Post-onboarding): Farm-specific details (land survey number, arecanut variety, soil type)
4. Restrict all location selectors to Karnataka only.

## Non-Goals

- Real SMS gateway integration (mocked/encrypted SMS simulation using local storage + toast log)
- Runtime-permission handling on web
- Backend/cloud changes beyond service/repository tier already in the app
- Plot-related UI restoration (plots remain hidden per project constraints)

---

## Functional Requirements (FR)

### FR1: OTP Verification System

- **FR1.1** — OTP is generated and "sent" via the simulated encrypted SMS channel whenever:
  - a user attempts login (after password validation succeeds)
  - a user submits a phone-number change in Profile Edit
  - a new user signs up (after signup succeeds, before granting access)
- **FR1.2** — OTP is a 6-digit numeric value.
- **FR1.3** — OTP expires 15 minutes after generation; expiry is checked before validation.
- **FR1.4** — Resend rate limit: minimum 2-second cooldown between resends to the same phone.
- **FR1.5** — Verification attempt limit: max 5 wrong OTP entries per session; after that the session is locked for 5 minutes.
- **FR1.6** — Explicit error states for: invalid OTP, expired OTP, mismatched phone, rate-limited, too many attempts.
- **FR1.7** — OTP verification screen shows a countdown timer for resend availability.
- **FR1.8** — After successful verification during login, the user is routed to the next step (onboarding or dashboard).
- **FR1.9** — After successful OTP for a phone-number change, the new phone is persisted and `isPhoneVerified` is set.

### FR2: Permission Request Workflow

- **FR2.1** — Permission request for gallery + camera never runs before login/signup is fully complete (including OTP).
- **FR2.2** — A purpose-explanation dialog appears before system permission prompts, describing:
  - Gallery access: "Required to upload farm and crop photos for records and diagnostics"
  - Camera access: "Required to scan documents and capture live farm/crop images"
- **FR2.3** — If the user grants, mark permissions as granted in local storage and proceed.
- **FR2.4** — If the user denies permanently:
  - Show a fallback explanation message
  - Provide a button to navigate to app settings
  - Continue app access (denial is not a hard block; image-dependent features are disabled with a message)
- **FR2.5** — The permission workflow runs at most once per session (deduplicated via storage flag).

### FR3: Phased Data Collection

- **FR3.1** — Phase A (Onboarding Form) collects only:
  - Full name (mandatory, min 2 chars)
  - Phone number (mandatory, Indian-format)
  - Location: State (fixed Karnataka), District, Taluk, Village (all mandatory)
  - Village field is a searchable/autocomplete dropdown populated from the authoritative `Karnataka_Location_Master.json` master file, with villages aggregated per taluk (hobli sub-grouping ignored/ flattened).
- **FR3.2** — Phase A validates all inputs before persistence.
- **FR3.3** — On Phase A submit:
  - Persist farmer core details under `FarmProfileModel`
  - Mark "Phase A completed" flag in storage
  - Navigate to Phase B (farm details collection)
- **FR3.4** — Phase B (Farm Details Form) collects only:
  - Land survey number (mandatory, format validator for Karnataka survey numbers: e.g., `123`, `12/3`, `12/3A`, `12/3/4`)
  - Arecanut cultivation type (mandatory dropdown: Mangala, Sumangala, Sreemangala, SAS-1, Mohitnagar, Hirehalli Dwarf, Other)
  - Soil type (mandatory dropdown: Red Sandy, Red Loamy, Black Cotton, Laterite, Alluvial, Clay)
- **FR3.5** — Phase B data is linked to the same farmer profile / userId.
- **FR3.6** — Only after Phase B submission is `hasCompletedOnboarding` set to true and user navigates to dashboard.
- **FR3.7** — If a user closes the app during Phase B, they resume from Phase B (not Phase A) on next login.

### FR4: Karnataka-Only Location + Authoritative Village Master

- **FR4.1** — `KarnatakaLocations.states` returns `['Karnataka']` only.
- **FR4.2** — All State dropdowns across onboarding, profile edit, and farm management are disabled (read-only Karnataka), or hidden entirely in favor of a label.
- **FR4.3** — Districts and taluks are sourced from `Karnataka_Location_Master.json` (district_name / taluk_name fields) and kept in sync with the JSON; the old hardcoded `districtsByState`/`taluksByDistrict` maps are deprecated or regenerated from the same master file structure.
- **FR4.4** — Village list per taluk is sourced from `Karnataka_Location_Master.json`, aggregating all villages across every hobli inside the taluk (hobli level ignored for UI grouping but each village retains its `village_name` and `village_code`).
- **FR4.5** — District and taluk names from the master JSON are normalized (title case) to match existing UI labels; both uppercase and title-case lookups work.
- **FR4.6** — `Karnataka_Location_Master.json` is bundled as a Flutter asset and loaded once at app start (via a `LocationMasterService`), cached in memory for dropdown lookups. A fallback list is used if asset loading fails.

---

## Non-Functional Requirements (NFR)

- **NFR1 (Security)** — OTP storage is hashed (SHA-256 over OTP+phone+nonce) in local storage; plain OTP never persisted.
- **NFR2 (Rate limiting)** — Rate limits and lockout windows are tracked per-phone-number and enforced before OTP generation/verification.
- **NFR3 (Validation)** — All form validations follow existing `AuthValidators` extension style and are unit-testable.
- **NFR4 (State mgmt)** — All new state is exposed via Riverpod notifiers, consistent with existing `AuthController`/`auth_state.dart` pattern.
- **NFR5 (Navigation)** — GoRouter redirects preserve phase ordering; manually navigating to a phase URL out of order is redirected to the correct pending phase.
- **NFR6 (Backward compat)** — Existing users (with onboarding already complete) are routed through a one-time migration check to fill missing farm-detail fields (Phase B).

---

## Constraints & Dependencies

- Dependencies already available: `pinput` for OTP UI, `permission_handler` for permissions, `shared_preferences`, `flutter_riverpod`, `go_router`.
- No new 3rd-party packages are required.
- Runs on Android + iOS; permission-flow gracefully no-ops on web/desktop.
- Simulated SMS channel logs the OTP via `AppLogger.info` and displays a success toast so testers can read the OTP during manual QA.

---

## Assumptions

- Firebase Phone Auth is not available for this iteration; the OTP system uses a simulated SMS service.
- "Encrypted SMS channel" in the scope of this iteration means the OTP is hashed before storage and the mock send pipeline is logged as encrypted-channel.
- Existing users with complete onboarding but missing `landSurveyNo`/`arecanutCultivationType`/`soilType` fields will see Phase B once before entering dashboard.

---

## Open Questions

None at this time; all scope decisions resolved above.

---

## Acceptance Criteria

### rule: AC1 — OTP triggers on login/signup/phone-change
Navigate login flow → after correct password, user is pushed to OTP screen. Signup flow → after account creation, OTP screen appears. Profile Edit → changing phone field → OTP verification required before save completes.

### rule: AC2 — OTP 15-min expiry & rate limiting
Generate an OTP; wait 15 simulated minutes (advance stored timestamp); attempt verify → "OTP expired" error. Hit resend 3 times in <2s → cooldown enforced.

### rule: AC3 — OTP retry lockout after 5 wrong entries
Submit 5 wrong OTP codes in one session → 5-minute lockout message appears; resend and verify are disabled until lockout passes.

### rule: AC4 — Permissions only after auth+OTP complete
Clear app storage and run from splash → permission prompt does NOT appear before login/OTP finishes. Only after the session is authenticated and OTP verified does the purpose dialog appear.

### rule: AC5 — Permission denial handled gracefully
Deny both gallery and camera permanently → a fallback card shows "Permissions denied" with "Open Settings" button; app remains usable.

### rule: AC6 — Phase A collects only core farmer fields
Inspect Onboarding (Phase A) form → fields present: Full name, Phone, State (Karnataka disabled), District, Taluk, Village (dropdown from master). No agricultural role field; no farm survey/soil/variety fields.

### rule: AC6b — Village dropdown sourced from Karnataka_Location_Master.json
For any taluk in Phase A, the Village dropdown lists villages aggregated across all hoblis in that taluk from the master JSON. Search/autocomplete filters by village name.

### rule: AC7 — Phase B collects only farm detail fields
After Phase A submit, user navigates to Phase B form → fields present: Land survey number, Arecanut cultivation type, Soil type. No duplicate farmer core fields.

### rule: AC8 — Phasing enforces order via storage & router
Manually navigate to `/farm-details` without completing Phase A → router redirects to `/onboarding`. Navigate to `/dashboard` without completing Phase B → router redirects to `/farm-details`.

### rule: AC9 — Karnataka-only restriction + master-sourced districts/taluks
State dropdown in Phase A and Profile edit shows only "Karnataka" and is non-editable/disabled; `KarnatakaLocations.states` list length == 1. District/Taluk/Village data match the entries in `Karnataka_Location_Master.json`.

### rule: AC10 — Survey number format validation
Enter invalid formats like "abc", "1234567" (too long), or "12//3" in survey number → validator rejects with error message. Enter "12/3A" → passes.

### rubric: AC11 — UX Clarity of OTP / Permission / Phase flows (threshold: ≥3/5)
**Scale:**
- 1: Confusing, dead ends, no feedback
- 3: Clear labels, buttons work, minor rough edges
- 5: Delightful, self-explanatory, professional

Evidence: Manual walkthrough of each flow, capturing screenshots or steps showing labels, error messages, progress indicators.

### rubric: AC12 — Code Architecture Consistency (threshold: ≥3/5)
**Scale:**
- 1: Ad-hoc state, globals, breaks Riverpod pattern
- 3: Follows existing Controller/Service/Repository layers, uses Riverpod properly
- 5: Same patterns as existing modules, clean separation, fully testable

Evidence: Code review of new service/repository/controller layers.

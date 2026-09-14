# Implementation Tasks

## Task 1a: Declare Karnataka_Location_Master.json as Flutter asset
**Priority:** high
**Depends on:** none
**Status:** pending

### Description
Copy `Karnataka_Location_Master.json` into `assets/` directory (or reference from project root) and declare it in `pubspec.yaml` under the `flutter: assets:` section so it can be loaded at runtime with `rootBundle.loadString`.

### Files to modify
- [pubspec.yaml](file:///c:/major-project/pubspec.yaml)
- `assets/Karnataka_Location_Master.json` (if copying required)

### Local Test Requirements
- **rule TR1a.1:** `flutter pub get` runs without asset errors.
- **rule TR1a.2:** Asset path matches a file that exists on disk.

---

## Task 1b: Build LocationMasterService to parse JSON, cache districts/taluks/villages
**Priority:** high
**Depends on:** Task 1a
**Status:** pending

### Description
Create `LocationMasterService` that:
1. Loads `Karnataka_Location_Master.json` from assets on first access (async init).
2. Normalizes `district_name` / `taluk_name` to Title Case (matching UI expectations).
3. Ignores hobli grouping; instead aggregates all villages per taluk into a single flat list of `{village_name, village_code}` entries (de-duped by `village_code`).
4. Provides synchronous getters once initialized: `districts`, `taluksFor(district)`, `villagesFor(taluk)`.
5. Falls back to the existing hardcoded `KarnatakaLocations` if asset load fails.

Expose via a Riverpod provider (e.g., `locationMasterServiceProvider`) that awaits initialization on app start or lazily.

### Files to create/modify
- `lib/core/services/location_master_service.dart` (new)
- Optionally update [karnataka_locations.dart](file:///c:/major-project/lib/core/constants/karnataka_locations.dart) to deprecate old maps or re-route through service

### Local Test Requirements
- **rule TR1b.1:** After loading, `districts` list is non-empty and matches the number of district entries in JSON.
- **rule TR1b.2:** `taluksFor` for a known district (e.g., "Bagalkote") matches all taluks in that JSON district entry.
- **rule TR1b.3:** `villagesFor(taluk)` returns the correct count by summing villages across all hoblis in that taluk from JSON.
- **rule TR1b.4:** No hobli appears in the UI-facing methods (hobli is transparent/ignored).

---

## Task 1c: Restrict KarnatakaLocations to Karnataka-only (display-only)
**Priority:** high
**Depends on:** none
**Status:** pending

### Description
Update `karnataka_locations.dart` so `states` list contains only `"Karnataka"` and keep existing hardcoded district/taluk maps as a fallback only. Ensure districtsFor/taluksFor still work correctly for the single-state input.

### Files to modify
- [karnataka_locations.dart](file:///c:/major-project/lib/core/constants/karnataka_locations.dart)

### Local Test Requirements
- **rule TR1c.1:** `KarnatakaLocations.states.length == 1 && KarnatakaLocations.states.first == 'Karnataka'`
- **rule TR1c.2:** `KarnatakaLocations.districtsFor('Karnataka')` returns non-empty Karnataka district list.
- **rule TR1c.3:** Calling `districtsFor` with a non-Karnataka state still falls back to Karnataka districts.

---

## Task 2: Extend FarmProfileModel, FarmModel with Phase B fields + villageCode
**Priority:** high
**Depends on:** none
**Status:** pending

### Description
Add `landSurveyNumber`, `arecanutCultivationType`, `soilType` fields to FarmProfileModel and FarmModel with proper serialization, plus `villageCode` (to persist the authoritative KGIS village code from master JSON) to both models. Keep backward-compatible defaults for existing users.

Keep UserModel unchanged (no agricultural role field per requirement drop).

### Files to modify
- [farm_profile_model.dart](file:///c:/major-project/lib/models/farm/farm_profile_model.dart)
- [farm_model.dart](file:///c:/major-project/lib/models/farm/farm_model.dart)

### Local Test Requirements
- **rule TR2.1:** `FarmProfileModel.fromMap` returns sensible defaults for missing new fields (no crash on old data, survey/cultivation/soil all default to empty string or first option as appropriate).
- **rule TR2.2:** `FarmProfileModel` serializes `landSurveyNumber`, `arecanutCultivationType`, `soilType`, `villageCode` to/from map/json without data loss.
- **rule TR2.3:** `FarmModel` includes `landSurveyNumber`, `arecanutCultivationType`, `soilType`, `villageCode` with non-null defaults.

---

## Task 3: Create OTP Service, OTP Failure types, rate-limit / expiry logic
**Priority:** high
**Depends on:** Task 2
**Status:** pending

### Description
Create `OtpService` class with methods `generateOtp(phone)`, `verifyOtp(phone, code)`, `canResend(phone)`, `isLocked(phone)`. OTP: 6-digit random, 15-min expiry, SHA-256 hash stored (never plain), 60s resend cooldown, 5 attempts → 5-min lockout. Add OTP-specific Failure factories to failures.dart.

### Files to create/modify
- `lib/services/otp/otp_service.dart` (new)
- [failures.dart](file:///c:/major-project/lib/core/errors/failures.dart)

### Local Test Requirements
- **rule TR3.1:** `generateOtp` returns a 6-digit numeric string.
- **rule TR3.2:** `verifyOtp` with correct code within 15 min returns true; after 15 min (faked clock/stored time) returns OtpExpired failure.
- **rule TR3.3:** 5 consecutive wrong `verifyOtp` calls triggers lockout; subsequent calls return OtpLocked failure.
- **rule TR3.4:** Second `generateOtp` within 60s of first returns RateLimited failure.
- **rule TR3.5:** Stored OTP hash in SharedPreferences does not match the plain OTP string.

---

## Task 4: Add OTP Controller, extend AuthState & AuthController for OTP flow
**Priority:** high
**Depends on:** Task 3
**Status:** pending

### Description
Add OTP flow to the auth pipeline: after successful password auth (login/signup) or phone change, push user to OTP screen instead of directly granting access. Update `AuthStatus` enum with `otpVerificationPending`. Add controller methods to trigger OTP send, verify OTP, resend OTP.

### Files to create/modify
- [auth_state.dart](file:///c:/major-project/lib/features/auth/controllers/auth_state.dart)
- [auth_controller.dart](file:///c:/major-project/lib/features/auth/controllers/auth_controller.dart)
- [auth_service.dart](file:///c:/major-project/lib/services/auth/auth_service.dart) (add otp helpers)
- [auth_repository.dart](file:///c:/major-project/lib/repositories/auth/auth_repository.dart) (wrap otp calls)

### Local Test Requirements
- **rule TR4.1:** After `login()` succeeds with correct password, `authState.status == AuthStatus.otpVerificationPending`.
- **rule TR4.2:** Calling `verifyOtpAndLogin(...)` with correct OTP transitions to `authenticated`.
- **rule TR4.3:** Calling `verifyOtpAndLogin(...)` with wrong OTP sets an errorMessage; status remains `otpVerificationPending`.

---

## Task 5: Build OTP Verification Screen with countdown
**Priority:** high
**Depends on:** Task 4
**Status:** pending

### Description
Create `/otp-verification` route and screen. Use `pinput` package for 6-digit input. Show phone number being verified, resend button with 60s countdown timer, error/success banners, 5-attempt lockout message. Integrate with GoRouter routes.

### Files to create/modify
- `lib/features/auth/screens/otp_verification_screen.dart` (new)
- [router.dart](file:///c:/major-project/lib/app/router.dart)

### Local Test Requirements
- **rule TR5.1:** Route `/otp-verification` is registered.
- **rule TR5.2:** 6 pinput boxes present; autofocused on first.
- **rule TR5.3:** Resend button is disabled for 60s after entering screen; countdown text visible.
- **rule TR5.4:** Error banner appears on wrong code; lockout message visible after 5 failures.

---

## Task 6: Create Permission Request Service + Screen/Dialog
**Priority:** medium
**Depends on:** Task 5
**Status:** pending

### Description
Create `PermissionService` wrapping `permission_handler`. Create a purpose-explanation dialog screen (`/permission-setup`) that runs after auth+OTP. The dialog lists camera + gallery use-cases, then requests system permissions. On permanent denial, show fallback with "Open App Settings" action. Store `hasRequestedPermissions` in LocalStorageService so it runs once per installation.

### Files to create/modify
- `lib/services/permissions/permission_service.dart` (new)
- `lib/features/auth/screens/permission_setup_screen.dart` (new)
- [local_storage_service.dart](file:///c:/major-project/lib/core/storage/local_storage_service.dart) (add permission flag keys)
- [router.dart](file:///c:/major-project/lib/app/router.dart)

### Local Test Requirements
- **rule TR6.1:** Permission screen only reachable when user is fully authenticated + OTP verified.
- **rule TR6.2:** Permission purpose dialog shows correct text for camera and gallery.
- **rule TR6.3:** When permissions permanently denied, fallback UI is shown and "Open Settings" calls `openAppSettings()` (mocked/verified via service).
- **rule TR6.4:** `hasRequestedPermissions` flag written to storage on completion.

---

## Task 7: Rework Onboarding Screen into Phase A (Farmer Core Details) + Village dropdown
**Priority:** high
**Depends on:** Tasks 1a, 1b, 1c, 2, 6
**Status:** pending

### Description
Rewrite existing `onboarding_screen.dart` to collect ONLY: Full name, Phone, and Location (State fixed to Karnataka, District dropdown, Taluk dropdown, Village searchable/autocomplete dropdown from master JSON). State dropdown is disabled/fixed to "Karnataka". Remove Agricultural Role field entirely. Remove all farm-detail fields (farm name, size, water, irrigation, planting date, etc.). Village must be a searchable or paginated dropdown sourced from `LocationMasterService.villagesFor(taluk)` (all villages aggregated across hoblis). User must explicitly select a village; fallback free-text input is disabled. On submit, save farmer core details (including the selected `villageName` + `villageCode`), mark Phase A done, navigate to Phase B route.

### Files to modify
- [onboarding_screen.dart](file:///c:/major-project/lib/features/onboarding/screens/onboarding_screen.dart)
- [local_storage_service.dart](file:///c:/major-project/lib/core/storage/local_storage_service.dart) (add Phase A/Phase B flags: `hasCompletedPhaseA`, `hasCompletedPhaseB`)

### Local Test Requirements
- **rule TR7.1:** Form renders exactly: name, phone, state (label/disabled reading "Karnataka"), district dropdown, taluk dropdown, village searchable dropdown. No agricultural role. No farm fields.
- **rule TR7.2:** State field is non-editable and reads "Karnataka".
- **rule TR7.3:** Changing district resets taluk to first taluk in that district; changing taluk resets village list to that taluk's villages (from master JSON).
- **rule TR7.4:** Village dropdown shows searchable list filtered by taluk; selecting a village populates both village name + villageCode.
- **rule TR7.5:** On successful submit → `/farm-details` route is navigated to and `hasCompletedPhaseA == true` in storage.

---

## Task 8: Build Phase B (Farm Details) Screen
**Priority:** high
**Depends on:** Task 7
**Status:** pending

### Description
Create `/farm-details` screen with: Land Survey Number (with format validator), Arecanut Cultivation Type dropdown, Soil Type dropdown. Link data to userId via FarmProfileModel (with new fields from Task 2) and FarmModel. On submit, set `hasCompletedOnboarding = true` and navigate to `/dashboard`. Router must prevent reaching Phase B before Phase A, and prevent dashboard before Phase B.

### Files to create/modify
- `lib/features/farm/screens/farm_details_screen.dart` (new)
- [auth_validators.dart](file:///c:/major-project/lib/core/validators/auth_validators.dart) (add `validateSurveyNumber`)
- [router.dart](file:///c:/major-project/lib/app/router.dart)
- [profile_repository.dart](file:///c:/major-project/lib/repositories/profile/profile_repository.dart) (if needed, helper to merge)

### Local Test Requirements
- **rule TR8.1:** Survey number validator accepts: `123`, `12/3`, `12/3A`, `12/3/4`. Rejects: `abc`, `12//3`, `123456789` (length).
- **rule TR8.2:** Cultivation dropdown contains: Mangala, Sumangala, Sreemangala, SAS-1, Mohitnagar, Hirehalli Dwarf, Other.
- **rule TR8.3:** Soil dropdown contains: Red Sandy, Red Loamy, Black Cotton, Laterite, Alluvial, Clay.
- **rule TR8.4:** Router blocks `/dashboard` when Phase A or B incomplete; redirects to pending phase.
- **rule TR8.5:** On submit, `hasCompletedOnboarding == true` in storage.

---

## Task 9: Update Profile Edit Screen for phone-change OTP + fixed Karnataka + village dropdown + new fields
**Priority:** medium
**Depends on:** Tasks 1a, 1b, 1c, 2, 4, 8
**Status:** pending

### Description
Update `profile_edit_screen.dart`:
- State dropdown disabled (Karnataka only, label-read-only)
- District/Taluk/Village dropdowns sourced from LocationMasterService; Village is searchable/autocomplete and shows the master list with preselected existing value.
- No Agricultural Role field (removed entirely)
- Add farm detail fields (survey, cultivation, soil) to edit as dedicated editable fields
- Phone field change triggers OTP verification; save blocked until OTP succeeds. If phone unchanged, no OTP needed.
- Persist villageCode alongside village name.

### Files to modify
- [profile_edit_screen.dart](file:///c:/major-project/lib/features/profile/screens/profile_edit_screen.dart)

### Local Test Requirements
- **rule TR9.1:** Changing phone number and saving triggers OTP flow (OTP screen appears or inline OTP modal). If phone unchanged, save proceeds directly.
- **rule TR9.2:** State field locked to Karnataka (non-editable, shows "Karnataka").
- **rule TR9.3:** New farm detail fields (survey, cultivation, soil) are editable and persist on save.
- **rule TR9.4:** Village is a dropdown/autocomplete sourced from master JSON and preselects existing village name; villageCode is persisted on save.

---

## Task 10: Update LoginScreen & SignupScreen to trigger OTP post-auth
**Priority:** high
**Depends on:** Task 4, 5
**Status:** pending

### Description
Modify login/submit handlers so instead of going directly to dashboard/onboarding, they wait for `otpVerificationPending` status and navigate to `/otp-verification`. Signup same.

### Files to modify
- [login_screen.dart](file:///c:/major-project/lib/features/auth/screens/login_screen.dart)
- [signup_screen.dart](file:///c:/major-project/lib/features/auth/screens/signup_screen.dart)

### Local Test Requirements
- **rule TR10.1:** Login with correct credentials pushes to `/otp-verification`.
- **rule TR10.2:** Signup with valid form → after success, pushes to `/otp-verification`.

---

## Task 11: Update GoRouter redirect logic for phase ordering + permission gating
**Priority:** high
**Depends on:** Tasks 5, 6, 8
**Status:** pending

### Description
Refactor router.dart redirect function to:
1. If authenticated + OTP verified + permissions not yet requested → `/permission-setup`
2. If permissions requested + Phase A not done → `/onboarding`
3. If Phase A done + Phase B not done → `/farm-details`
4. If both phases done → allowed to `/dashboard`

Manual URL tampering redirects appropriately.

### Files to modify
- [router.dart](file:///c:/major-project/lib/app/router.dart)

### Local Test Requirements
- **rule TR11.1:** Unauthenticated requests to `/dashboard` → `/login`.
- **rule TR11.2:** Authenticated but Phase B pending → `/farm-details`.
- **rule TR11.3:** Authenticated but permissions pending → `/permission-setup` (first time after install only).
- **rule TR11.4:** Authenticated, permissions done, Phase A pending → `/onboarding`.

---

## Task 12: Backward-compat migration for existing users (Phase B once)
**Priority:** medium
**Depends on:** Task 11
**Status:** pending

### Description
In router logic or profile load: if `hasCompletedOnboarding == true` but `FarmProfileModel.landSurveyNumber` is missing, force Phase B once before dashboard. On Phase B submit for returning users, preserve existing farm data.

### Files to modify
- [router.dart](file:///c:/major-project/lib/app/router.dart) or profile repository helper
- [local_storage_service.dart](file:///c:/major-project/lib/core/storage/local_storage_service.dart)

### Local Test Requirements
- **rule TR12.1:** When `hasCompletedOnboarding=true` and farm details fields are empty, router redirects to `/farm-details`.
- **rule TR12.2:** After Phase B completes, dashboard loads and subsequent sessions skip Phase B.

---

## Task 13: Run end-to-end verification with flutter analyze + existing test suite + new validators tests
**Priority:** high
**Depends on:** Tasks 1–12
**Status:** pending

### Description
Run:
- `flutter analyze`
- `flutter test`
- If runtime tests are feasible, manual spec walkthrough checklist against AC1–AC10 and rubric scoring for AC11, AC12.

Also write a new test file for OTP service validators & survey number validators.

### Files to create/modify
- `test/otp_service_test.dart` (new)
- `test/survey_validator_test.dart` (new)
- Existing test files updated if needed for new fields

### Local Test Requirements
- **rule TR13.1:** `flutter analyze` completes with 0 errors, 0 warnings (information only allowed).
- **rule TR13.2:** `flutter test` runs and all tests pass.
- **rule TR13.3:** OTP service tests cover: generation, expiry (mocked time), lockout, rate limit.
- **rule TR13.4:** Survey validator tests cover all pass/reject patterns from TR8.1.
- **rubric TR13.5:** AC11 UX clarity score (0–5, threshold ≥3). Score with rationale and evidence (walkthrough notes).
- **rubric TR13.6:** AC12 Architecture consistency score (0–5, threshold ≥3). Score with rationale and evidence.

---
artifact: test_checklist
metadata_schema_version: "1.0"
project: app
status: pending-device-proof
scope: Android native Clerk auth bridge
---

# Android native Clerk auth bridge

Build identity (redacted): pending device build. Record commit/build id and
Paris/UTC build timestamps before executing this checklist. Do not record a
token, cookie, auth code, full callback URI, email address or SHA-1.

| Scenario ID | Surface | Scenario | Required | Expected | Status | Observed | Evidence pointer | Notes | Bug Link |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AUTH-ANDROID-001 | Android device | Google native success creates Clerk session, calls bootstrap, opens onboarding/workspace. | yes | Native sign-in returns to app with active session. | NOT_RUN |  |  | Device build/provider configuration required. |  |
| AUTH-ANDROID-002 | Android device | Cancelled account chooser remains signed out and offers retry. | yes | Cancel leaves no session and retry remains available. | NOT_RUN |  |  | Device build required. |  |
| AUTH-ANDROID-003 | Android callback | Valid external callback reaches app once when created or already open. | yes | Callback is handled exactly once in both Activity paths. | NOT_RUN |  |  | Provider redirect configuration required. |  |
| AUTH-ANDROID-004 | Android callback | Invalid/replayed callback changes no session or navigation. | yes | Invalid/replayed callback is ignored safely. | NOT_RUN |  |  | Device build required. |  |
| AUTH-ANDROID-005 | Android device | App restart restores session and obtains a fresh bearer for bootstrap. | yes | Native session restores without Dart token persistence. | NOT_RUN |  |  | Device build required. |  |
| AUTH-ANDROID-006 | Android device | Sign-out/401 clears auth state and subsequent request has no bearer. | yes | Sign-out clears session and authenticated calls stop. | NOT_RUN |  |  | Device/backend test required. |  |
| AUTH-WEB-001 | Web preview | ClerkJS `/sign-in`, `/sign-up`, `/sso-callback` remain unchanged. | yes | Existing web auth routes still work. | NOT_RUN |  |  | Preview/runtime key required. |  |

Diagnostics review: verify copied diagnostics start with build identity,
Paris/UTC timestamps, and contain no token, cookie, code, private callback URI
or unnecessary personal data.

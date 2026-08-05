## 2026-05-16 - BUG-2026-05-05-001 Android safe area demo onboarding

- Scope: BUG-2026-05-05-001
- Environment: local Android release build
- Tester: user
- Source: sf-test
- Status: blocked
- Confidence: high
- Result summary: Retest not executable because the expected `Open Interactive Demo` entry option is absent from the Android entry screen.
- Bug pointer: BUG-2026-05-05-001 -> shipglows_data/workflow/bugs/app/BUG-2026-05-05-001.md
- Evidence pointer: user-provided entry diagnostics, generated at 2026-05-16T12:17:55.080922Z, build commit 77be95214347b0a7227768dfed2cec83d13324a7.
- Follow-up: /sf-fix BUG-2026-05-05-001 Android demo entry unavailable

## 2026-05-16 - BUG-2026-05-05-001 Android safe area demo onboarding retest

- Scope: BUG-2026-05-05-001
- Environment: local Android device/build
- Tester: user
- Source: sf-test
- Status: pass
- Confidence: medium
- Result summary: User reported `PASS` after the demo entry fix; `Open Interactive Demo` is usable and the Android onboarding safe-area issue did not reproduce.
- Bug pointer: BUG-2026-05-05-001 -> shipglows_data/workflow/bugs/app/BUG-2026-05-05-001.md
- Evidence pointer: chat reply `pass` on 2026-05-16 after retest instructions.
- Follow-up: /sf-verify BUG-2026-05-05-001 Android safe area demo onboarding

## 2026-05-16 - BUG-2026-05-05-001 Android safe area demo onboarding verification

- Scope: BUG-2026-05-05-001
- Environment: local Flutter + user Android retest evidence
- Tester: Codex + user evidence
- Source: sf-verify
- Status: pass
- Confidence: high
- Result summary: Closure criteria verified; focused Flutter tests passed and the user Android retest passed.
- Bug pointer: BUG-2026-05-05-001 -> shipglows_data/workflow/bugs/app/BUG-2026-05-05-001.md
- Evidence pointer: `flox activate -- flutter test test/presentation/screens/entry/entry_screen_test.dart test/navigation/resume_no_jump_test.dart test/presentation/screens/onboarding/onboarding_back_test.dart` -> passed.
- Follow-up: none

## 2026-05-16 - BUG-2026-05-05-002 Android back navigation demo retest

- Scope: BUG-2026-05-05-002
- Environment: local Android device/build
- Tester: user
- Source: sf-test
- Status: pass
- Confidence: medium
- Result summary: User reported all requested onboarding back-navigation checks passed.
- Bug pointer: BUG-2026-05-05-002 -> shipglows_data/workflow/bugs/app/BUG-2026-05-05-002.md
- Evidence pointer: chat reply `all pass` on 2026-05-16 after retest instructions.
- Follow-up: /sf-verify BUG-2026-05-05-002 Android back navigation demo

## 2026-05-16 - BUG-2026-05-05-002 Android back navigation demo verification

- Scope: BUG-2026-05-05-002
- Environment: local Flutter + user Android retest evidence
- Tester: Codex + user evidence
- Source: sf-verify
- Status: pass
- Confidence: high
- Result summary: Closure criteria verified; focused Flutter onboarding back test passed and the user Android retest passed.
- Bug pointer: BUG-2026-05-05-002 -> shipglows_data/workflow/bugs/app/BUG-2026-05-05-002.md
- Evidence pointer: `flox activate -- flutter test test/presentation/screens/onboarding/onboarding_back_test.dart` -> passed.
- Follow-up: /sf-spec Android back history outside onboarding

## 2026-05-17 - BUG-2026-05-10-001 Personas draft SQL insert fails on Hrana None parse

- Scope: BUG-2026-05-10-001
- Environment: prod
- Tester: user
- Source: sf-test
- Status: blocked
- Confidence: medium
- Result summary: Re-test blocked: runtime diagnostics show Clerk config missing (`hasClerkKey=false`, `sessionState=signedOut`, no Bearer token), so backend/auth flow could not be exercised.
- Bug pointer: BUG-2026-05-10-001 -> shipglows_data/workflow/bugs/lab/BUG-2026-05-10-001.md
- Evidence pointer: user diagnostics payload (build commit 438b10c9db15d2ad9a16d4288a595ba01468002c, generated 2026-05-17T10:57:04.026131Z).
- Follow-up: /sf-fix BUG-2026-05-10-001

## 2026-06-10 - Hosted Clerk sign-up pre-OTP smoke

- Scope: hosted auth `/sign-up`
- Environment: prod
- Tester: Codex browser smoke
- Source: sf-test
- Status: pass
- Confidence: high
- Result summary: `https://app.contentglows.com/sign-up` returns 200, deployed `clerk-runtime.js` contains the hash-routing OTP fix, Clerk SignUp mounts with email/password fields, and Playwright observed no console or failed-request errors before entering an email.
- Bug pointer: none
- Evidence pointer: `shipglows_data/workflow/qa/evidence/auth-otp-signup-2026-06-10/sign-up.png`; Playwright summary observed HTTP 200, final URL `/sign-up`, no console errors, no failed requests, `Ready.` status, and mounted email/password fields. Deployed build `b283b478e698ecdf4dbe868e05415e7977f11d84`, timestamp `2026-06-02T14:46:27Z`.
- Follow-up: run full hosted OTP account creation with an accessible test inbox; do not log raw OTP.

## 2026-06-10 - Hosted Clerk email OTP sign-up

- Scope: hosted auth `/sign-up`
- Environment: prod
- Tester: user
- Source: sf-test
- Status: pass
- Confidence: high
- Result summary: User reported PASS for the full hosted email sign-up flow: one OTP email received, code accepted, account creation completed, and no redirect loop or Clerk error observed.
- Bug pointer: none
- Evidence pointer: user reply `PASS` on 2026-06-10 after OTP test instructions; no raw OTP or private email details stored.
- Follow-up: /sf-verify hosted Clerk OTP sign-up fix

## 2026-05-06 - LAB AGENTS compatibility symlink retest

- Scope: BUG-2026-05-06-001
- Environment: local
- Tester: tooling
- Source: sf-test
- Status: pass
- Confidence: high
- Result summary: `lab/AGENTS.md` is a symlink to `lab/AGENT.md`; canonical guidance is consolidated and stale contradictory references were not found.
- Bug pointer: BUG-2026-05-06-001 -> shipglows_data/workflow/bugs/lab/BUG-2026-05-06-001.md
- Evidence pointer: `test -L lab/AGENTS.md`; `readlink lab/AGENTS.md`; focused `rg` checks on canonical and stale references
- Follow-up: /sf-verify BUG-2026-05-06-001

## 2026-05-10 - LAB personas draft prod retest

- Scope: BUG-2026-05-10-001
- Environment: prod
- Tester: tooling
- Source: sf-test
- Status: blocked
- Confidence: high
- Result summary: `POST /api/personas/draft` on `https://api.contentglows.com` returned `401`; the job was not created and polling could not be exercised.
- Bug pointer: BUG-2026-05-10-001 -> shipglows_data/workflow/bugs/lab/BUG-2026-05-10-001.md
- Evidence pointer: `curl https://api.contentglows.com/health` (200), `curl -X POST https://api.contentglows.com/api/personas/draft` (401), outputs saved to local temp files during the retest
- Follow-up: /sf-fix BUG-2026-05-10-001

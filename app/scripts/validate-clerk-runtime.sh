#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/home/claude/.flutter-sdk/bin:$PATH"

API_BASE_URL_VALUE="${API_BASE_URL:-https://api.contentglows.com}"
CLERK_PUBLISHABLE_KEY_VALUE="${CLERK_PUBLISHABLE_KEY:-}"
APP_SITE_URL_VALUE="${APP_SITE_URL:-https://contentglows.com}"
APP_WEB_URL_VALUE="${APP_WEB_URL:-https://app.contentglows.com}"
BUILD_COMMIT_SHA_VALUE="${BUILD_COMMIT_SHA:-${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}}"
BUILD_ID_VALUE="${BUILD_ID:-${GITHUB_RUN_ID:-${VERCEL_GIT_COMMIT_SHA:-$BUILD_COMMIT_SHA_VALUE}}}"
BUILD_ENVIRONMENT_VALUE="${BUILD_ENVIRONMENT:-${VERCEL_ENV:-local-validation}}"
BUILD_TIMESTAMP_VALUE="${BUILD_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
BUILD_AT_UTC_VALUE="${BUILD_AT_UTC:-$BUILD_TIMESTAMP_VALUE}"
BUILD_AT_PARIS_VALUE="${BUILD_AT_PARIS:-$(TZ=Europe/Paris date -d "$BUILD_AT_UTC_VALUE" '+%Y-%m-%d %H:%M' 2>/dev/null || TZ=Europe/Paris date '+%Y-%m-%d %H:%M')}"
SENTRY_DSN_VALUE="${SENTRY_DSN:-}"
SENTRY_ENVIRONMENT_VALUE="${SENTRY_ENVIRONMENT:-${BUILD_ENVIRONMENT_VALUE}}"
SENTRY_RELEASE_VALUE="${SENTRY_RELEASE:-}"
SENTRY_DIST_VALUE="${SENTRY_DIST:-${BUILD_ID:-${GITHUB_RUN_ID:-${VERCEL_GIT_COMMIT_SHA:-${BUILD_TIMESTAMP_VALUE}}}}}"
SENTRY_TRACES_SAMPLE_RATE_VALUE="${SENTRY_TRACES_SAMPLE_RATE:-0.0}"
SENTRY_SEND_DEFAULT_PII_VALUE="${SENTRY_SEND_DEFAULT_PII:-false}"
SENTRY_DEBUG_VALUE="${SENTRY_DEBUG:-false}"
PORT_VALUE="${PORT:-3050}"

cd "$ROOT_DIR"

echo "== ContentGlows Clerk Runtime Validation =="
echo "Project: $ROOT_DIR"
echo "API_BASE_URL: $API_BASE_URL_VALUE"
echo "APP_SITE_URL: $APP_SITE_URL_VALUE"
echo "APP_WEB_URL: $APP_WEB_URL_VALUE"
echo "BUILD_COMMIT_SHA: $BUILD_COMMIT_SHA_VALUE"
echo "BUILD_ID: $BUILD_ID_VALUE"
echo "BUILD_ENVIRONMENT: $BUILD_ENVIRONMENT_VALUE"
echo "BUILD_TIMESTAMP: $BUILD_TIMESTAMP_VALUE"
echo "BUILD_AT_PARIS: $BUILD_AT_PARIS_VALUE"
echo "BUILD_AT_UTC: $BUILD_AT_UTC_VALUE"
echo "SENTRY_DSN: $([[ -n "$SENTRY_DSN_VALUE" ]] && echo configured || echo not-configured)"
echo "SENTRY_DIST: $([[ -n "$SENTRY_DIST_VALUE" ]] && echo configured || echo not-configured)"
echo "PORT: $PORT_VALUE"

if [[ -z "$CLERK_PUBLISHABLE_KEY_VALUE" ]]; then
  echo ""
  echo "Missing CLERK_PUBLISHABLE_KEY."
  echo "Export it, then re-run this script."
  echo ""
  echo "Example:"
  echo "  API_BASE_URL=https://api.contentglows.com \\"
  echo "  CLERK_PUBLISHABLE_KEY=pk_test_xxx \\"
  echo "  APP_SITE_URL=https://contentglows.com \\"
  echo "  APP_WEB_URL=https://app.contentglows.com \\"
  echo "  BUILD_COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown) \\"
  echo "  BUILD_ID=local-validation \\"
  echo "  BUILD_ENVIRONMENT=local-validation \\"
  echo "  BUILD_AT_PARIS=$(TZ=Europe/Paris date '+%Y-%m-%d %H:%M') \\"
  echo "  BUILD_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ) \\"
  echo "  PORT=3050 \\"
  echo "  ./scripts/validate-clerk-runtime.sh"
  exit 1
fi

echo ""
echo "1. Flutter toolchain"
flutter --version

echo ""
echo "2. Dependencies"
flutter pub get

echo ""
echo "3. Static analysis"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo ""
echo "4. Web build with Clerk config"
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL_VALUE}" \
  --dart-define=CLERK_PUBLISHABLE_KEY="${CLERK_PUBLISHABLE_KEY_VALUE}" \
  --dart-define=APP_SITE_URL="${APP_SITE_URL_VALUE}" \
  --dart-define=APP_WEB_URL="${APP_WEB_URL_VALUE}" \
  --dart-define=BUILD_COMMIT_SHA="${BUILD_COMMIT_SHA_VALUE}" \
  --dart-define=BUILD_ID="${BUILD_ID_VALUE}" \
  --dart-define=BUILD_ENVIRONMENT="${BUILD_ENVIRONMENT_VALUE}" \
  --dart-define=BUILD_TIMESTAMP="${BUILD_TIMESTAMP_VALUE}" \
  --dart-define=BUILD_AT_PARIS="${BUILD_AT_PARIS_VALUE}" \
  --dart-define=BUILD_AT_UTC="${BUILD_AT_UTC_VALUE}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN_VALUE}" \
  --dart-define=SENTRY_ENVIRONMENT="${SENTRY_ENVIRONMENT_VALUE}" \
  --dart-define=SENTRY_RELEASE="${SENTRY_RELEASE_VALUE}" \
  --dart-define=SENTRY_DIST="${SENTRY_DIST_VALUE}" \
  --dart-define=SENTRY_TRACES_SAMPLE_RATE="${SENTRY_TRACES_SAMPLE_RATE_VALUE}" \
  --dart-define=SENTRY_SEND_DEFAULT_PII="${SENTRY_SEND_DEFAULT_PII_VALUE}" \
  --dart-define=SENTRY_DEBUG="${SENTRY_DEBUG_VALUE}"

echo ""
echo "5. Serving build/web on http://localhost:${PORT_VALUE}"
echo "   Eruda: append ?eruda=1 once to keep the console enabled in localStorage."
echo "   Validation flow:"
echo "   - open /entry"
echo "   - sign in with a real Clerk test account"
echo "   - verify redirect to /onboarding or /feed from /entry"
echo "   - refresh the page and confirm session restore"
echo "   - confirm /api/bootstrap loads without bouncing back to /entry"
echo ""

exec node server.js "${PORT_VALUE}"

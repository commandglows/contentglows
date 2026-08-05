#!/bin/bash
set -euo pipefail

export PATH="/home/claude/.flutter-sdk/bin:$PATH"
cd "$(cd "$(dirname "$0")" && pwd)"

EXPECTED_FLUTTER_VERSION="$(tr -d '[:space:]' < .flutter-version 2>/dev/null || true)"
INSTALLED_FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null | tr -d '\n' | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"

if [[ -n "${EXPECTED_FLUTTER_VERSION}" && -n "${INSTALLED_FLUTTER_VERSION}" && "${EXPECTED_FLUTTER_VERSION}" != "${INSTALLED_FLUTTER_VERSION}" ]]; then
  echo "WARNING: .flutter-version expects ${EXPECTED_FLUTTER_VERSION}, but local flutter is ${INSTALLED_FLUTTER_VERSION}." >&2
fi

API_BASE_URL_VALUE="${CONTENTGLOWS_DEVSERVER_API_BASE_URL:-${API_BASE_URL:-https://api.contentglows.com}}"
CLERK_PUBLISHABLE_KEY_VALUE="${CLERK_PUBLISHABLE_KEY:-}"
DEV_AUTH_BYPASS_VALUE="${CONTENTGLOWS_DEV_AUTH_BYPASS:-false}"
APP_SITE_URL_VALUE="${CONTENTGLOWS_DEVSERVER_SITE_URL:-${APP_SITE_URL:-https://contentglows.com}}"
APP_WEB_URL_VALUE="${CONTENTGLOWS_DEVSERVER_APP_WEB_URL:-${APP_WEB_URL:-https://app.contentglows.com}}"
BUILD_COMMIT_SHA_VALUE="${BUILD_COMMIT_SHA:-${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}}"
BUILD_ID_VALUE="${BUILD_ID:-${GITHUB_RUN_ID:-${VERCEL_GIT_COMMIT_SHA:-$BUILD_COMMIT_SHA_VALUE}}}"
BUILD_ENVIRONMENT_VALUE="${BUILD_ENVIRONMENT:-${VERCEL_ENV:-local}}"
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

if [[ "${DEV_AUTH_BYPASS_VALUE}" == "true" && "${BUILD_ENVIRONMENT_VALUE}" == "production" ]]; then
  echo "ERROR: CONTENTGLOWS_DEV_AUTH_BYPASS cannot be enabled for a production build." >&2
  exit 1
fi

if [[ "${DEV_AUTH_BYPASS_VALUE}" == "true" ]]; then
  CLERK_PUBLISHABLE_KEY_VALUE=""
fi

if [[ -z "${CLERK_PUBLISHABLE_KEY_VALUE}" && "${DEV_AUTH_BYPASS_VALUE}" != "true" ]]; then
  echo "ERROR: CLERK_PUBLISHABLE_KEY is required to build the Flutter web app." >&2
  echo "Run through Doppler or export CLERK_PUBLISHABLE_KEY before starting PM2." >&2
  exit 1
fi

flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL_VALUE}" \
  --dart-define=CLERK_PUBLISHABLE_KEY="${CLERK_PUBLISHABLE_KEY_VALUE}" \
  --dart-define=CONTENTGLOWS_DEV_AUTH_BYPASS="${DEV_AUTH_BYPASS_VALUE}" \
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

bash ./scripts/install-web-auth.sh ./build/web

exec node server.js "${PORT_VALUE}"

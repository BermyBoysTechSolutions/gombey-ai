#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/customer-backup.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gombey-customer-backup-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  echo "customer-backup test failed: $*" >&2
  exit 1
}

FIXTURE_REPO="$TEST_ROOT/repo"
FIXTURE_CUSTOMER="$FIXTURE_REPO/deploy/customer"
FIXTURE_ENV="$FIXTURE_CUSTOMER/.env"
PASS_FILE="$TEST_ROOT/recovery-key"
mkdir -p "$FIXTURE_CUSTOMER"
printf 'COMPOSE_PROJECT_NAME=backup-safety-test\nMONGO_DATABASE=GombeyAI\n' > "$FIXTURE_ENV"
chmod 600 "$FIXTURE_ENV"
printf 'test-only-random-recovery-secret\n' > "$PASS_FILE"
chmod 600 "$PASS_FILE"

expect_fail() {
  expected="$1"
  shift
  set +e
  "$@" > "$TEST_ROOT/stdout" 2> "$TEST_ROOT/stderr"
  result=$?
  set -e
  [[ "$result" -ne 0 ]] || fail "command unexpectedly succeeded"
  grep -Fq "$expected" "$TEST_ROOT/stderr" || fail "expected failure message was missing: $expected"
}

BASE_ENV=(env
  "GOMBEY_REPO_DIR=$FIXTURE_REPO"
  "GOMBEY_CUSTOMER_DIR=$FIXTURE_CUSTOMER"
  "GOMBEY_CUSTOMER_ENV_PATH=$FIXTURE_ENV"
)

expect_fail "encrypted backup required" "${BASE_ENV[@]}" "$BACKUP_SCRIPT" "$TEST_ROOT/backups"

chmod 644 "$FIXTURE_ENV"
expect_fail "customer .env must be mode 600" \
  "${BASE_ENV[@]}" "GOMBEY_BACKUP_PASSPHRASE_FILE=$PASS_FILE" "$BACKUP_SCRIPT" "$TEST_ROOT/backups"
chmod 600 "$FIXTURE_ENV"

chmod 644 "$PASS_FILE"
expect_fail "passphrase file must be mode 600" \
  "${BASE_ENV[@]}" "GOMBEY_BACKUP_PASSPHRASE_FILE=$PASS_FILE" "$BACKUP_SCRIPT" "$TEST_ROOT/backups"
chmod 600 "$PASS_FILE"

expect_fail "backup directory must be outside the Git checkout" \
  "${BASE_ENV[@]}" "GOMBEY_BACKUP_PASSPHRASE_FILE=$PASS_FILE" "$BACKUP_SCRIPT" "$FIXTURE_REPO/private-backups"

echo "customer-backup safety tests passed"

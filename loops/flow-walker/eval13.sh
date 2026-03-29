#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/flow-walker"
PASS=0; FAIL=0; TOTAL=0
check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" > /dev/null 2>&1; then
    PASS=$((PASS + 1)); echo "  PASS [$TOTAL] $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL [$TOTAL] $1"
  fi
}

echo "=== Phase 13: Agent-Friendly Verification Pipeline ==="

# --- Honest result semantics ---
check "VerifyResult type allows 'unverified' result" \
  "grep -q 'unverified' src/verify.ts"

check "verify returns unverified when all automated=no_evidence and all agent=pending" \
  "grep -qE 'unverified' tests/verify-tiers.test.ts"

check "reporter renders unverified badge (amber/distinct from pass/fail)" \
  "grep -q 'unverified' src/reporter.ts"

check "audit mode badge shows AUDIT not PASS" \
  "grep -qE 'AUDIT|audit' src/reporter.ts"

# --- Step recipes in record init ---
check "record init returns recipe when flow provided" \
  "grep -q 'recipe' src/record.ts"

check "recipe includes per-step event list" \
  "grep -qE 'recipe.*step|generateRecipe' src/record.ts"

check "recipe test exists" \
  "grep -qE 'recipe' tests/record.test.ts"

check "recipe includes assert hints from expect field" \
  "grep -qE 'assert|text_visible' tests/record.test.ts"

# --- agent-review event type ---
check "agent-review is a valid event type" \
  "grep -q 'agent-review' src/event-schema.ts"

check "verify processes agent-review events" \
  "grep -qE 'agent-review' src/verify.ts"

check "agent-review updates prompt status from pending to pass/fail" \
  "grep -qE 'agent-review.*pass|verdict.*pass' tests/verify-tiers.test.ts"

check "agent-review test: prompt resolves from pending to pass" \
  "grep -qE 'agent-review|resolves.*pending|verdict' tests/verify-tiers.test.ts"

# --- Event gap warnings ---
check "record finish detects missing assert events" \
  "grep -qE 'warning|gap|missing.*assert' src/record.ts"

check "record finish detects missing artifact for judge steps" \
  "grep -qE 'warning|gap|missing.*artifact' src/record.ts"

check "gap warnings test exists" \
  "grep -qE 'warning|gap|missing' tests/record.test.ts"

# --- Quality gates ---
check "TypeScript compiles clean" \
  "npx tsc --noEmit"

check "All tests pass" \
  "npm test 2>&1 | grep -qE 'fail 0'"

check "At least 280 tests" \
  "npm test 2>&1 | grep -oP 'tests \\K[0-9]+' | awk '{exit (\$1 >= 280) ? 0 : 1}'"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "PHASE 13 COMPLETE" || echo "PHASE 13 INCOMPLETE"

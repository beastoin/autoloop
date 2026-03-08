#!/usr/bin/env bash
# Immutable eval harness for Marionette integration autoresearch loop.
# Usage: bash autoresearch/eval.sh
# DO NOT MODIFY THIS FILE.

set -uo pipefail
cd "$(dirname "$0")/.."

# Ensure tools are on PATH
export PATH="/home/claude/tools/node/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# Node 22 needs this flag to run .ts files directly
export NODE_OPTIONS="--experimental-strip-types"

# Detect current phase from files
PHASE=1
if [ -f "src/platforms/flutter/element-converter.ts" ]; then
  PHASE=2
fi
if [ -f "src/platforms/flutter/matcher-builder.ts" ]; then
  PHASE=3
fi

echo "---"
echo "phase:            $PHASE"

# Step 1: Build
BUILD_STATUS="pass"
if pnpm build > /tmp/ad-eval-build.log 2>&1; then
  BUILD_STATUS="pass"
else
  BUILD_STATUS="fail"
fi
echo "build:            $BUILD_STATUS"

# Step 2: Typecheck
TYPECHECK_STATUS="pass"
if pnpm run typecheck > /tmp/ad-eval-typecheck.log 2>&1; then
  TYPECHECK_STATUS="pass"
else
  TYPECHECK_STATUS="fail"
fi
echo "typecheck:        $TYPECHECK_STATUS"

# Step 3: Existing tests (must not regress)
EXISTING_STATUS="pass"
EXISTING_COUNT="0"
if pnpm test:unit > /tmp/ad-eval-existing.log 2>&1; then
  EXISTING_STATUS="pass"
  EXISTING_COUNT=$(grep -cE "^ok |# pass" /tmp/ad-eval-existing.log 2>/dev/null || echo "0")
else
  EXISTING_STATUS="fail"
  EXISTING_COUNT=$(grep -cE "^not ok|# fail" /tmp/ad-eval-existing.log 2>/dev/null || echo "0")
fi
echo "existing_tests:   $EXISTING_STATUS ($EXISTING_COUNT)"

# Step 4: Flutter tests (new tests for this integration)
FLUTTER_STATUS="N/A"
FLUTTER_COUNT="0"
if [ -d "src/platforms/flutter/__tests__" ]; then
  FLUTTER_TEST_FILES=$(find src/platforms/flutter/__tests__ -name '*.test.ts' 2>/dev/null)
  if [ -n "$FLUTTER_TEST_FILES" ]; then
    if node --test $FLUTTER_TEST_FILES > /tmp/ad-eval-flutter.log 2>&1; then
      FLUTTER_STATUS="pass"
      FLUTTER_COUNT=$(grep -cE "^ok |# pass" /tmp/ad-eval-flutter.log 2>/dev/null || echo "0")
    else
      FLUTTER_STATUS="fail"
      FLUTTER_COUNT=$(grep -cE "^not ok|# fail" /tmp/ad-eval-flutter.log 2>/dev/null || echo "0")
    fi
  else
    FLUTTER_STATUS="no_tests"
  fi
else
  FLUTTER_STATUS="no_tests"
fi
echo "flutter_tests:    $FLUTTER_STATUS ($FLUTTER_COUNT)"

# Step 5: Count new/changed lines
TOTAL_FILES="0"
NEW_LINES="0"
if [ -d "src/platforms/flutter" ]; then
  TOTAL_FILES=$(find src/platforms/flutter -name '*.ts' 2>/dev/null | wc -l)
  NEW_LINES=$(find src/platforms/flutter -name '*.ts' 2>/dev/null -exec cat {} + 2>/dev/null | wc -l)
fi
if [ -f "src/daemon/handlers/flutter.ts" ]; then
  HANDLER_LINES=$(wc -l < src/daemon/handlers/flutter.ts)
  NEW_LINES=$((NEW_LINES + HANDLER_LINES))
  TOTAL_FILES=$((TOTAL_FILES + 1))
fi
echo "total_files:      $TOTAL_FILES"
echo "new_lines:        $NEW_LINES"

# Phase gate check
PHASE_COMPLETE="no"
if [ "$BUILD_STATUS" = "pass" ] && [ "$TYPECHECK_STATUS" = "pass" ] && [ "$EXISTING_STATUS" = "pass" ]; then
  case $PHASE in
    1)
      if [ -f "src/platforms/flutter/vm-service-client.ts" ] && \
         [ -f "src/daemon/handlers/flutter.ts" ] && \
         [ "$FLUTTER_STATUS" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    2)
      if [ -f "src/platforms/flutter/element-converter.ts" ] && \
         [ "$FLUTTER_STATUS" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
    3)
      if [ -f "src/platforms/flutter/matcher-builder.ts" ] && \
         [ "$FLUTTER_STATUS" = "pass" ]; then
        PHASE_COMPLETE="yes"
      fi
      ;;
  esac
fi
echo "phase_complete:   $PHASE_COMPLETE"
echo "---"

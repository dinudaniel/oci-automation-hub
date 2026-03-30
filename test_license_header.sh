#!/bin/bash
# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

# Test script for check_license_header.yml logic
# Creates temporary test files, runs the header check logic against them,
# and verifies expected pass/fail results.

set -euo pipefail

CURRENT_YEAR=$(date +%Y)
LICENSE_TEXT_COPYRIGHT="Copyright (c) 2024, ${CURRENT_YEAR}, Oracle and/or its affiliates. All rights reserved."
LICENSE_TEXT_UPL="The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASSED=0
TOTAL=0

# ── Helper: run the check logic against a single file ──
check_file() {
  local FILE="$1"

  if [[ "$FILE" == *.md ]] || [[ "$FILE" == *.json ]]; then
    echo "SKIP"
    return
  fi

  if [ ! -f "$FILE" ] || ! file "$FILE" | grep -q text; then
    echo "SKIP"
    return
  fi

  case "$FILE" in
    *.go|*.java)  PREFIX="//" ;;
    *.html)       PREFIX="HTML" ;;
    *.sql)        PREFIX="--" ;;
    *)            PREFIX="#" ;;
  esac

  if [[ "$PREFIX" == "HTML" ]]; then
    LINE1="<!-- ${LICENSE_TEXT_COPYRIGHT} -->"
    LINE2="<!-- ${LICENSE_TEXT_UPL} -->"
  else
    LINE1="${PREFIX} ${LICENSE_TEXT_COPYRIGHT}"
    LINE2="${PREFIX} ${LICENSE_TEXT_UPL}"
  fi

  if [[ "$FILE" == *.sh ]]; then
    SHEBANG=$(sed -n '1p' "$FILE")
    if [[ "$SHEBANG" != \#!* ]]; then
      echo "BAD"
      return
    fi
    ACTUAL_LINE1=$(sed -n '3p' "$FILE")
    ACTUAL_LINE2=$(sed -n '4p' "$FILE")
  else
    ACTUAL_LINE1=$(sed -n '1p' "$FILE")
    ACTUAL_LINE2=$(sed -n '2p' "$FILE")
  fi

  if [ "$ACTUAL_LINE1" = "$LINE1" ] && [ "$ACTUAL_LINE2" = "$LINE2" ]; then
    echo "GOOD"
  else
    echo "BAD"
  fi
}

# ── Helper: assert expected result ──
assert_result() {
  local test_name="$1"
  local expected="$2"
  local file="$3"

  TOTAL=$((TOTAL + 1))
  result=$(check_file "$file")

  if [ "$result" = "$expected" ]; then
    PASSED=$((PASSED + 1))
    echo "  PASS  $test_name"
  else
    echo "  FAIL  $test_name (expected=$expected, got=$result)"
  fi
}

# ══════════════════════════════════════════════
# Test cases
# ══════════════════════════════════════════════

echo ""
echo "=== YAML / TF / PY (# prefix) ==="

cat > "$TMPDIR/good.yml" <<EOF
# ${LICENSE_TEXT_COPYRIGHT}
# ${LICENSE_TEXT_UPL}

name: test
EOF
assert_result "yml with correct header" "GOOD" "$TMPDIR/good.yml"

cat > "$TMPDIR/good.tf" <<EOF
# ${LICENSE_TEXT_COPYRIGHT}
# ${LICENSE_TEXT_UPL}

variable "test" {}
EOF
assert_result "tf with correct header" "GOOD" "$TMPDIR/good.tf"

cat > "$TMPDIR/bad.yml" <<EOF
name: test
EOF
assert_result "yml missing header" "BAD" "$TMPDIR/bad.yml"

cat > "$TMPDIR/wrong.py" <<EOF
# Wrong copyright line
# ${LICENSE_TEXT_UPL}
EOF
assert_result "py with wrong line 1" "BAD" "$TMPDIR/wrong.py"

echo ""
echo "=== Shell (.sh) ==="

cat > "$TMPDIR/good.sh" <<EOF
#!/bin/bash

# ${LICENSE_TEXT_COPYRIGHT}
# ${LICENSE_TEXT_UPL}

echo "hello"
EOF
assert_result "sh with correct header after shebang" "GOOD" "$TMPDIR/good.sh"

cat > "$TMPDIR/no_shebang.sh" <<EOF
# ${LICENSE_TEXT_COPYRIGHT}
# ${LICENSE_TEXT_UPL}
EOF
assert_result "sh missing shebang" "BAD" "$TMPDIR/no_shebang.sh"

cat > "$TMPDIR/bad_header.sh" <<EOF
#!/bin/bash

# wrong line
# ${LICENSE_TEXT_UPL}
EOF
assert_result "sh with wrong header line 1" "BAD" "$TMPDIR/bad_header.sh"

echo ""
echo "=== Go (.go) ==="

cat > "$TMPDIR/good.go" <<EOF
// ${LICENSE_TEXT_COPYRIGHT}
// ${LICENSE_TEXT_UPL}

package main
EOF
assert_result "go with correct header" "GOOD" "$TMPDIR/good.go"

cat > "$TMPDIR/bad.go" <<EOF
package main
EOF
assert_result "go missing header" "BAD" "$TMPDIR/bad.go"

echo ""
echo "=== Java (.java) ==="

cat > "$TMPDIR/good.java" <<EOF
// ${LICENSE_TEXT_COPYRIGHT}
// ${LICENSE_TEXT_UPL}

public class Test {}
EOF
assert_result "java with correct header" "GOOD" "$TMPDIR/good.java"

cat > "$TMPDIR/bad.java" <<EOF
public class Test {}
EOF
assert_result "java missing header" "BAD" "$TMPDIR/bad.java"

echo ""
echo "=== HTML (.html) ==="

cat > "$TMPDIR/good.html" <<EOF
<!-- ${LICENSE_TEXT_COPYRIGHT} -->
<!-- ${LICENSE_TEXT_UPL} -->

<html></html>
EOF
assert_result "html with correct header" "GOOD" "$TMPDIR/good.html"

cat > "$TMPDIR/bad.html" <<EOF
<html></html>
EOF
assert_result "html missing header" "BAD" "$TMPDIR/bad.html"

echo ""
echo "=== SQL (.sql) ==="

cat > "$TMPDIR/good.sql" <<EOF
-- ${LICENSE_TEXT_COPYRIGHT}
-- ${LICENSE_TEXT_UPL}

SELECT 1;
EOF
assert_result "sql with correct header" "GOOD" "$TMPDIR/good.sql"

cat > "$TMPDIR/bad.sql" <<EOF
SELECT 1;
EOF
assert_result "sql missing header" "BAD" "$TMPDIR/bad.sql"

echo ""
echo "=== Skipped file types ==="

cat > "$TMPDIR/readme.md" <<EOF
No header here
EOF
assert_result "md file skipped" "SKIP" "$TMPDIR/readme.md"

cat > "$TMPDIR/data.json" <<EOF
{"key": "value"}
EOF
assert_result "json file skipped" "SKIP" "$TMPDIR/data.json"

# ── Summary ──
echo ""
echo "==============================="
echo "  Results: ${PASSED}/${TOTAL} passed"
echo "==============================="

if [ "$PASSED" -ne "$TOTAL" ]; then
  exit 1
fi

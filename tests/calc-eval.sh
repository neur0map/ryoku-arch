#!/usr/bin/env bash
# Fixture test for ryoku-cmd-calc's Python fallback: qalc is preferred when
# present, but the launcher must still evaluate math on a fresh install before
# qalc lands. Runs the script with PATH stripped of qalc so the fallback is
# always exercised, and asserts the acceptance cases (basic ops, ^ as power,
# math functions, constants, percentages, and the "print nothing on error"
# contract) hold on plain bash + python3.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
calc="$here/../ryoku/hyprland/scripts/ryoku-cmd-calc"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required" >&2
  exit 0
fi

# Force the Python fallback so this test exercises the qalc-less path regardless
# of whether the box has libqalculate. An empty PATH shim is not enough: qalc
# lives in /usr/bin, which the script still needs on PATH for python3 and bash.
# So drop a stub `qalc` that exits nonzero into the shim dir and put it first;
# the script's `command -v qalc` finds the stub, it fails, and the Python
# evaluator takes over, which is exactly the code under test.
shim="$(mktemp -d)"
trap 'rm -rf "$shim"' EXIT
printf '#!/bin/sh\nexit 1\n' > "$shim/qalc"
chmod +x "$shim/qalc"
export PATH="$shim:/usr/bin:/bin"

fail=0
pass=0
assert_eq() {  # assert_eq EXPR EXPECTED MSG
  local got
  got="$(bash "$calc" "$1" || true)"
  if [[ "$got" == "$2" ]]; then
    printf 'PASS %s\n' "$3"
    pass=$((pass + 1))
  else
    printf 'FAIL %s\n  expr     %q\n  expected %q\n  got      %q\n' \
      "$3" "$1" "$2" "$got" >&2
    fail=$((fail + 1))
  fi
}

# Basic arithmetic still works after the rewrite.
assert_eq "2+2"          "4"    "addition"
assert_eq "1+2*3"        "7"    "precedence"
assert_eq "(2+3)*4"      "20"   "parens"
assert_eq "-3+1"         "-2"   "unary minus"
assert_eq ".5*2"         "1"    "leading decimal"
assert_eq "10 // 3"      "3"    "floor division"
assert_eq "10 % 3"      "1"    "modulo"

# ^ maps to power, per the acceptance list.
assert_eq "2^10"         "1024" "caret power"
assert_eq "2**10"        "1024" "double-star power still works"

# Math whitelist.
assert_eq "sqrt(16)"     "4"    "sqrt"
assert_eq "sin(0)"       "0"    "sin"
assert_eq "cos(0)"       "1"    "cos"
assert_eq "log10(100)"   "2"    "log10"
assert_eq "log2(8)"      "3"    "log2"
assert_eq "ln(e)"        "1"    "ln alias for log"
assert_eq "abs(-5)"      "5"    "abs"
assert_eq "floor(3.7)"   "3"    "floor"
assert_eq "ceil(3.1)"    "4"    "ceil"
assert_eq "factorial(5)" "120"  "factorial"
assert_eq "hypot(3,4)"   "5"    "hypot"
assert_eq "pow(2,8)"     "256"  "pow"

# Constants.
assert_eq "pi"           "3.1415926536" "pi constant"
assert_eq "tau"          "6.2831853072" "tau constant"
assert_eq "e"            "2.7182818285" "e constant"

# Percentages: bare %, "X% of Y", and additive form.
assert_eq "15% of 200"   "30"   "X% of Y"
assert_eq "200 + 10%"    "220"  "additive percentage adds 10 percent of 200"
assert_eq "50%"          "0.5"  "bare percentage"

# The 'print nothing on error' contract: unknown names, non-whitelisted calls,
# strings, imports, and plain text MUST print nothing and exit 0.
assert_eq ""             ""     "empty prints nothing"
assert_eq "firefox"      ""     "app name prints nothing"
assert_eq "sqrt"         ""     "bare function name prints nothing"
assert_eq "eval('1+1')"  ""     "eval() call is rejected"
assert_eq "__import__('os')" "" "dunder import is rejected"
assert_eq "open('x')"    ""     "open() is not whitelisted"
assert_eq "'a'+'b'"      ""     "string concat is rejected"
assert_eq "1+"           ""     "syntax error prints nothing"

# The trailing '=' some users type is stripped before eval.
assert_eq "2+2="         "4"    "trailing equals is stripped"

# Hand-typed multiplication and division signs: a bare x/X between operands, the
# cross sign, and the division sign. This is the "4+3x43" a person actually types.
assert_eq "4+3x43"       "133"  "x as multiply in a sum"
assert_eq "12x34"        "408"  "bare x multiply"
assert_eq "2x3x4"        "24"   "chained x multiply"
assert_eq "(2+3)x4"      "20"   "x after a paren"
assert_eq "6×7"          "42"   "cross sign multiply"
assert_eq "10÷2"         "5"    "division sign"

if (( fail > 0 )); then
  echo "calc-eval: $fail test(s) FAILED, $pass passed" >&2
  exit 1
fi
echo "calc-eval: all $pass checks passed"

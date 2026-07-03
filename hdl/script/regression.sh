#!/usr/bin/env bash
# SPDX-License-Identifier: MIT


set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hdl_dir="$(cd "$script_dir/.." && pwd)"
log_dir="$hdl_dir/build/regression"

default_tests=(
    TestBaudGen
    TestUartRx
    TestUartTx
    TestUartRxModes
    TestUartRxOverflow
    TestUartLoopback
    TestUartCore
    TestUartAxisBridge
    TestUartAxisBridgeCsr
    TestUartAxiLiteMaster
)

if [ "$#" -gt 0 ]; then
    tests=("$@")
elif [ -n "${REGRESSION_TESTS:-}" ]; then
    # shellcheck disable=SC2206
    tests=(${REGRESSION_TESTS})
else
    tests=("${default_tests[@]}")
fi

mkdir -p "$log_dir"

if [ -t 1 ]; then
    bold="$(printf '\033[1m')"
    green="$(printf '\033[32m')"
    red="$(printf '\033[31m')"
    yellow="$(printf '\033[33m')"
    reset="$(printf '\033[0m')"
else
    bold=""
    green=""
    red=""
    yellow=""
    reset=""
fi

declare -a names
declare -a results
declare -a durations

passes=0
failures=0

printf "%sRunning %d regression tests%s\n" "$bold" "${#tests[@]}" "$reset"
printf "Logs: %s\n\n" "$log_dir"

for test in "${tests[@]}"; do
    log="$log_dir/${test}.log"
    start=$SECONDS

    printf "%-28s" "$test"
    if make -C "$hdl_dir" RUN_TEST="$test" sim >"$log" 2>&1; then
        duration=$((SECONDS - start))
        printf " %sPASS%s %4ss\n" "$green" "$reset" "$duration"
        result="PASS"
        passes=$((passes + 1))
    else
        duration=$((SECONDS - start))
        printf " %sFAIL%s %4ss\n" "$red" "$reset" "$duration"
        result="FAIL"
        failures=$((failures + 1))
    fi

    names+=("$test")
    results+=("$result")
    durations+=("$duration")
done

printf "\n%sRegression summary%s\n" "$bold" "$reset"
printf "%-28s %-8s %8s %s\n" "Test" "Result" "Time" "Log"
printf "%-28s %-8s %8s %s\n" "----" "------" "----" "---"

for i in "${!names[@]}"; do
    test="${names[$i]}"
    result="${results[$i]}"
    duration="${durations[$i]}"
    log="$log_dir/${test}.log"

    if [ "$result" = "PASS" ]; then
        color="$green"
    else
        color="$red"
    fi

    printf "%-28s %s%-8s%s %7ss %s\n" "$test" "$color" "$result" "$reset" "$duration" "$log"
done

printf "\n%s%d passed%s, " "$green" "$passes" "$reset"
printf "%s%d failed%s\n" "$red" "$failures" "$reset"

if [ "$failures" -ne 0 ]; then
    printf "\n%sFailing test log tails:%s\n" "$yellow" "$reset"
    for i in "${!names[@]}"; do
        if [ "${results[$i]}" = "FAIL" ]; then
            test="${names[$i]}"
            log="$log_dir/${test}.log"
            printf "\n%s==> %s <==%s\n" "$yellow" "$log" "$reset"
            tail -n 40 "$log"
        fi
    done
    exit 1
fi


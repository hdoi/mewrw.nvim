#!/bin/bash

# run_tests.sh
# Run all Neovim plugin tests in a clean environment.

echo "========================================"
echo "   Running All mewrw Tests"
echo "========================================"

FAILED_TESTS=()
PASSED_COUNT=0

# Use nvim -u NONE to avoid user config interference
for test_file in tests/test_*.lua; do
    echo "Running: $test_file"
    echo "----------------------------------------"
    
    # Run test and capture output
    nvim -u NONE --headless -c "luafile $test_file" -c "q"
    
    if [ $? -eq 0 ]; then
        echo "Result: PASSED"
        ((PASSED_COUNT++))
    else
        echo "Result: FAILED"
        FAILED_TESTS+=("$test_file")
    fi
    # Add a small sleep to let async filesystem operations settle
    sleep 0.5
done

echo "========================================"
echo "Summary: $PASSED_COUNT Passed, ${#FAILED_TESTS[@]} Failed"

if [ ${#FAILED_TESTS[@]} -ne 0 ]; then
    echo "Failed Tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    exit 1
else
    echo "ALL TESTS PASSED!"
    exit 0
fi

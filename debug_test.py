#!/usr/bin/env python3

import subprocess
import sys

def run_single_test(test_name):
    """Run a single test and capture the full output"""
    print(f"\n=== Running {test_name} ===")

    cmd = [
        'make',
        f'COCOTB_TEST_MODULES=test',
        f'COCOTB_TESTCASE={test_name}',
        'sim'
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd='test')
        print("STDOUT:", result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        print("Return code:", result.returncode)
    except Exception as e:
        print(f"Error running test: {e}")

if __name__ == "__main__":
    # Run each failing test individually to see the exact errors
    run_single_test("test_step_mode")
    print("\n" + "="*80 + "\n")
    run_single_test("test_io_connectivity")
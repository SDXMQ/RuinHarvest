#!/usr/bin/env python3
"""
scripts/tools/run_e2e_tests.py
RuinHarvest Automated E2E Test Suite Runner
Executes 161+ comprehensive tests across Tiers 1 to 4 covering R1 through R14.
Provides clear ANSI colored console reporting, tier filtering, and JSON artifact export.
"""

import os
import sys
import argparse
import json
import time
from typing import List, Dict, Any

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from tests.e2e.framework import BaseE2ETestCase, TestResult
from tests.e2e.tier1_functional import get_tier1_tests
from tests.e2e.tier2_boundaries import get_tier2_tests
from tests.e2e.tier3_interactions import get_tier3_tests
from tests.e2e.tier4_workloads import get_tier4_tests

# ANSI Terminal Colors
class Color:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    GREEN = "\033[32m"
    RED = "\033[31m"
    YELLOW = "\033[33m"
    CYAN = "\033[36m"
    MAGENTA = "\033[35m"
    GRAY = "\033[90m"
    BG_GREEN = "\033[42m\033[30m"
    BG_RED = "\033[41m\033[37m"

def print_header(title: str):
    width = 80
    print("\n" + Color.CYAN + "=" * width + Color.RESET)
    print(Color.BOLD + Color.CYAN + f" {title}".ljust(width) + Color.RESET)
    print(Color.CYAN + "=" * width + Color.RESET)

def run_suite(tests: List[BaseE2ETestCase], verbose: bool = False) -> List[TestResult]:
    results: List[TestResult] = []
    for test in tests:
        res = test.run()
        results.append(res)
        
        status_tag = f"{Color.GREEN}[PASS]{Color.RESET}" if res.passed else f"{Color.RED}[FAIL]{Color.RESET}"
        tier_tag = f"{Color.MAGENTA}T{res.tier}{Color.RESET}"
        feat_tag = f"{Color.YELLOW}{res.feature:<10}{Color.RESET}"
        
        if verbose or not res.passed:
            timing = f"{Color.GRAY}({res.duration_ms:.2f}ms){Color.RESET}"
            print(f" {status_tag} {tier_tag} {feat_tag} {res.test_id} - {res.name} {timing}")
            if not res.passed:
                print(f"        {Color.RED}>>> Error: {res.error_message}{Color.RESET}")
        else:
            # Compact dot reporting when not verbose
            sys.stdout.write(f"{Color.GREEN}.{Color.RESET}")
            sys.stdout.flush()

    if not verbose:
        print() # Newline after compact dots
    return results

def main():
    parser = argparse.ArgumentParser(description="RuinHarvest E2E Test Suite Runner")
    parser.add_argument("--tier", type=int, choices=[1, 2, 3, 4], help="Run only tests from a specific tier (1, 2, 3, or 4)")
    parser.add_argument("--feature", type=str, help="Run only tests matching a specific feature tag (e.g. R1, R2, R12)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose test-by-test logging")
    parser.add_argument("--report-json", type=str, help="Export test results to a JSON file")
    args = parser.parse_args()

    t_start = time.perf_counter()

    print_header("RUINHARVEST AUTOMATED E2E TEST SUITE")
    print(f"Working Directory: {PROJECT_ROOT}")
    print(f"Integrity Specification: ORIGINAL_REQUEST.md & PROJECT.md (R1 ~ R14)")

    # Collect tests based on filters
    test_suite: List[BaseE2ETestCase] = []
    
    t1_all = get_tier1_tests()
    t2_all = get_tier2_tests()
    t3_all = get_tier3_tests()
    t4_all = get_tier4_tests()

    if args.tier is None or args.tier == 1:
        test_suite.extend(t1_all)
    if args.tier is None or args.tier == 2:
        test_suite.extend(t2_all)
    if args.tier is None or args.tier == 3:
        test_suite.extend(t3_all)
    if args.tier is None or args.tier == 4:
        test_suite.extend(t4_all)

    if args.feature:
        feat_query = args.feature.upper()
        test_suite = [t for t in test_suite if feat_query in t.feature.upper()]

    print(f"Selected Test Cases: {len(test_suite)} across active tiers")
    if args.tier:
        print(f"Filtered by Tier: {args.tier}")
    if args.feature:
        print(f"Filtered by Feature: {args.feature}")

    print("\nExecuting tests...")
    results = run_suite(test_suite, verbose=args.verbose)

    t_end = time.perf_counter()
    total_elapsed_sec = t_end - t_start

    # Aggregation
    total_count = len(results)
    pass_count = sum(1 for r in results if r.passed)
    fail_count = total_count - pass_count

    # Tier breakdown
    tier_stats: Dict[int, Dict[str, int]] = {1: {"total": 0, "pass": 0}, 2: {"total": 0, "pass": 0}, 3: {"total": 0, "pass": 0}, 4: {"total": 0, "pass": 0}}
    for r in results:
        tier_stats[r.tier]["total"] += 1
        if r.passed:
            tier_stats[r.tier]["pass"] += 1

    print_header("TEST SUITE EXECUTION SUMMARY")
    print(f"  Tier 1 (Functional Baseline)    : {tier_stats[1]['pass']:>3}/{tier_stats[1]['total']:<3} Passed")
    print(f"  Tier 2 (Boundaries & Edge Cases): {tier_stats[2]['pass']:>3}/{tier_stats[2]['total']:<3} Passed")
    print(f"  Tier 3 (Pairwise Interactions)  : {tier_stats[3]['pass']:>3}/{tier_stats[3]['total']:<3} Passed")
    print(f"  Tier 4 (Raid Workload Scenarios): {tier_stats[4]['pass']:>3}/{tier_stats[4]['total']:<3} Passed")
    print("-" * 80)
    print(f"  TOTAL TESTS RUN   : {total_count}")
    print(f"  PASSED            : {Color.GREEN}{pass_count}{Color.RESET}")
    print(f"  FAILED            : {Color.RED if fail_count > 0 else Color.GREEN}{fail_count}{Color.RESET}")
    pass_rate = (pass_count / total_count * 100.0) if total_count > 0 else 0.0
    print(f"  PASS RATE         : {Color.BOLD}{pass_rate:.1f}%{Color.RESET}")
    print(f"  TOTAL DURATION    : {total_elapsed_sec:.3f} seconds")
    print("-" * 80)

    # Failures detail
    if fail_count > 0:
        print(f"\n{Color.RED}{Color.BOLD}FAILURES DETECTED ({fail_count}):{Color.RESET}")
        for r in results:
            if not r.passed:
                print(f"  - [{r.test_id}] {r.name} (Tier {r.tier}, {r.feature})")
                print(f"    Error: {r.error_message}")
        print()

    # Export JSON if requested
    if args.report_json:
        report_data = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total": total_count,
            "passed": pass_count,
            "failed": fail_count,
            "pass_rate_percent": pass_rate,
            "duration_sec": total_elapsed_sec,
            "tier_breakdown": tier_stats,
            "results": [
                {
                    "test_id": r.test_id,
                    "name": r.name,
                    "tier": r.tier,
                    "feature": r.feature,
                    "passed": r.passed,
                    "duration_ms": r.duration_ms,
                    "error": r.error_message
                }
                for r in results
            ]
        }
        with open(args.report_json, "w", encoding="utf-8") as f:
            json.dump(report_data, f, indent=2, ensure_ascii=False)
        print(f"{Color.CYAN}Exported JSON report to: {args.report_json}{Color.RESET}")

    if fail_count == 0:
        print(f"\n{Color.BG_GREEN}{Color.BOLD} >>> ALL {total_count} E2E TESTS PASSED SUCCESSFULLY! <<< {Color.RESET}\n")
        sys.exit(0)
    else:
        print(f"\n{Color.BG_RED}{Color.BOLD} >>> {fail_count} TEST(S) FAILED! <<< {Color.RESET}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()

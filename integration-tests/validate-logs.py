#!/usr/bin/env python3
"""
validate-logs.py — Validate log output from all running gRPC services.

Collects logs from Docker containers started by docker-compose and
checks for:
  - Server startup messages (gRPC server started)
  - Error/panic indicators
  - Health check registration
  - RPC call handling evidence

Usage:
  python3 validate-logs.py [--docker-compose-dir .]
"""
import subprocess
import sys
import os
import re
import argparse
from pathlib import Path

# Services to check — these names match docker-compose service names
SERVICES = ["go-server", "java-server", "python-server", "node-server", "rust-server"]

# Patterns that indicate successful startup
STARTUP_PATTERNS = [
    re.compile(r"start.*grpc.*server", re.IGNORECASE),
    re.compile(r"server.*started", re.IGNORECASE),
    re.compile(r"listening.*\d+", re.IGNORECASE),
    re.compile(r"registered.*service", re.IGNORECASE),
]

# Patterns that indicate errors
ERROR_PATTERNS = [
    re.compile(r"\bfatal\b", re.IGNORECASE),
    re.compile(r"\bpanic\b", re.IGNORECASE),
    re.compile(r"traceback", re.IGNORECASE),
    re.compile(r"unhandled exception", re.IGNORECASE),
    re.compile(r"connection refused", re.IGNORECASE),
]

# Patterns that indicate RPC handling
RPC_PATTERNS = [
    re.compile(r"talk.*request", re.IGNORECASE),
    re.compile(r"unary.*rpc", re.IGNORECASE),
    re.compile(r"received.*data", re.IGNORECASE),
]


def get_container_logs(service: str) -> str:
    """Get logs from a docker-compose service."""
    try:
        result = subprocess.run(
            ["docker-compose", "logs", "--tail=200", service],
            capture_output=True, text=True, timeout=30
        )
        return result.stdout + result.stderr
    except Exception as e:
        return f"[ERROR fetching logs: {e}]"


def validate_service(name: str, logs: str) -> dict:
    """Validate logs for a single service."""
    result = {
        "service": name,
        "has_startup": False,
        "has_errors": False,
        "has_rpc": False,
        "error_lines": [],
        "status": "PASS",
        "reason": "",
    }

    for line in logs.splitlines():
        for pattern in STARTUP_PATTERNS:
            if pattern.search(line):
                result["has_startup"] = True
        for pattern in RPC_PATTERNS:
            if pattern.search(line):
                result["has_rpc"] = True
        for pattern in ERROR_PATTERNS:
            if pattern.search(line):
                result["has_errors"] = True
                result["error_lines"].append(line.strip()[:200])

    if not result["has_startup"]:
        result["status"] = "WARN"
        result["reason"] = "no startup message found"
    if result["has_errors"]:
        result["status"] = "FAIL"
        result["reason"] = f"error patterns found ({len(result['error_lines'])} lines)"

    return result


def main():
    parser = argparse.ArgumentParser(description="Validate gRPC service logs")
    parser.add_argument("--dir", default=".", help="docker-compose directory")
    args = parser.parse_args()

    os.chdir(args.dir)

    print("=" * 60)
    print("  Log Validation")
    print("=" * 60)

    all_pass = True
    results = []

    for service in SERVICES:
        print(f"\n  [{service}]")
        logs = get_container_logs(service)

        if logs.startswith("[ERROR"):
            print(f"    ERROR: could not fetch logs: {logs}")
            results.append({"service": service, "status": "ERROR", "reason": "log fetch failed"})
            all_pass = False
            continue

        result = validate_service(service, logs)
        results.append(result)

        print(f"    Startup: {'YES' if result['has_startup'] else 'NO'}")
        print(f"    RPC evidence: {'YES' if result['has_rpc'] else 'NO'}")
        print(f"    Errors: {'YES' if result['has_errors'] else 'NO'}")
        print(f"    Status: {result['status']}")

        if result["status"] != "PASS":
            all_pass = False
            if result["error_lines"]:
                print(f"    Error lines (first 3):")
                for line in result["error_lines"][:3]:
                    print(f"      > {line}")

    print("\n" + "=" * 60)
    print("  LOG VALIDATION SUMMARY")
    print("=" * 60)
    for r in results:
        status_icon = "✅" if r["status"] == "PASS" else "❌" if r["status"] == "FAIL" else "⚠️"
        print(f"  {status_icon} {r['service']}: {r['status']}"
              + (f" ({r['reason']})" if r.get("reason") else ""))

    if not all_pass:
        print("\n  Some services have issues — check logs for details.")
        sys.exit(1)
    else:
        print("\n  All services validated successfully.")


if __name__ == "__main__":
    main()

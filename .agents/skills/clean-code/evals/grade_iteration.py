#!/usr/bin/env python3
"""Grade clean-code eval runs for a benchmark iteration."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


VALIDATION_KEYWORDS = ("Passed", "Not run", "Blockers", "did not run successfully", "code 127")
SKIP_DIR_NAMES = {"target", "node_modules", ".git", "__pycache__"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n")


def find_text_files(root: Path, suffix: str) -> list[Path]:
    return sorted(path for path in root.rglob(f"*{suffix}") if path.is_file())


def sum_output_chars(root: Path) -> int:
    total = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if any(part in SKIP_DIR_NAMES for part in path.parts):
            continue
        try:
            total += len(path.read_text(errors="replace"))
        except OSError:
            continue
    return total


def collect_residual_risks(report_path: Path) -> list[str]:
    if not report_path.exists():
        return []

    content = report_path.read_text(errors="replace")
    match = re.search(r"^## Residual [Rr]isks\n\n([\s\S]*?)(?=^## |\Z)", content, re.MULTILINE)
    if not match:
        return []

    return [line[2:].strip() for line in match.group(1).splitlines() if line.startswith("- ")]


def grade_typescript(run_dir: Path, assertions: list[str]) -> list[dict]:
    outputs_dir = run_dir / "outputs"
    index_path = outputs_dir / "src" / "reports" / "index.ts"
    route_path = outputs_dir / "src" / "ui" / "admin" / "routes" / "exportUserReport.ts"
    legacy_path = outputs_dir / "src" / "features" / "reports" / "userReportService.ts"
    report_path = outputs_dir / "report.md"

    results = []

    index_exists = index_path.exists() and "createUserReport" in index_path.read_text(errors="replace")
    results.append({
        "text": assertions[0],
        "passed": index_exists,
        "evidence": (
            f"Found stable entry at {index_path.relative_to(run_dir)}"
            if index_exists
            else f"Missing stable entry or createUserReport export at {index_path.relative_to(run_dir)}"
        ),
    })

    deep_relative_hits = []
    for path in find_text_files(outputs_dir / "src", ".ts"):
        content = path.read_text(errors="replace")
        if re.search(r"from\s+[\"'](?:\.\./){2,}", content):
            deep_relative_hits.append(str(path.relative_to(run_dir)))
    no_deep_relative = not deep_relative_hits
    results.append({
        "text": assertions[1],
        "passed": no_deep_relative,
        "evidence": (
            "No ../../ or ../../../ imports remain under src/."
            if no_deep_relative
            else f"Found deep relative imports in: {', '.join(deep_relative_hits)}"
        ),
    })

    route_imports = []
    if route_path.exists():
        route_content = route_path.read_text(errors="replace")
        route_imports = re.findall(r"from\s+[\"']([^\"']+)[\"']", route_content)
    route_uses_only_facade = bool(route_imports) and all(module == "@/reports" for module in route_imports)
    results.append({
        "text": assertions[2],
        "passed": route_uses_only_facade,
        "evidence": (
            f"Route imports only stable facade modules: {', '.join(route_imports)}"
            if route_uses_only_facade
            else f"Route imports are not fully narrowed to @/reports: {', '.join(route_imports) or 'none found'}"
        ),
    })

    legacy_removed = not legacy_path.exists()
    results.append({
        "text": assertions[3],
        "passed": legacy_removed,
        "evidence": (
            f"Legacy file removed: {legacy_path.relative_to(run_dir)}"
            if legacy_removed
            else f"Legacy compatibility layer still exists: {legacy_path.relative_to(run_dir)}"
        ),
    })

    report_content = report_path.read_text(errors="replace") if report_path.exists() else ""
    report_has_validation = report_path.exists() and "## Validation" in report_content and any(
        keyword in report_content for keyword in VALIDATION_KEYWORDS
    )
    results.append({
        "text": assertions[4],
        "passed": report_has_validation,
        "evidence": (
            f"Validation details recorded in {report_path.relative_to(run_dir)}"
            if report_has_validation
            else f"Validation details missing from {report_path.relative_to(run_dir)}"
        ),
    })

    return results


def grade_rust(run_dir: Path, assertions: list[str]) -> list[dict]:
    outputs_dir = run_dir / "outputs"
    invoice_path = outputs_dir / "src" / "invoice" / "mod.rs"
    lib_path = outputs_dir / "src" / "lib.rs"
    report_path = outputs_dir / "report.md"

    results = []

    invoice_content = invoice_path.read_text(errors="replace") if invoice_path.exists() else ""
    documented_generate = bool(
        invoice_path.exists()
        and "///" in invoice_content
        and re.search(r"pub\s+fn\s+generate\b", invoice_content)
    )
    results.append({
        "text": assertions[0],
        "passed": documented_generate,
        "evidence": (
            f"Documented stable entry found at {invoice_path.relative_to(run_dir)}"
            if documented_generate
            else f"Missing documented generate entry in {invoice_path.relative_to(run_dir)}"
        ),
    })

    super_super_hits = []
    for path in find_text_files(outputs_dir / "src", ".rs"):
        content = path.read_text(errors="replace")
        if "super::super" in content:
            super_super_hits.append(str(path.relative_to(run_dir)))
    no_super_super = not super_super_hits
    results.append({
        "text": assertions[1],
        "passed": no_super_super,
        "evidence": (
            "No super::super imports remain under src/."
            if no_super_super
            else f"Found super::super imports in: {', '.join(super_super_hits)}"
        ),
    })

    lib_content = lib_path.read_text(errors="replace") if lib_path.exists() else ""
    narrowed_surface = lib_path.exists() and "pub mod reporting;" not in lib_content and "pub mod shared;" not in lib_content
    results.append({
        "text": assertions[2],
        "passed": narrowed_surface,
        "evidence": (
            f"Public crate surface narrowed in {lib_path.relative_to(run_dir)}"
            if narrowed_surface
            else f"Old implementation modules still publicly exported in {lib_path.relative_to(run_dir)}"
        ),
    })

    old_reporting_import = re.search(
        r"use\s+crate::reporting::generate_invoice::\{[^}]*\b(normalize_customer_name|render_invoice_lines|generate_invoice)\b",
        invoice_content,
        re.DOTALL,
    )
    invoice_isolated = invoice_path.exists() and old_reporting_import is None
    results.append({
        "text": assertions[3],
        "passed": invoice_isolated,
        "evidence": (
            f"Invoice facade does not import helper-level symbols from old reporting implementation in {invoice_path.relative_to(run_dir)}"
            if invoice_isolated
            else f"Invoice facade still imports helper-level symbols from old reporting implementation in {invoice_path.relative_to(run_dir)}"
        ),
    })

    report_content = report_path.read_text(errors="replace") if report_path.exists() else ""
    report_has_validation = report_path.exists() and "cargo fmt" in report_content and any(
        keyword in report_content for keyword in ("cargo test", "cargo check", "Blockers", "blocker")
    )
    results.append({
        "text": assertions[4],
        "passed": report_has_validation,
        "evidence": (
            f"Validation details recorded in {report_path.relative_to(run_dir)}"
            if report_has_validation
            else f"Validation details missing from {report_path.relative_to(run_dir)}"
        ),
    })

    return results


def build_grading(run_dir: Path, expectations: list[dict]) -> dict:
    passed = sum(1 for expectation in expectations if expectation["passed"])
    total = len(expectations)
    failed = total - passed
    report_path = run_dir / "outputs" / "report.md"

    timing = {
        "executor_duration_seconds": 0.0,
        "grader_duration_seconds": 0.0,
        "total_duration_seconds": 0.0,
    }

    return {
        "expectations": expectations,
        "summary": {
            "passed": passed,
            "failed": failed,
            "total": total,
            "pass_rate": round(passed / total, 2) if total else 0.0,
        },
        "execution_metrics": {
            "tool_calls": {},
            "total_tool_calls": 0,
            "total_steps": 0,
            "errors_encountered": 0,
            "output_chars": sum_output_chars(run_dir / "outputs"),
            "transcript_chars": 0,
        },
        "timing": {
            "executor_duration_seconds": timing["executor_duration_seconds"],
            "grader_duration_seconds": timing["grader_duration_seconds"],
            "total_duration_seconds": timing["total_duration_seconds"],
        },
        "claims": [],
        "user_notes_summary": {
            "uncertainties": collect_residual_risks(report_path),
            "needs_review": [],
            "workarounds": [],
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Grade clean-code benchmark runs")
    parser.add_argument("iteration_dir", help="Path to the benchmark iteration directory")
    args = parser.parse_args()

    iteration_dir = Path(args.iteration_dir).resolve()

    for eval_dir in sorted(iteration_dir.glob("eval-*")):
        metadata_path = eval_dir / "eval_metadata.json"
        if not metadata_path.exists():
            continue

        metadata = load_json(metadata_path)
        assertions = metadata.get("assertions", [])
        eval_name = metadata.get("eval_name", "")

        for run_dir in sorted(eval_dir.glob("*/run-*")):
            if eval_name == "typescript-stable-entry":
                expectations = grade_typescript(run_dir, assertions)
            elif eval_name == "rust-stable-module":
                expectations = grade_rust(run_dir, assertions)
            else:
                raise ValueError(f"Unsupported eval name: {eval_name}")

            grading = build_grading(run_dir, expectations)
            write_json(run_dir / "grading.json", grading)
            write_json(
                run_dir / "timing.json",
                {
                    "total_tokens": 0,
                    "duration_ms": 0,
                    "total_duration_seconds": grading["timing"]["total_duration_seconds"],
                },
            )


if __name__ == "__main__":
    main()
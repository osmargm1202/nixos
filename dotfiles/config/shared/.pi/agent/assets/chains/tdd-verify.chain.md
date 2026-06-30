---
name: tdd-verify
description: Review and verify an already implemented TDD change.
---

## tdd-reviewer

output: review-report.md
outputMode: file-only
progress: true

Review {task} against available plans, implementation evidence, strict TDD discipline, assertion quality, and review workload boundaries.

## tdd-verifier

reads: review-report.md
output: verification-report.md
outputMode: file-only
progress: true

Verify {task} using the review report, available project artifacts, strict TDD evidence, and required project verification commands.

---
name: tdd-full
description: Run the full TDD lifecycle for a change when explicitly approved.
---

## tdd-brainstormer

output: brainstorm.md
outputMode: file-only
progress: true

Explore {task}. Clarify intent, desired behavior, risks, constraints, and test strategy before planning.

## tdd-planner

reads: brainstorm.md
output: plan.md
outputMode: file-only
progress: true

Create a strict-TDD implementation plan for {task}. Include expected red/green/refactor evidence and focused verification commands.

## tdd-worktree-manager

reads: plan.md
output: worktree.md
outputMode: file-only
progress: true
optional: true
condition: Use only when the approved plan or workspace state requires an isolated worktree.

Prepare an isolated workspace for {task} when needed. If no worktree is required, report the reason and continue without changing workspace state.

## tdd-implementer

reads: brainstorm.md+plan.md
output: implementation-progress.md
outputMode: file-only
progress: true

Implement only the approved plan for {task}. Follow strict red/green/refactor discipline and record failing-first evidence plus passing verification.

## tdd-reviewer

reads: brainstorm.md+plan.md+implementation-progress.md
output: review-report.md
outputMode: file-only
progress: true

Review {task} against the plan, implementation evidence, strict TDD discipline, assertion quality, and review workload boundaries.

## tdd-verifier

reads: brainstorm.md+plan.md+implementation-progress.md+review-report.md
output: verification-report.md
outputMode: file-only
progress: true

Verify {task} using the plan, implementation progress, review report, strict TDD evidence, and required project verification commands.

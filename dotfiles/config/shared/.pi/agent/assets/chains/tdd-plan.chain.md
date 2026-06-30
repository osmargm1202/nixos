---
name: tdd-plan
description: Plan a TDD change through brainstorming and implementation planning.
---

## tdd-brainstormer

output: brainstorm.md
outputMode: file-only
progress: true

Explore {task}. Clarify intent, behavior, risks, constraints, and test strategy before planning.

## tdd-planner

reads: brainstorm.md
output: plan.md
outputMode: file-only
progress: true

Create a strict-TDD implementation plan for {task} using the brainstorming notes and previous output. Keep tasks reviewable and verification-focused.

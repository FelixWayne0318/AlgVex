# AlgVex

AlgVex is an AI-assisted quantitative research and automation system.

## Core goals
- Automate research & code generation via Claude
- Use GitHub as the single source of truth
- Trigger workflows via Slack
- Keep all changes traceable via PRs

## Rules for Claude
- Do NOT push directly to main
- Always work in feature branches
- Use clear commit messages
- Prefer small, reviewable changes
- If uncertain, ask before acting

## Execution model
Slack → GitHub Issue / Comment → GitHub Actions → Claude → PR → Review

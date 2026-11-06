# Contributing

Thanks for helping. Read [AGENTS.md](AGENTS.md) first: it holds the project's
invariants, layout and checks, for people and agents alike.

## Setup

```sh
brew install go-task xcodegen actionlint shellcheck
task check
```

`task check` needs full Xcode (not just the Command Line Tools). Tests use
fixtures, so no USB hardware is required; check UI changes against a real
device before asking for review.

## Changes

- Branch from `main` and open a pull request back to `main`.
- Use Conventional Commit messages (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`).
- Run `task check` before pushing; add tests for new behaviour.
- Use synthetic fixtures, never real credentials or personal data.
- Describe the observable problem, the change, and the checks you ran.

Required checks and a Copilot review run on every pull request. Pull requests
are squash-merged.

## Releases

Maintainers release locally with release-tools; see the Release section of
AGENTS.md. Contributors never need signing credentials.

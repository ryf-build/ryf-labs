# RYF Labs

**Small public experiments in developer tooling, automation, AI-assisted engineering, and reproducible technical-book companions.**

This is the sandbox for ideas that are useful to share but do not belong to a larger product repository.

> Experiments here are clean-room public examples. No private product code, customer data, credentials, production configuration, or internal endpoints are published here.

## Areas

- Developer tooling
- GitHub Actions
- Windows automation
- PowerShell utilities
- AI-agent experiments
- CI/CD prototypes
- Small command-line tools
- Workflow experiments
- Technical-book companion code

## Featured companion

### Coin Rush — Roblox book sample

`roblox/coin-rush-book-sample` contains the public companion for the Zenn book **「Robloxでゲームを作って、運営して、稼ぐ本」**.

It connects the book's examples into one educational Roblox/Luau project:

```text
Join
→ profile claim / load
→ Coin pickup / Upgrade / Zone
→ autosave / session lease
→ Analytics
→ Developer Product receipt
→ final save
```

The repository-level static contract check is **74 / 74 PASS**. Roblox Studio runtime, multi-client, DataStore, receipt redelivery, mobile, and network checks remain explicit environment gates and are not represented as completed until they are actually run.

Book: https://zenn.dev/ryf/books/roblox-game-ops-monetization

## Structure

```text
experiments/
scripts/
roblox/
  coin-rush-book-sample/
```

Each experiment should be:

- understandable on its own
- safe to run
- free of production secrets
- small enough to learn from
- explicit about limitations

## Status

Public lab. Experiments and book companions are added selectively.

---

Built by [ryf-build](https://github.com/ryf-build).

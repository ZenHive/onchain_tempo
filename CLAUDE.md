<!-- Selective-load (Opus 4.8): eager floor = critical-rules + harness-workflow (this repo is
     harness-driven — the OTP dispatch→review→land loop is the active workflow). onchain-workspace
     is the harness workspace add-on (7-repo roster + dependency shape), eager family-wide.
     Everything else previously imported here (across-instances, worktree, task-prioritization/writing, rmap,
     workflow-philosophy, web-command, elixir-setup, ex-unit-json, dialyzer-json, code-style,
     development-commands/philosophy, agent-economy) is skill-on-demand via the elixir / task-driver
     / dev-lifecycle plugins. The Linear-as-queue + Codex/Cursor delegation flow (delegation +
     onchain-workspace) is retired — harness replaced it. Re-add an @-import per-surface only if
     Opus visibly degrades on it. See ~/.claude/setup-guide.md § "Skills vs Includes". -->
@~/.claude/includes/critical-rules.md
@~/.claude/includes/harness-workflow.md
@~/.claude/includes/onchain-workspace.md

# OnchainTempo

Tempo blockchain primitives for Elixir. Extracted from MPP (Machine Payments Protocol) to provide standalone 0x76 transaction handling, TIP-20 encoding, RPC, and event parsing.

**Repo:** [ZenHive/onchain_tempo](https://github.com/ZenHive/onchain_tempo) | **Org:** ZenHive

> **Cross-family reviewers:** the `.json` mix tasks (`mix test.json`, `mix dialyzer.json`) emit JSON **by design** — parse it for real failures, never flag the envelope as a build error. Full toolchain/check-command contract for codex/cursor/grok reviewers is in `AGENTS.md` § "Toolchain & check commands".

## Commands

```bash
mix test.json --quiet              # Unit tests (AI-friendly JSON)
mix test.json --quiet --failed     # Re-run failures
mix test.json --quiet --include integration  # + integration tests
mix dialyzer.json --quiet          # Type checking
mix credo --strict --format json   # Static analysis
mix sobelow                        # Security scanner
mix doctor                         # Docs/specs coverage
mix format                         # Auto-format (Styler)
```

## Architecture

This is a **library** (not a Phoenix app). It provides Tempo-specific blockchain primitives that any Elixir project can use.

### Module Map

```
OnchainTempo                       — Root module, Discoverable entry point
Onchain.Tempo.TIP20                — TIP-20 selectors, calldata encoders, DEX address
Onchain.Tempo.Transaction          — 0x76 struct, deserialize, payment matching, fee payer co-signing
Onchain.Tempo.Transaction.Builder  — Build + sign 0x76 transactions from scratch
Onchain.Tempo.RPC                  — broadcast_async/sync, fetch_receipt, parse_receipt
Onchain.Tempo.Transfer             — TransferWithMemo event log parsing
Onchain.Tempo.Faucet               — Moderato testnet faucet (tempo_fundAddress) wrapper
```

### Key Design Decisions

- **Signing uses Curvy directly** — Tempo 0x76 is non-standard; `Onchain.Signer` handles EIP-1559 only. Direct `Cartouche.Signer.Curvy` + `Cartouche.Recover.find_recid/3` is correct.
- **TIP20 owns all selectors** — Single source of truth, eliminates duplication.
- **RPC uses plain errors** — `{:error, "message"}` not wrapped error structs.
- **ExRLP is transitive** — Available via onchain → cartouche. `@dialyzer` suppressions needed.

### Dependencies

- `onchain` — Core Ethereum utilities (RPC, ABI, signing, logs)
- `req` — HTTP client for RPC calls
- `jason` — JSON encoding for RPC payloads
- `descripex` — Self-describing APIs
- `plug` — Required for Req.Test stubs (dev/test only)

### Tempo Network Chain IDs

| Network | Chain ID | RPC URL |
|---------|----------|---------|
| Mainnet | `4217` | `https://rpc.tempo.xyz` |
| Moderato (testnet) | `42431` | `https://rpc.moderato.tempo.xyz` |

### Dialyzer Notes

Dialyzer shows `unknown_function` warnings for transitive deps when using onchain as a path dep. This is a known issue shared with onchain_aave — the path dep's transitive deps aren't fully resolved in the PLT. These are false positives.

### Conventions

- Styler is the formatter plugin (runs automatically via `mix format`)
- `test/support/` is compiled in test env
- Integration tests live under `test/onchain/tempo/integration/`, tagged `:integration`, excluded by default. They self-fund fresh wallets via the Moderato `tempo_fundAddress` faucet RPC — no env var required. Override the endpoint with `TEMPO_RPC_URL`.
- All calldata functions accept raw binaries (20-byte addresses, 32-byte memos), not hex strings
- Error format: `{:ok, result} | {:error, String.t()}`

## Git Commit Configuration

**Configured**: 2026-03-28

### Commit Message Format

**Format**: imperative-mood

#### Imperative Mood Template
```
<description>
```
Start with imperative verb: Add, Update, Fix, Remove, etc.

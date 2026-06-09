# Changelog

## v0.2.2

### Dependency updates

- Bumped `onchain` `~> 0.5.3` → `~> 0.7.0`. onchain 0.7.0 cascades a major
  `decimal` `2.0` → `3.1.1` jump and pulls `descripex` `0.7.0` + `cartouche`
  `0.2.2` transitively.
- Bumped `descripex` `~> 0.6` → `~> 0.7` and dev-tool `doctor` `~> 0.22` →
  `~> 0.23` (0.23 requires `decimal ~> 3.1`, unblocked by the decimal jump).
- `req` resolves to `0.6.1`. No library code changes — compile clean under
  `--warnings-as-errors`, full offline suite green.

### Faucet — poll for funding confirmation instead of fixed sleep

`Onchain.Tempo.Faucet.fresh_funded_wallet/1` now polls `eth_getBalance` on the
fresh address until the funding transaction lands, replacing the previous
fixed 2.5 s `Process.sleep`. The helper returns as soon as the balance is
non-zero, cutting per-call overhead from a flat ~2.5 s to ~one block (~500 ms
on Moderato).

`:settle_ms` is now the poll **timeout** (default `10_000` ms); `settle_ms: 0`
still skips the wait entirely for unit tests that mock the RPC layer. New
`:poll_interval_ms` option (default `200` ms) tunes the poll cadence.

## v0.2.1

### Migrate signing to Cartouche

**Completed** 2026-05-15

**What was done:**
- Switched internal signing/recovery aliases from `Signet.Signer.Curvy` / `Signet.Recover` to `Cartouche.Signer.Curvy` / `Cartouche.Recover` in `Onchain.Tempo.Transaction` and `Onchain.Tempo.Transaction.Builder`. Cartouche is ZenHive's fork of signet — drop-in compatible, available transitively via `onchain`.
- Tightened the `onchain` dep from `~> 0.5` to `~> 0.5.3` to ensure the cartouche-bearing version is resolved.
- Public API unchanged — purely internal refactor for consumers.

### Dialyzer configuration

- Adopted `plt_add_deps: :apps_direct` to keep the PLT scoped to direct deps (tidewave/bandit's HTTP stack bloated the tree to ~800 modules).
- Moved PLT files from `_build/dialyzer/` to `priv/plts/` so they survive `mix clean` / `_build` wipes. Added `/priv/plts/` to `.gitignore`.

## v0.2.0

### Public `Onchain.Tempo.Faucet` helper for `tempo_fundAddress`

**Completed** 2026-04-19 | [D:2/B:5/U:5 → Eff:2.5]

**What was done:**
- Promoted the previously test-only `Onchain.Tempo.TestSupport.ModeratoFaucet` (`test/support/moderato_faucet.ex`) into public `Onchain.Tempo.Faucet` at `lib/onchain/tempo/faucet.ex` so downstream consumers writing their own integration suites can reuse the Moderato faucet recipe without copying it from our test code.
- Public API: `rpc_url/0` (Moderato default, `TEMPO_RPC_URL` override), `fund_address/2` (thin wrapper around the `tempo_fundAddress` JSON-RPC, returns `{:ok, [tx_hash]}`), and `fresh_funded_wallet/1` (generates a 32-byte keypair, funds it, sleeps for settlement). Both accept an opts keyword list with `:rpc_url`, `:req_options`, and (for `fresh_funded_wallet/1`) `:settle_ms`.
- Registered `Onchain.Tempo.Faucet` in `OnchainTempo`'s `Descripex.Discoverable` module list so it surfaces in `OnchainTempo.describe/0`.
- Migrated the integration suite (`test/onchain/tempo/integration/moderato_test.exs`) to the public module and deleted the old `test/support/moderato_faucet.ex`.
- Added unit tests at `test/onchain/tempo/faucet_test.exs` covering happy/error/transport paths via `Req.Test` stubs.

**Key decisions:**
- Kept the wrapper thin — same `{:ok, _} | {:error, String.t()}` contract as the rest of the library, no struct for the wallet (single-shot return value, kept as a plain map to match the original API).
- Single opts keyword list (rather than `(address, rpc_url, opts)` positional) so callers like `fund_address("0xabc", req_options: [...])` don't silently bind the keyword list to `rpc_url`. RPC URL is pulled with `Keyword.pop(opts, :rpc_url, rpc_url())`.
- `fresh_funded_wallet/1` accepts a `:settle_ms` option (defaults to `2_500`) so unit tests can pass `settle_ms: 0` and avoid the real-world post-funding sleep.
- HTTP path closely follows `Onchain.Tempo.RPC.rpc_request/4` — same `Req.request/2` two-list shape, `Jason.encode!` with string keys, and `req_options` pass-through for `Req.Test`; adds `receive_timeout: 15_000` since funding occasionally exceeds the default.
- Carried forward the existing TODO about the fixed-sleep settle, retagged as `TODO(Task 6):` with a matching ROADMAP entry to replace it with a poll loop on `eth_getTransactionCount`/`eth_getBalance`.

## v0.1.1

### Integration tests against Moderato testnet

**Completed** 2026-04-19 | [D:3/B:7/U:6 → Eff:2.17]

**What was done:**
- Added opt-in `:integration` suite at `test/onchain/tempo/integration/moderato_test.exs` exercising the full Builder → RPC pipeline against live Moderato (chain `42_431`, `https://rpc.moderato.tempo.xyz`).
- Three tests cover: Builder real nonce fetch + 0x76 round-trip via `Transaction.deserialize/1`, `RPC.fetch_receipt/2` returning `{:error, "Transaction not found on-chain"}` for unknown hashes, and `RPC.broadcast_sync/2` confirming a self-transfer of pathUSD with a real receipt + logs.
- New `test/support/moderato_faucet.ex` helper wraps the Moderato `tempo_fundAddress` custom JSON-RPC so each test self-funds a fresh keypair — no env var required.

**Key decisions:**
- Fresh keypair per test (vs MPP's hardcoded Hardhat keys) — avoids nonce races between concurrent CI runs and downstream library consumers.
- Loud `flunk/1` on funding failure rather than silent skip (per project critical-rules).
- pathUSD (`0x20c0…0000`) chosen as the canonical TIP-20 test token, sourced from MPP's existing Moderato integration suite.
- Override `TEMPO_RPC_URL` to point the faucet at a different Tempo endpoint; default stays Moderato.

### Builder default gas_limit raised to 500_000

**Completed** 2026-04-19

**What was done:**
- `Onchain.Tempo.Transaction.Builder` `@default_gas_limit` bumped from 200_000 to 500_000 — a stock TIP-20 transfer on Moderato consumes ~272k, so the previous default under-provisioned real transfers.
- Integration test no longer needs a per-call `gas_limit` override; the library default works out of the box.

**Key decisions:**
- 500k is a ceiling, not an amount spent — no real-world cost change; just prevents `out of gas` for the common TIP-20 path.

### Update MPP to use onchain_tempo

**Completed** 2026-04-19 | [D:3/B:8/U:9 → Eff:2.83]

**What was done:**
- Bookkeeping closure — verified the MPP-side migration was already accomplished during the original v0.1.0 extraction (MPP Task 23, 2026-03-28).
- `MPP.Methods.Tempo` aliases `Onchain.Tempo.{RPC, Transaction, Transfer}`; no `MPP.Tempo.Transaction` module remains in `mpp/lib/`.
- Remaining `MPP.Tempo.*` modules (`Store`, `ConCacheStore`, `Methods.Tempo.SessionReceipt`) are MPP-specific concerns (HTTP 402 dedup, session receipt encoding) and intentionally stay in MPP.

**Key decisions:**
- No code changes in either repo. The migration was complete; the roadmap entry was stale.
- Forward-looking: when onchain_tempo v0.2.0 ships with bumped `onchain` / `descripex`, MPP will need a coordinated dep bump — tracked as MPP Task 43.

## v0.1.0

Initial release — extracted Tempo blockchain primitives from MPP.

**What was done:**
- `Onchain.Tempo.TIP20` — TIP-20 function selectors, calldata encoders, stablecoin DEX address
- `Onchain.Tempo.Transaction` — 0x76 transaction struct, RLP deserialization, payment call matching, fee-payer call scope validation, fee-payer co-signing (0x78 domain)
- `Onchain.Tempo.Transaction.Builder` — Build and sign 0x76 transactions (transfer, multicall, fee-payer variants)
- `Onchain.Tempo.RPC` — Tempo JSON-RPC (broadcast async/sync, fetch receipt, parse receipt)
- `Onchain.Tempo.Transfer` — TransferWithMemo event log parsing via `Onchain.Log.decode_event/2`
- `OnchainTempo` — Root module with Descripex Discoverable progressive API discovery
- 77 unit tests covering deserialization, calldata encoding, payment matching, call scope validation, RPC stubs, and builder validation

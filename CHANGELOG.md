# Changelog

## [Unreleased]

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

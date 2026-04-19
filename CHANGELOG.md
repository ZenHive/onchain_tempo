# Changelog

## [Unreleased]

### Task: Update MPP to use onchain_tempo

**Completed** 2026-04-19 | [D:3/B:8/U:9 → Eff:2.83]

**What was done:**
- Bookkeeping closure — verified the MPP-side migration was already accomplished during the original v0.1.0 extraction (MPP Task 23, 2026-03-28).
- `MPP.Methods.Tempo` aliases `Onchain.Tempo.{RPC, Transaction, Transfer}`; no `MPP.Tempo.Transaction` module remains in `mpp/lib/`.
- Remaining `MPP.Tempo.*` modules (`Store`, `ConCacheStore`, `Methods.Tempo.SessionReceipt`) are MPP-specific concerns (HTTP 402 dedup, session receipt encoding) and intentionally stay in MPP.

**Key decisions:**
- No code changes in either repo. The migration was complete; T2 was a stale roadmap entry.
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

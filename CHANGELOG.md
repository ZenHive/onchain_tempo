# Changelog

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

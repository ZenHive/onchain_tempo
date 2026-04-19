# OnchainTempo Roadmap

**Vision:** Standalone Tempo blockchain primitives for the Elixir ecosystem.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## Phase 1: Extraction from MPP ✅

> Initial extraction of Tempo primitives from MPP into standalone library.
> Built: TIP20, Transaction (deserialize + build + sign + fee payer), RPC, Transfer.

---

## Phase 2: Future Work

- [ ] Publish to Hex [D:2/B:8/U:8 → Eff:4.0]
      Switch onchain dep from path to published version, publish onchain_tempo to Hex.

- [ ] Integration tests against Moderato testnet [D:3/B:7/U:6 → Eff:2.17]
      Add integration tests for Builder (real nonce fetch) and RPC (real broadcast/receipt).
      Requires TEMPO_PRIVATE_KEY env var.

- [x] Update MPP to use onchain_tempo [D:3/B:8/U:9 → Eff:2.83] ✅
      Already complete — MPP migrated during the original v0.1.0 extraction (2026-03-28).
      Confirmed 2026-04-19: `mpp/lib/mpp/methods/tempo.ex` aliases `Onchain.Tempo.{RPC, Transaction, Transfer}`,
      `mpp/mix.exs` declares `{:onchain_tempo, "~> 0.1"}`, no `MPP.Tempo.Transaction` module exists.
      See [CHANGELOG.md](CHANGELOG.md#unreleased).

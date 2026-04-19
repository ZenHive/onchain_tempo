# OnchainTempo Roadmap

**Vision:** Standalone Tempo blockchain primitives for the Elixir ecosystem.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## Phase 1: Extraction from MPP ✅

> Initial extraction of Tempo primitives from MPP into standalone library.
> Built: TIP20, Transaction (deserialize + build + sign + fee payer), RPC, Transfer.

---

## Phase 2: Hex Release & Integration Coverage ✅

- [x] Publish to Hex [D:2/B:8/U:8 → Eff:4.0] ✅
      v0.1.0 published to Hex; `onchain` switched from path dep to published version.
      See [CHANGELOG.md](CHANGELOG.md#v010).

- [x] Integration tests against Moderato testnet [D:3/B:7/U:6 → Eff:2.17] ✅
      Added opt-in `:integration` suite covering Builder (real nonce fetch) and RPC
      (real broadcast/receipt) against Moderato. Self-funds fresh wallets via
      `tempo_fundAddress` faucet RPC — no env var required.
      See [CHANGELOG.md](CHANGELOG.md#v011).

- [x] Update MPP to use onchain_tempo [D:3/B:8/U:9 → Eff:2.83] ✅
      Already complete — MPP migrated during the original v0.1.0 extraction (2026-03-28).
      See [CHANGELOG.md](CHANGELOG.md#v011).

---

## Phase 3: Future Work

- [ ] Public Onchain.Tempo.Faucet helper for tempo_fundAddress [D:2/B:5/U:5 → Eff:2.5] 🚀
      Moderato exposes a `tempo_fundAddress` custom JSON-RPC that funds an address
      with native + pathUSD. Currently only used internally by the integration test
      suite (`test/support/moderato_faucet.ex`). Promote a thin public wrapper to
      `lib/onchain/tempo/faucet.ex` so consumers writing their own integration
      suites don't have to re-derive the recipe. Discovered during the v0.1.1
      integration test work — recipe sourced from MPP's existing tempo integration tests.

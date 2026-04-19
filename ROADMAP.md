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

- [x] Public Onchain.Tempo.Faucet helper for tempo_fundAddress [D:2/B:5/U:5 → Eff:2.5] ✅
      Promoted `test/support/moderato_faucet.ex` to public `Onchain.Tempo.Faucet`
      with `rpc_url/0`, `fund_address/2`, and `fresh_funded_wallet/1`. Single
      opts keyword list (`:rpc_url`, `:req_options`, `:settle_ms`); the
      `:settle_ms` option lets unit tests skip the post-funding sleep. Old test
      support helper deleted; integration suite migrated to the public module.
      See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [ ] Task 6: Replace Faucet fixed-sleep settle with poll loop [D:3/B:3/U:3 → Eff:1.0] 📋
      `Onchain.Tempo.Faucet.fresh_funded_wallet/2` currently sleeps a fixed
      `@default_settle_ms` (2_500ms) after funding before returning. Replace
      with a poll loop on `eth_getTransactionCount` or `eth_getBalance` so the
      helper returns as soon as the funding transaction lands (Moderato blocks
      ~500ms; the fixed sleep wastes ~2s per integration test). Discovered
      during the v0.1.1 integration test work and carried forward when the
      helper was promoted to a public module.

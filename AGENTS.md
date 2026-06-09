This is an Elixir **library** (not a Phoenix app): Tempo blockchain primitives — 0x76 transaction handling, TIP-20 encoding, RPC, and event parsing. See `CLAUDE.md` for the module map and architecture.

## Project guidelines

- Use the already-included `:req` (`Req`) library for HTTP requests — **avoid** `:httpoison`, `:tesla`, and `:httpc`.
- All calldata functions accept raw binaries (20-byte addresses, 32-byte memos), **not** hex strings.
- Error format is `{:ok, result} | {:error, String.t()}` — RPC uses plain string errors, not wrapped structs.
- Styler runs automatically via `mix format` (it's the formatter plugin) — don't hand-format; run `mix format`.

## Toolchain & check commands (read before judging a build)

There is **no `precommit` alias** in this repo. The check gate is this set, run individually (a clean run of all of them is the merge bar):

```bash
mix format                          # auto-format (Styler plugin)
mix compile --warnings-as-errors    # must compile clean
mix credo --strict --format json    # static analysis
mix doctor                          # docs/specs coverage
mix sobelow                         # security scanner (honors .sobelow-skips via --skip)
mix test.json --quiet               # unit tests (excludes :integration by default)
mix dialyzer.json --quiet           # type checking
```

**The `.json` mix tasks emit JSON BY DESIGN — that is expected output, never an error or a broken setup:**

- **`mix test.json`** (from the `ex_unit_json` dep) — ExUnit results as a JSON document for machine parsing; it's the same run as `mix test`. Parse it for real failures; the JSON envelope itself is never a failure signal. `--cover` can emit a large per-module coverage blob — pipe it to a file (`--output /tmp/cov.json`) and `jq` the summary, don't dump it to the transcript. Coverage tiers: **≥80%** standard logic, **≥95%** for critical paths (signing, money handling, encoders, security-sensitive parsers).
- **`mix dialyzer.json`** (from the `dialyzer_json` dep; `preferred_envs: ["dialyzer.json": :dev]`) — dialyzer warnings as JSON. Read the JSON array for *real* warnings; do NOT flag the JSON output itself as a problem. If the encoder errors on a warning shape it can't serialize, run **plain `mix dialyzer`** — that is the authoritative dialyzer check. Zero real warnings = pass. Note: `unknown_function` warnings for transitive deps are known false positives (path-dep PLT resolution; suppressed via `.dialyzer_ignore.exs`).

The other tools are plain-text: `mix credo --strict`, `mix doctor`, `mix sobelow`.

**Sobelow skips:** the commit hook honors only the hash-based `.sobelow-skips` file (read via `mix sobelow --skip`); inline `# sobelow_skip [...]` comments are NOT honored — see `CLAUDE.md`.

## Integration tests

Integration tests live under `test/onchain/tempo/integration/`, tagged `:integration`, and are **excluded by default**. They self-fund fresh wallets via the Moderato testnet `tempo_fundAddress` faucet RPC — **no env var or credentials required**. Override the endpoint with `TEMPO_RPC_URL`. Run them with:

```bash
mix test.json --quiet --include integration
```

(Claude-family agents with the user's global skills can invoke `elixir:ex-unit-json` and `elixir:dialyzer-json` for the full flag/jq reference. For every other agent, the notes above are self-contained — you don't need the skills.)

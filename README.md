# OnchainTempo

Tempo blockchain primitives for Elixir — 0x76 transaction handling, TIP-20 token encoding, RPC broadcasting, and TransferWithMemo event parsing.

Built on [onchain](https://github.com/ZenHive/onchain).

## Installation

```elixir
def deps do
  [
    {:onchain_tempo, "~> 0.1"}
  ]
end
```

## Modules

| Module | Purpose |
|--------|---------|
| `Onchain.Tempo.TIP20` | TIP-20 function selectors, calldata encoders, Tempo constants |
| `Onchain.Tempo.Transaction` | 0x76 transaction struct, deserialize, payment matching, fee payer co-signing |
| `Onchain.Tempo.Transaction.Builder` | Build and sign 0x76 transactions from scratch |
| `Onchain.Tempo.RPC` | Tempo JSON-RPC operations (broadcast async/sync, fetch receipt) |
| `Onchain.Tempo.Transfer` | TransferWithMemo event log parsing |

## Quick Start

### Deserialize a Tempo transaction

```elixir
{:ok, tx} = Onchain.Tempo.Transaction.deserialize("0x76...")
tx.chain_id  #=> 42431
tx.calls     #=> [%{to: <<...>>, value: 0, input: <<...>>}]
```

### Find a payment call

```elixir
{:ok, match} = Onchain.Tempo.Transaction.find_payment_call(tx, token_address,
  amount: "1000000",
  recipient: "0x70997970..."
)
match.amount  #=> 1000000
```

### Build and sign a transfer

```elixir
{:ok, tx_hex} = Onchain.Tempo.Transaction.Builder.build_signed_transfer(
  private_key: "0xac09...",
  token: "0x20c0...",
  recipient: "0x7099...",
  amount: 1_000_000,
  chain_id: 42_431,
  rpc_url: "https://rpc.moderato.tempo.xyz"
)
```

### Broadcast

```elixir
# Async (returns tx hash immediately)
{:ok, tx_hash} = Onchain.Tempo.RPC.broadcast_async(tx_hex, rpc_url)

# Sync (waits for block inclusion, returns receipt)
{:ok, tx_hash, receipt} = Onchain.Tempo.RPC.broadcast_sync(tx_hex, rpc_url)
```

## Discovery

All modules use [descripex](https://hex.pm/packages/descripex):

```elixir
OnchainTempo.describe()                          # Module overview
OnchainTempo.describe(:transaction)              # Function list
OnchainTempo.describe(:transaction, :deserialize) # Full details
```

## Tempo Networks

| Network | Chain ID | RPC URL |
|---------|----------|---------|
| Mainnet | `4217` | `https://rpc.tempo.xyz` |
| Moderato (testnet) | `42431` | `https://rpc.moderato.tempo.xyz` |

## License

MIT

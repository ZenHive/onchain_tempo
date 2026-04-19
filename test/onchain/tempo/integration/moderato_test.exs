defmodule Onchain.Tempo.Integration.ModeratoTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Onchain.Tempo.RPC
  alias Onchain.Tempo.TestSupport.ModeratoFaucet
  alias Onchain.Tempo.Transaction
  alias Onchain.Tempo.Transaction.Builder

  @moduletag :integration

  # Canonical pathUSD TIP-20 stablecoin on Moderato (6 decimals).
  @path_usd Base.decode16!("20c0000000000000000000000000000000000000", case: :lower)
  @chain_id 42_431

  setup do
    case ModeratoFaucet.fresh_funded_wallet() do
      {:ok, wallet} ->
        {:ok, wallet: wallet, rpc_url: ModeratoFaucet.rpc_url()}

      {:error, reason} ->
        flunk("""
        Could not fund a Moderato testnet wallet: #{reason}

        These integration tests require Moderato to be reachable and the
        `tempo_fundAddress` JSON-RPC method to succeed. Override the RPC URL
        with TEMPO_RPC_URL if needed.

        Skip this suite by running without --include integration.
        """)
    end
  end

  test "Builder fetches a real nonce and produces a deserializable 0x76 tx", %{wallet: w, rpc_url: rpc} do
    {:ok, raw} =
      Builder.build_signed_transfer(
        private_key: w.private_key,
        token: @path_usd,
        recipient: w.address_bin,
        amount: 1,
        chain_id: @chain_id,
        rpc_url: rpc,
        fee_token: @path_usd
      )

    assert "0x76" <> _ = raw

    {:ok, tx} = Transaction.deserialize(raw)
    assert tx.chain_id == @chain_id
    assert [_one_call] = tx.calls
  end

  test "fetch_receipt returns :not_found error for a nonexistent tx hash", %{rpc_url: rpc} do
    fake_hash = "0x" <> String.duplicate("de", 32)
    assert {:error, "Transaction not found on-chain"} = RPC.fetch_receipt(fake_hash, rpc)
  end

  test "broadcast_sync confirms a self-transfer of 1 micro-pathUSD", %{wallet: w, rpc_url: rpc} do
    {:ok, raw} =
      Builder.build_signed_transfer(
        private_key: w.private_key,
        token: @path_usd,
        recipient: w.address_bin,
        amount: 1,
        chain_id: @chain_id,
        rpc_url: rpc,
        fee_token: @path_usd
      )

    assert {:ok, "0x" <> _hash, %{status: 1, logs: logs}} = RPC.broadcast_sync(raw, rpc)
    refute Enum.empty?(logs)
  end
end

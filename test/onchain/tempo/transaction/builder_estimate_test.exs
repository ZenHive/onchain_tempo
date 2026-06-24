defmodule Onchain.Tempo.Transaction.BuilderEstimateTest do
  # async: false — toggles the global `:cartouche, :client` seam to stub the
  # eth_estimateGas transport (Onchain.RPC -> Cartouche.RPC.send_rpc).
  use ExUnit.Case, async: false

  alias Onchain.Tempo.Transaction
  alias Onchain.Tempo.Transaction.Builder

  @private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @recipient "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  @token "0x20c0000000000000000000000000000000000000"
  @chain_id 42_431
  @amount 1_000_000
  @rpc_url "https://rpc.example.test"

  # RLP field index for gas_limit in the 0x76 envelope.
  @gas_limit_index 3

  # Stub HTTP client matching the Cartouche.RPC `:client` seam (request/3 returning
  # a Finch.Response). Echoes the request id and returns a fixed eth_estimateGas
  # result so the headroom math is deterministic.
  defmodule StubClient do
    @moduledoc false
    @estimate_gas 50_000

    def request(%Finch.Request{body: body}, _name, _opts) do
      %{"id" => id} = Jason.decode!(body)
      result = "0x" <> Integer.to_string(@estimate_gas, 16)
      json = Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "result" => result})
      {:ok, %Finch.Response{status: 200, headers: [], body: json}}
    end

    def estimate_gas, do: @estimate_gas
  end

  defmodule ErrorClient do
    @moduledoc false
    def request(%Finch.Request{}, _name, _opts) do
      {:error, %Finch.Error{reason: :timeout}}
    end
  end

  defp with_client(module, fun) do
    prev = Application.get_env(:cartouche, :client)
    Application.put_env(:cartouche, :client, module)
    on_exit(fn -> restore_client(prev) end)
    fun.()
  end

  defp restore_client(nil), do: Application.delete_env(:cartouche, :client)
  defp restore_client(prev), do: Application.put_env(:cartouche, :client, prev)

  defp estimate_opts do
    [
      private_key: @private_key,
      token: @token,
      recipient: @recipient,
      amount: @amount,
      chain_id: @chain_id,
      rpc_url: @rpc_url,
      nonce: 0
    ]
  end

  defp gas_limit_of(tx_hex) do
    {:ok, tx} = Transaction.deserialize(tx_hex)
    :binary.decode_unsigned(Enum.at(tx.fields, @gas_limit_index))
  end

  describe "gas estimation when :gas_limit is omitted" do
    test "sizes the tx from eth_estimateGas with the 1.25x headroom" do
      with_client(StubClient, fn ->
        assert {:ok, tx_hex} = Builder.build_signed_transfer(estimate_opts())

        # ceil(50_000 * 5 / 4) = 62_500
        expected = div(StubClient.estimate_gas() * 5 + 3, 4)
        assert gas_limit_of(tx_hex) == expected
      end)
    end

    test "applies estimation on the fee-payer path too" do
      with_client(StubClient, fn ->
        assert {:ok, tx_hex} = Builder.build_fee_payer_transfer(estimate_opts())
        assert gas_limit_of(tx_hex) == div(StubClient.estimate_gas() * 5 + 3, 4)
      end)
    end

    test "sums per-call estimates for a multicall" do
      with_client(StubClient, fn ->
        calldata = Base.decode16!("a9059cbb", case: :lower)
        token_bin = Base.decode16!("20c0000000000000000000000000000000000000", case: :lower)
        calls = [[token_bin, <<>>, calldata], [token_bin, <<>>, calldata]]

        opts =
          estimate_opts()
          |> Keyword.delete(:token)
          |> Keyword.delete(:recipient)
          |> Keyword.delete(:amount)
          |> Keyword.merge(calls: calls, fee_token: @token)

        assert {:ok, tx_hex} = Builder.build_signed_multicall(opts)
        # Two calls summed, then headroom: ceil(100_000 * 5 / 4) = 125_000
        assert gas_limit_of(tx_hex) == div(StubClient.estimate_gas() * 2 * 5 + 3, 4)
      end)
    end

    test "fetches the nonce from RPC when :nonce is also omitted" do
      with_client(StubClient, fn ->
        opts = Keyword.delete(estimate_opts(), :nonce)
        assert {:ok, "0x76" <> _} = Builder.build_signed_transfer(opts)
      end)
    end

    test "propagates a failed estimate instead of falling back to a default" do
      with_client(ErrorClient, fn ->
        assert {:error, {:rpc_error, _}} = Builder.build_signed_transfer(estimate_opts())
      end)
    end
  end
end

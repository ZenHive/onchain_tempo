defmodule Onchain.Tempo.TestSupport.ModeratoFaucet do
  @moduledoc false

  @default_rpc_url "https://rpc.moderato.tempo.xyz"
  # TODO: fixed-sleep settle — replace with a poll loop on getTransactionCount/getBalance
  #       once we have a retry helper. Moderato blocks ~500ms; 2.5s usually suffices.
  @settle_ms 2_500

  @doc "Generates a fresh keypair, funds it via the Moderato `tempo_fundAddress` RPC, and waits for settlement."
  def fresh_funded_wallet do
    priv = :crypto.strong_rand_bytes(32)
    {:ok, addr_hex} = Onchain.Signer.address_from_key(priv)
    addr_bin = addr_hex |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)

    case fund(addr_hex) do
      {:ok, _hashes} ->
        Process.sleep(@settle_ms)
        {:ok, %{private_key: priv, address_hex: addr_hex, address_bin: addr_bin}}

      {:error, _} = err ->
        err
    end
  end

  def rpc_url, do: System.get_env("TEMPO_RPC_URL") || @default_rpc_url

  defp fund(addr_hex) do
    body = %{jsonrpc: "2.0", method: "tempo_fundAddress", params: [addr_hex], id: 1}

    case Req.post(rpc_url(), json: body, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"result" => hashes}}} when is_list(hashes) -> {:ok, hashes}
      {:ok, %{body: %{"error" => err}}} -> {:error, "faucet error: #{inspect(err)}"}
      {:ok, other} -> {:error, "unexpected faucet response: #{inspect(other)}"}
      {:error, reason} -> {:error, "faucet HTTP error: #{inspect(reason)}"}
    end
  end
end

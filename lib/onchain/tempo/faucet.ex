defmodule Onchain.Tempo.Faucet do
  @moduledoc """
  Moderato testnet faucet — wraps the non-standard `tempo_fundAddress` JSON-RPC.

  Moderato exposes a custom JSON-RPC method, `tempo_fundAddress`, that funds an
  address with native gas + pathUSD in a single call. This module provides a
  thin wrapper plus a convenience helper for spinning up a fresh, funded
  keypair — useful for writing integration tests against Moderato without
  re-deriving the recipe.

  Only Moderato (chain `42_431`) supports this RPC. Mainnet (`4_217`) does not.

  ## Usage

      # Fund an existing address.
      {:ok, [tx_hash | _]} = Onchain.Tempo.Faucet.fund_address("0xabc...")

      # Generate + fund a fresh keypair (waits for settlement before returning).
      {:ok, %{private_key: priv, address_hex: hex, address_bin: bin}} =
        Onchain.Tempo.Faucet.fresh_funded_wallet()

      # Override the endpoint (defaults to https://rpc.moderato.tempo.xyz, or
      # the TEMPO_RPC_URL env var if set).
      Onchain.Tempo.Faucet.fund_address("0xabc...", rpc_url: "https://my-mirror")

  ## Options

  Both `fund_address/2` and `fresh_funded_wallet/1` accept:

    * `:rpc_url` — RPC endpoint URL. Defaults to `rpc_url/0`.
    * `:req_options` — keyword list passed to `Req.request/2` (timeouts,
      adapters, `Req.Test` plug, etc.)
    * `:settle_ms` (`fresh_funded_wallet/1` only) — milliseconds to sleep after
      funding before returning. Defaults to `2_500`. Set `0` in unit tests.
  """
  # Jason, Req are transitive deps via onchain — not resolved in PLT with path deps
  @dialyzer [:no_unknown]

  @default_rpc_url "https://rpc.moderato.tempo.xyz"
  @default_settle_ms 2_500

  @doc """
  RPC URL used by the faucet by default — `TEMPO_RPC_URL` env var if set,
  otherwise `https://rpc.moderato.tempo.xyz`.
  """
  @spec rpc_url() :: String.t()
  def rpc_url, do: System.get_env("TEMPO_RPC_URL") || @default_rpc_url

  @doc """
  Fund an existing address via Moderato's `tempo_fundAddress` RPC.

  Returns `{:ok, hashes}` where `hashes` is the list of funding transaction
  hashes returned by the node.
  """
  @spec fund_address(String.t(), keyword()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def fund_address(address_hex, opts \\ []) do
    {url, opts} = Keyword.pop(opts, :rpc_url, rpc_url())

    case rpc_request("tempo_fundAddress", [address_hex], url, opts) do
      {:ok, hashes} when is_list(hashes) -> {:ok, hashes}
      {:ok, other} -> {:error, "unexpected faucet result: #{inspect(other)}"}
      {:error, _} = err -> err
    end
  end

  @doc """
  Generate a fresh 32-byte keypair, fund it via `tempo_fundAddress`, and wait
  for settlement.

  Returns the wallet as a map with `:private_key` (32 bytes), `:address_hex`
  (`"0x"` + 40 hex), and `:address_bin` (20 bytes).
  """
  @spec fresh_funded_wallet(keyword()) ::
          {:ok, %{private_key: binary(), address_hex: String.t(), address_bin: binary()}}
          | {:error, String.t()}
  def fresh_funded_wallet(opts \\ []) do
    priv = :crypto.strong_rand_bytes(32)
    {:ok, addr_hex} = Onchain.Signer.address_from_key(priv)
    addr_bin = addr_hex |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)

    case fund_address(addr_hex, opts) do
      {:ok, _hashes} ->
        # TODO(Task 6): replace fixed-sleep settle with poll loop on
        # getTransactionCount/getBalance once a retry helper exists.
        # Moderato blocks ~500ms; 2.5s usually suffices.
        settle_ms = Keyword.get(opts, :settle_ms, @default_settle_ms)
        if settle_ms > 0, do: Process.sleep(settle_ms)
        {:ok, %{private_key: priv, address_hex: addr_hex, address_bin: addr_bin}}

      {:error, _} = err ->
        err
    end
  end

  # --- Private ---

  defp rpc_request(method, params, rpc_url, opts) do
    req_options = Keyword.get(opts, :req_options, [])

    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params,
        "id" => 1
      })

    result =
      Req.request(
        [
          url: rpc_url,
          method: :post,
          headers: [{"content-type", "application/json"}],
          body: body,
          receive_timeout: 15_000
        ],
        req_options
      )

    case result do
      {:ok, %Req.Response{status: status, body: %{"result" => value}}} when status in 200..299 ->
        {:ok, value}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, "faucet error: #{inspect(error)}"}

      {:error, exception} ->
        {:error, "faucet HTTP error: #{Exception.message(exception)}"}

      {:ok, %Req.Response{} = response} ->
        {:error, "unexpected faucet response: status #{response.status}, body #{inspect(response.body)}"}
    end
  end
end

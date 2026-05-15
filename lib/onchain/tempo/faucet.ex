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

      # Generate + fund a fresh keypair (polls for confirmation before returning).
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

  `fresh_funded_wallet/1` additionally accepts:

    * `:settle_ms` — maximum milliseconds to wait for the funding transaction
      to confirm. Defaults to `10_000`. Set to `0` to skip the wait entirely
      (used by unit tests that mock the RPC layer).
    * `:poll_interval_ms` — interval between `eth_getBalance` polls. Defaults
      to `200`.
  """
  # Jason, Req are transitive deps via onchain — not resolved in PLT with path deps
  @dialyzer [:no_unknown]

  @default_rpc_url "https://rpc.moderato.tempo.xyz"
  @default_wait_timeout_ms 10_000
  @default_poll_interval_ms 200

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
  Generate a fresh 32-byte keypair, fund it via `tempo_fundAddress`, and poll
  `eth_getBalance` until the funding transaction lands on-chain.

  Returns the wallet as a map with `:private_key` (32 bytes), `:address_hex`
  (`"0x"` + 40 hex), and `:address_bin` (20 bytes).

  Polling is bounded by `:settle_ms` (default `10_000` ms); pass `0` to skip
  the wait entirely. The interval between polls is controlled by
  `:poll_interval_ms` (default `200` ms).
  """
  @spec fresh_funded_wallet(keyword()) ::
          {:ok, %{private_key: binary(), address_hex: String.t(), address_bin: binary()}}
          | {:error, String.t()}
  def fresh_funded_wallet(opts \\ []) do
    with :ok <- validate_wait_opts(opts) do
      priv = :crypto.strong_rand_bytes(32)
      {:ok, addr_hex} = Onchain.Signer.address_from_key(priv)
      addr_bin = addr_hex |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)

      with {:ok, _hashes} <- fund_address(addr_hex, opts),
           :ok <- wait_for_funding(addr_hex, opts) do
        {:ok, %{private_key: priv, address_hex: addr_hex, address_bin: addr_bin}}
      end
    end
  end

  # --- Private ---

  @spec validate_wait_opts(keyword()) :: :ok | {:error, String.t()}
  defp validate_wait_opts(opts) do
    timeout_ms = Keyword.get(opts, :settle_ms, @default_wait_timeout_ms)
    interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)

    cond do
      not (is_integer(timeout_ms) and timeout_ms >= 0) ->
        {:error, ":settle_ms must be a non-negative integer, got: #{inspect(timeout_ms)}"}

      timeout_ms > 0 and not (is_integer(interval_ms) and interval_ms > 0) ->
        {:error, ":poll_interval_ms must be a positive integer, got: #{inspect(interval_ms)}"}

      true ->
        :ok
    end
  end

  @spec wait_for_funding(String.t(), keyword()) :: :ok | {:error, String.t()}
  defp wait_for_funding(addr_hex, opts) do
    timeout_ms = Keyword.get(opts, :settle_ms, @default_wait_timeout_ms)

    if timeout_ms == 0 do
      :ok
    else
      interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
      {url, rpc_opts} = Keyword.pop(opts, :rpc_url, rpc_url())
      deadline = System.monotonic_time(:millisecond) + timeout_ms
      poll_balance(addr_hex, url, rpc_opts, deadline, interval_ms, timeout_ms)
    end
  end

  @spec poll_balance(String.t(), String.t(), keyword(), integer(), pos_integer(), pos_integer()) ::
          :ok | {:error, String.t()}
  defp poll_balance(addr_hex, url, opts, deadline, interval_ms, timeout_ms) do
    with {:ok, balance_hex} <- rpc_request("eth_getBalance", [addr_hex, "latest"], url, opts),
         {:ok, balance} <- parse_balance_hex(balance_hex) do
      cond do
        balance > 0 ->
          :ok

        System.monotonic_time(:millisecond) >= deadline ->
          {:error, "timeout waiting for funding to confirm after #{timeout_ms}ms"}

        true ->
          Process.sleep(interval_ms)
          poll_balance(addr_hex, url, opts, deadline, interval_ms, timeout_ms)
      end
    end
  end

  @spec parse_balance_hex(term()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  defp parse_balance_hex("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "unexpected eth_getBalance result: #{inspect("0x" <> hex)}"}
    end
  end

  defp parse_balance_hex(other), do: {:error, "unexpected eth_getBalance result: #{inspect(other)}"}

  @spec rpc_request(String.t(), list(), String.t(), keyword()) ::
          {:ok, term()} | {:error, String.t()}
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

defmodule Onchain.Tempo.RPC do
  @moduledoc """
  Tempo-specific JSON-RPC operations — transaction broadcast and receipt fetching.

  Provides both async (`eth_sendRawTransaction`) and sync
  (`eth_sendRawTransactionSync`) broadcast methods. The sync variant is
  Tempo-specific — it waits for block inclusion (~500ms on Tempo) and returns
  the receipt inline, eliminating the race condition of separate receipt polling.

  ## Usage

      {:ok, tx_hash} = Onchain.Tempo.RPC.broadcast_async(signed_hex, rpc_url)

      {:ok, tx_hash, receipt} = Onchain.Tempo.RPC.broadcast_sync(signed_hex, rpc_url)

      {:ok, receipt} = Onchain.Tempo.RPC.fetch_receipt(tx_hash, rpc_url)

  ## Options

  All functions accept an `opts` keyword list with:

    * `:req_options` — keyword list passed to `Req.request/2` (timeouts, adapters, etc.)
  """
  # Jason, Req are transitive deps via onchain — not resolved in PLT with path deps
  @dialyzer [:no_unknown]

  @doc """
  Broadcast a signed transaction via async `eth_sendRawTransaction`.

  Returns the transaction hash immediately without waiting for block inclusion.
  """
  @spec broadcast_async(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def broadcast_async(raw_hex, rpc_url, opts \\ []) do
    case rpc_request("eth_sendRawTransaction", [raw_hex], rpc_url, opts) do
      {:ok, tx_hash} when is_binary(tx_hash) ->
        {:ok, tx_hash}

      {:ok, other} ->
        {:error, "Unexpected broadcast response: #{inspect(other)}"}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Broadcast a signed transaction via Tempo's synchronous `eth_sendRawTransactionSync`.

  Waits for block inclusion and returns the full receipt inline. Returns
  `{:ok, tx_hash, receipt}` on success.
  """
  @spec broadcast_sync(String.t(), String.t(), keyword()) :: {:ok, String.t(), map()} | {:error, String.t()}
  def broadcast_sync(raw_hex, rpc_url, opts \\ []) do
    case rpc_request("eth_sendRawTransactionSync", [raw_hex], rpc_url, opts) do
      {:ok, receipt} when is_map(receipt) ->
        tx_hash = receipt["transactionHash"]
        {:ok, tx_hash, parse_receipt(receipt)}

      {:ok, other} ->
        {:error, "Unexpected sync broadcast response: #{inspect(other)}"}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Fetch a transaction receipt via `eth_getTransactionReceipt`.
  """
  @spec fetch_receipt(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def fetch_receipt(tx_hash, rpc_url, opts \\ []) do
    case rpc_request("eth_getTransactionReceipt", [tx_hash], rpc_url, opts) do
      {:ok, nil} ->
        {:error, "Transaction not found on-chain"}

      {:ok, receipt} when is_map(receipt) ->
        {:ok, parse_receipt(receipt)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Parse a raw JSON-RPC receipt map into atom-keyed format.

  The output is compatible with `Onchain.Transfer.parse_logs/1` and
  `Onchain.Tempo.Transfer.parse_transfer_with_memo_logs/1`.
  """
  @spec parse_receipt(map()) :: map()
  def parse_receipt(raw) when is_map(raw) do
    %{
      status: parse_hex_integer(raw["status"]),
      logs: Enum.map(raw["logs"] || [], &parse_log/1)
    }
  end

  # --- Private ---

  # Executes a JSON-RPC request via Req.
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
          body: body
        ],
        req_options
      )

    case result do
      {:ok, %Req.Response{status: status, body: %{"result" => value}}} when status in 200..299 ->
        {:ok, value}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, "RPC error: #{inspect(error)}"}

      {:error, exception} ->
        {:error, "RPC request failed: #{Exception.message(exception)}"}

      {:ok, %Req.Response{} = response} ->
        {:error, "Unexpected RPC response (status #{response.status})"}
    end
  end

  # Converts a raw JSON-RPC log entry to atom-keyed map.
  defp parse_log(log) do
    %{
      address: log["address"],
      topics: log["topics"] || [],
      data: log["data"],
      block_number: parse_hex_integer(log["blockNumber"]) || 0,
      transaction_hash: log["transactionHash"],
      log_index: parse_hex_integer(log["logIndex"]) || 0
    }
  end

  # Parses a hex string like "0x1" into an integer.
  defp parse_hex_integer(nil), do: nil
  defp parse_hex_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex_integer(_), do: nil
end

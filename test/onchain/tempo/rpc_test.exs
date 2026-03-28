defmodule Onchain.Tempo.RPCTest do
  use ExUnit.Case, async: true

  alias Onchain.Tempo.RPC

  describe "parse_receipt/1" do
    test "parses a successful receipt" do
      raw = %{
        "status" => "0x1",
        "logs" => [
          %{
            "address" => "0x20c0000000000000000000000000000000000000",
            "topics" => ["0xabc123"],
            "data" => "0x",
            "blockNumber" => "0xa",
            "transactionHash" => "0xdeadbeef",
            "logIndex" => "0x0"
          }
        ]
      }

      receipt = RPC.parse_receipt(raw)
      assert receipt.status == 1
      assert length(receipt.logs) == 1

      [log] = receipt.logs
      assert log.address == "0x20c0000000000000000000000000000000000000"
      assert log.topics == ["0xabc123"]
      assert log.block_number == 10
      assert log.log_index == 0
    end

    test "parses a reverted receipt" do
      raw = %{"status" => "0x0", "logs" => []}
      receipt = RPC.parse_receipt(raw)
      assert receipt.status == 0
      assert receipt.logs == []
    end

    test "handles missing logs key" do
      raw = %{"status" => "0x1"}
      receipt = RPC.parse_receipt(raw)
      assert receipt.logs == []
    end

    test "handles nil status" do
      raw = %{"status" => nil, "logs" => []}
      receipt = RPC.parse_receipt(raw)
      assert receipt.status == nil
    end
  end

  describe "broadcast_async/3" do
    test "returns ok with tx hash on success" do
      Req.Test.stub(:tempo_rpc, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_sendRawTransaction"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0xdeadbeef"})
      end)

      assert {:ok, "0xdeadbeef"} =
               RPC.broadcast_async("0x76abc", "http://localhost", req_options: [plug: {Req.Test, :tempo_rpc}])
    end

    test "returns error on RPC error response" do
      Req.Test.stub(:tempo_rpc_err, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32_000, "message" => "nonce too low"}
        })
      end)

      assert {:error, msg} =
               RPC.broadcast_async("0x76abc", "http://localhost", req_options: [plug: {Req.Test, :tempo_rpc_err}])

      assert msg =~ "nonce too low"
    end
  end

  describe "broadcast_sync/3" do
    test "returns ok with tx hash and parsed receipt" do
      Req.Test.stub(:tempo_rpc_sync, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "transactionHash" => "0xbeef",
            "status" => "0x1",
            "logs" => []
          }
        })
      end)

      assert {:ok, "0xbeef", receipt} =
               RPC.broadcast_sync("0x76abc", "http://localhost", req_options: [plug: {Req.Test, :tempo_rpc_sync}])

      assert receipt.status == 1
    end
  end

  describe "fetch_receipt/3" do
    test "returns ok with parsed receipt" do
      Req.Test.stub(:tempo_rpc_receipt, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "status" => "0x1",
            "logs" => [],
            "transactionHash" => "0xbeef"
          }
        })
      end)

      assert {:ok, receipt} =
               RPC.fetch_receipt("0xbeef", "http://localhost", req_options: [plug: {Req.Test, :tempo_rpc_receipt}])

      assert receipt.status == 1
    end

    test "returns error when transaction not found" do
      Req.Test.stub(:tempo_rpc_nil, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => nil})
      end)

      assert {:error, "Transaction not found on-chain"} =
               RPC.fetch_receipt("0xbeef", "http://localhost", req_options: [plug: {Req.Test, :tempo_rpc_nil}])
    end
  end
end

defmodule DeltaTest.DataLayerTest.CrashHandlerTest do
  use ExUnit.Case

  alias Delta.DataLayer.CrashHandler

  setup do
    CrashHandler.start_link()
    :ok
  end

  defmodule TestServer do
    use GenServer

    def init(init_arg) do
      {:ok, init_arg}
    end
  end

  test "Delta.DataLayer.CrashHandler.add/2" do
    {:ok, pid} = GenServer.start(TestServer, [])
    self = self()

    CrashHandler.add(pid, fn -> send(self, :crash_handler) end)
    Process.exit(pid, :kill)

    assert_receive :crash_handler
  end

  test "Delta.DataLayer.CrashHandler.remove/2" do
    {:ok, pid} = GenServer.start(TestServer, [])
    self = self()

    CrashHandler.add(pid, fn -> send(self, :crash_handler) end)
    CrashHandler.remove(pid)
    Process.exit(pid, :kill)

    assert {:messages, []} == :erlang.process_info(self(), :messages)
  end
end

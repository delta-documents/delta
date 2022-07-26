defmodule Delta.DataLayer.CrashHandler do
  @moduledoc """
  Runs anonymous function on data layer exit
  """

  require Logger
  use GenServer

  @doc """
  Starts crash handler process with name `Delta.DataLayer.CrashHandler`.
  API assumes that process is named.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %{}}
  end

  @spec add(Delta.DataLayer.layer_id(), function()) :: :ok
  @doc """
  Adds data layer crash handler.
  """
  def add(layer_id, crash_handler) do
    pid = Delta.DataLayer.layer_id_pid(layer_id)

    GenServer.cast(__MODULE__, {:add, pid, crash_handler})
  end

  @spec remove(Delta.DataLayer.layer_id()) :: :ok
  @doc """
  Removes crash handler of data layer.
  """
  def remove(layer_id) do
    pid = Delta.DataLayer.layer_id_pid(layer_id)
    GenServer.cast(__MODULE__, {:remove, pid})
  end

  def handle_cast({:add, pid, fun}, state) do
    m = Process.monitor(pid)
    {:noreply, Map.put(state, pid, {m, fun})}
  end

  def handle_cast({:remove, pid}, state) do
    case Map.pop(state, pid) do
      {{m, _}, state} ->
        Process.demonitor(m)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    case Map.pop(state, pid) do
      {{_, f}, state} ->
        try do
          f.()
        rescue
          e -> Logger.log(:error, e)
        end

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end
end

defmodule Delta.Cache.Change do
  use GenServer

  @persistent __MODULE__.Persistent

  defstruct [:table, :nodes, :write_timeout, :write_timer, :memcheck_timeout, :memcheck_timer, :memory_limit, :dump_on_memory_limit, counter: 0]

  def start_link(init_args \\ []) do
    GenServer.start_link(__MODULE__, init_args)
  end

  def init(args \\ []) do
    %{table: table, nodes: nodes, write_timeout: wt, memcheck_timeout: mt} = state = opts_to_state(args) |> IO.inspect()

    {:atomic, :ok} =
      :mnesia.create_table(
        table,
        attributes: [:order, :id, :previous_change_id, :delta, :updated_at, :meta],
        index: [:id, :previous_change_id],
        type: :ordered_set,
        disc_copies: nodes
      )

    {:ok, _} = :mnesia.subscribe({:table, table, :simple})

    write_timer = Process.send_after(self(), :write_timer, wt)
    memcheck_timer = Process.send_after(self(), :memcheck_timer, mt)

    {:ok, struct(state, write_timer: write_timer, memcheck_timer: memcheck_timer)}
  end

  def load(pid), do: GenServer.call(pid, :load)

  def load(pid, change_ids), do: GenServer.call(pid, {:load, change_ids})

  def write(pid), do: GenServer.cast(pid, :write)

  def dump(pid, percentage \\ nil), do: GenServer.cast(pid, {:dump, percentage})

  def configure(pid, opts), do: GenServer.cast(pid, {:configure, opts})

  def handle_call(:load, _, %__MODULE__{table: tab} = state) do
    with {:ok, changes} <- @persistent.bulk_read(),
         {:atomic, :ok} <- :mnesia.transaction(fn -> Enum.map(changes, &:mnesia.write(tab, &1, :write)) end) do
      {:reply, :ok, state}
    else
      err -> {:reply, err, state}
    end
  end

  def handle_call({:load, change_ids}, _, %__MODULE__{table: tab} = state) do
    with {:ok, changes} <- @persistent.bulk_read(change_ids),
         {:atomic, :ok} <- :mnesia.transaction(fn -> Enum.map(changes, &:mnesia.write(tab, &1, :write)) end) do
      {:reply, :ok, state}
    else
      err -> {:reply, err, state}
    end
  end

  def handle_cast(:write, %__MODULE__{table: tab} = state) do
    folder = fn rec, acc ->
      if needs_sync(rec), do: [rec | acc], else: acc
    end

    {:atomic, records} = :mnesia.transaction(fn -> :mnesia.foldr(folder, [], tab) end)

    {:ok, res} = @persistent.bulk_write(records)

    {:atomic, _} =
      :mnesia.transaction(fn ->
        res
        |> Enum.map(&Delta.Cache.SyncTable.mark_synced(elem(&1, 1)))
      end)

    {:noreply, state} |> IO.inspect()
  end

  def handle_cast({:dump, percentage}, %__MODULE__{table: tab} = state) do
    {:atomic, records} =
      :mnesia.transaction(fn ->
        count = (:mnesia.table_info(tab, :size) * percentage) |> div(100)
        records_to_dump(tab, count)
      end)

    {:ok, res} = @persistent.bulk_write(records)

    {:atomic, _} =
      :mnesia.transaction(fn ->
        Enum.map(res, &:mnesia.delete_object/1)
      end)

    {:noreply, state} |> IO.inspect()
  end

  def handle_cast({:configure, opts}, state) do
    %__MODULE__{write_timer: wt, write_timeout: wto, memcheck_timer: mt, memcheck_timeout: mto} = state = opts_to_state(opts, state)

    Process.cancel_timer(wt)
    Process.cancel_timer(mt)
    write_timer = Process.send_after(self(), :write_timer, wto)
    memcheck_timer = Process.send_after(self(), :memcheck_timer, mto)

    {:noreply, struct(state, write_timer: write_timer, memcheck_timer: memcheck_timer)} |> IO.inspect()
  end

  def handle_info({:mnesia_table_event, _}, %__MODULE__{counter: c} = state) do
    {:noreply, struct(state, counter: c + 1)} |> IO.inspect()
  end

  def handle_info(:write_timer, %__MODULE__{write_timeout: wto, counter: 0} = state) do
    write_timer = Process.send_after(self(), :write_timer, wto)

    {:noreply, struct(state, write_timer: write_timer)} |> IO.inspect()
  end

  def handle_info(:write_timer, %__MODULE__{write_timeout: wt} = state) do
    write(self())
    write_timer = Process.send_after(self(), :write_timer, wt)

    {:noreply, struct(state, write_timer: write_timer, counter: 0)} |> IO.inspect()
  end

  def handle_info(:memcheck_timer, %__MODULE__{table: t, memory_limit: l, memcheck_timeout: mto, dump_on_memory_limit: p} = state) do
    if :mnesia.table_info(t, :memory) * :erlang.system_info(:wordsize) > l, do: dump(self(), p)

    memcheck_timer = Process.send_after(self(), :memcheck_timer, mto)

    {:noreply, struct(state, memcheck_timer: memcheck_timer)}
  end

  defp opts_to_state(opts, %__MODULE__{write_timer: wt, memcheck_timer: mt, counter: c} \\ %__MODULE__{}) do
    opts = Delta.Cache.defaults(opts)

    __MODULE__
    |> struct(opts)
    |> struct(opts[:change])
    |> struct(write_timer: wt, memcheck_timer: mt, counter: c)
  end

  defp records_to_dump(_, c) when c <= 0, do: []
  defp records_to_dump(tab, count) do
    case :mnesia.first(tab) do
      :"$end_of_table" ->
        []

      rec ->
        if needs_sync(rec),
          do: [rec | records_to_dump(tab, count - 1, rec)],
          else: records_to_dump(tab, count - 1, rec)
    end
  end

  defp records_to_dump(_, c, _) when c <= 0, do: []
  defp records_to_dump(tab, count, rec) do
    id = elem(rec, 1)

    case :mnesia.next(tab, id) do
      :"$end_of_table" -> []
      rec -> [rec | records_to_dump(tab, count - 1, rec)]
    end
  end

  defp needs_sync({_, id, _, _, _, updated_at, _}) do
    with %DateTime{} = synced_at <- Delta.Cache.SyncTable.when_synced(id),
         :lt <- DateTime.compare(synced_at, updated_at) do
      true
    else
      _ -> false
    end
  end
end

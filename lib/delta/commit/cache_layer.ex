defmodule Delta.Commit.CacheLayer do
  @moduledoc """
  Caching layer for Delta.Commit
  """

  require Logger
  use GenServer

  alias Delta.DataLayer
  alias Delta.Commit
  alias Delta.Errors.DoesNotExist

  @behaviour DataLayer
  @behaviour Delta.Commit

  defstruct [:document_id, :table]

  @impl DataLayer
  @doc """
  Starts this DataLayer with specific document id.
  Has no options.
  """
  def start_link(document_id, _ \\ nil) do
    table = document_id_to_table(document_id)

    GenServer.start_link(__MODULE__, [
      %__MODULE__{document_id: document_id, table: table}
    ])
  end

  @impl DataLayer
  @doc """
  Returns anonyumous function /0, which deletes mnesia table used by the layer.
  """
  def crash_handler(state) do
    fn ->
      Logger.log(:error, "#{__MODULE__} crashed: #{state}")
    end
  end

  @impl DataLayer
  @doc """
  Runs continuation on this data layer.
  """
  def continue(layer_id, continuation) do
    GenServer.call(DataLayer.layer_id_pid(layer_id), {:continue, continuation})
  end

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/1`
  """
  def list({__MODULE__, document_id} = layer_id, continuation?),
    do: GenServer.call({:via, :swarm, layer_id}, {:list, document_id, continuation?})

  def list(layer_id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(continuation?)

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/2`
  """
  def list({__MODULE__, document_id} = layer_id, from, to, continuation?),
    do: GenServer.call({:via, :swarm, layer_id}, {:list, document_id, from, to, continuation?})

  def list(layer_id, from, to, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(from, to, continuation?)

  @impl Commit
  @doc """
  Gets commit. If it exists, continuation is alwayus `nil`

  See `Delta.Commit.get/1`
  """
  def get({__MODULE__, document_id} = layer_id, id, continuation?),
    do: GenServer.call({:via, :swarm, layer_id}, {:get, document_id, id, continuation?})

  def get(layer_id, id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> get(id, continuation?)

  @impl Commit
  @doc """
  Writes commit. Continuation wirtes commit on another data layer.

  See `Delta.Commit.write/1`
  """
  def write({__MODULE__, document_id} = layer_id, commit, continuation?),
    do: GenServer.call({:via, :swarm, layer_id}, {:write, document_id, commit, continuation?})

  def write(layer_id, commit, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> write(commit, continuation?)

  @impl Commit
  @doc """
  Deletes commit. Always successful. Continuation deletes commit on antother data layer.

  See `Delta.Commit.delete/1`
  """
  def delete({__MODULE__, document_id} = layer_id, commit, continuation?),
    do: GenServer.call({:via, :swarm, layer_id}, {:delete, document_id, commit, continuation?})

  def delete(layer_id, commit, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> delete(commit, continuation?)


  @impl GenServer
  def init(%{document_id: id, table: table} = state) do
    Swarm.register_name({__MODULE__, id}, self())
    Swarm.join(DataLayer, self())

    DataLayer.CrashHandler.add(self(), crash_handler(state))

    :mnesia.create_table(table,
      attributes: [
        :order,
        :id,
        :previous_commit_id,
        :autosquash?,
        :delta,
        :reverse_delta,
        :meta,
        :updated_at
      ],
      index: [:id, :previous_commit_id],
      disc_copies: [node()]
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:continue, continuation}, _from, state) do
    layer_id = self()

    {:reply, continuation.(layer_id), state}
  end

  # def handle_call({:list, false}, _from, %{document_id: document_id, table: table}) do
  #   {status, result} = :mnesia.transaction(list_transaction(table, document_id))
  #   {status, result, nil}
  # end

  # def handle_call({:list, true}, _from, %{document_id: document_id, table: table}) do
  #   {status, result} = :mnesia.transaction(list_transaction(table, document_id))

  #   {status, result,
  #    fn {mod, ^document_id} = layer_id ->
  #      with {:atomic, r, _} <- mod.list(layer_id, document_id, false) do
  #        # TODO: cached data is priority
  #        (result ++ r)
  #        |> Enum.uniq()
  #        |> Enum.sort_by(fn %Commit{order: o} -> o end)
  #      end
  #    end}
  # end

  # def handle_call({:list, from, to, false}, _from, %{document_id: document_id, table: table}) do
  #   from_id = Commit.id(from)
  #   to_id = Commit.id(to)

  #   case :mnesia.transaction(list_transaction(table, from_id, to_id)) do
  #     {:atomic, {result, _}} -> {:atomic, Enum.map(result, &from_record(&1, document_id)), nil}
  #     {status, result} -> {status, result, nil}
  #   end
  # end

  # def handle_call({:list, from, to, true}, _from, %{document_id: document_id, table: table}) do
  #   from_id = Commit.id(from)
  #   to_id = Commit.id(to)

  #   case :mnesia.transaction(list_transaction(table, from_id, to_id)) do
  #     {:atomic, {result, to}} ->
  #       continuation =
  #         case {List.last(result), to} do
  #           {%{id: id}, %{id: id}} ->
  #             nil

  #           {%{id: from_id}, %{id: to_id}} ->
  #             fn {mod, ^document_id} = layer_id ->
  #               with {:atomic, r, _} <- mod.list(layer_id, from_id, to_id, false), do: result ++ r
  #             end
  #         end

  #       {:atomic, Enum.map(result, &from_record(&1, document_id)), continuation}

  #     {status, result} ->
  #       {status, result, fn {mod, ^document_id} -> mod.list(layer_id, from_id, to_id, false) end}
  #   end
  # end

  # def handle_call({:get, id, false}, _from, %{document_id: document_id, table: table}) do
  #   id = Commit.id(id)

  #   {status, result} = :mnesia.transaction(get_transaction(table, document_id, id))

  #   {status, result, nil}
  # end

  # def handle_call({:get, id, true}, _from, %{document_id: document_id, table: table}) do
  #   id = Commit.id(id)

  #   case :mnesia.transaction(get_transaction(table, document_id, id)) do
  #     {:atomic, result} ->
  #       {:atomic, result, nil}

  #     {status, result} ->
  #       {status, result, fn {mod, ^document_id} = layer_id -> mod.get(layer_id, id, false) end}
  #   end
  # end

  # def handle_call({:write, commit, false}, _from, %{document_id: document_id, table: table}) do

  # end

  # def handle_call({:write, commit, true}, _from, %{document_id: document_id, table: table}) do

  # end

  # def handle_call({:delete, commit, false}, _from, %{document_id: document_id, table: table}) do

  # end

  # def handle_call({:delete, commit, true}, _from, %{document_id: document_id, table: table}) do

  # end

  # defp list_transaction(table, document_id) do
  #   :mnesia.foldl(
  #     fn rec, acc -> [from_record(rec, document_id) | acc] end,
  #     [],
  #     table
  #   )
  # end

  # defp list_transaction(table, from_id, to_id) do
  #   fn ->
  #     from1 = :mnesia.index_read(table, from_id, 3)
  #     to1 = :mnesia.index_read(table, to_id, 3)

  #     [from] = if from1 == [], do: :mnesia.last(table), else: from1
  #     [to] = if to1 == [], do: :mnesia.first(table), else: to1

  #     from_order = elem(from, 1)
  #     to_order = elem(to, 1)

  #     {Enum.flat_map(from_order..to_order//-1, &:mnesia.read(table, &1)), to}
  #   end
  # end

  # # def get({__MODULE__, document_id} = layer_id, id, true) do
  # #
  # #
  # #
  # #
  # #
  # #
  # #
  # # end

  # # defp get_transaction(table, document_id, id) do
  # #   fn ->
  # #     case :mnesia.index_read(table, id, 3) do
  # #       [r] -> from_record(r, document_id)
  # #       [] -> :mnesia.abort(%DoesNotExist{struct: Commit, id: id})
  # #     end
  # #   end
  # # end

  # # @impl Commit
  # # def write(layer_id, commit, false) do
  # #   table = table(layer_id)

  # #   {status, result} = :mnesia.transaction(write_transaction(table, commit))

  # #   {status, result, nil}
  # # end

  # # def write({__MODULE__, document_id} = layer_id, commit, true) do
  # #   table = table(layer_id)

  # #   with {:atomic, result} <- :mnesia.transaction(write_transaction(table, commit)) do
  # #     id = Commit.id(result)

  # #     {:atomic, result,
  # #      fn {mod, ^document_id} = l ->
  # #        with {:atomic, result, _} <- get(layer_id, id, false), do: mod.write(l, result, false)
  # #      end}
  # #   else
  # #     {status, result} -> {status, result, nil}
  # #   end
  # # end

  # # defp write_transaction(table, commit) do
  # #   fn ->
  # #     commit
  # #     |> to_record(table)
  # #     |> :mnesia.write()

  # #     commit
  # #   end
  # # end

  # # @impl Commit
  # # def delete(layer_id, id, false) do
  # #   id = Commit.id(id)
  # #   table = table(layer_id)

  # #   {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
  # #   {status, result, nil}
  # # end

  # # def delete({__MODULE__, document_id} = layer_id, id, true) do
  # #   id = Commit.id(id)
  # #   table = table(layer_id)

  # #   {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
  # #   {status, result, fn {mod, ^document_id} = layer_id -> mod.delete(layer_id, id, false) end}
  # # end

  # # defp delete_transaction(table, id) do
  # #   fn ->
  # #     case :mnesia.index_read(table, id, 3) do
  # #       [r] -> :mnesia.delete_object(r)
  # #       _ -> :ok
  # #     end
  # #   end
  # # end

  defp from_record(
         {_, order, id, previous_commit_id, autosquash?, delta, reverse_delta, meta, updated_at},
         document_id
       ) do
    %Commit{
      id: id,
      previous_commit_id: previous_commit_id,
      document_id: document_id,
      order: order,
      autosquash?: autosquash?,
      delta: delta,
      reverse_delta: reverse_delta,
      meta: meta,
      updated_at: updated_at
    }
  end

  defp to_record(
         %Commit{
           id: id,
           previous_commit_id: previous_commit_id,
           order: order,
           autosquash?: autosquash?,
           delta: delta,
           reverse_delta: reverse_delta,
           meta: meta,
           updated_at: updated_at
         },
         document_id
       ) do
    {document_id_to_table(document_id), order, id, previous_commit_id, autosquash?, delta, reverse_delta, meta, updated_at}
  end

  defp document_id_to_table(id), do: :"#{__MODULE__}.#{id}"
end

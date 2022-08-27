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

  defstruct [:document_id, :table, :persistent_layer, continuations: []]

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

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/1`
  """
  def list({__MODULE__, document_id}, false) do
    table = document_id_to_table(document_id)

    {status, result} = :mnesia.transaction(list_transaction(table))
    {status, result, nil}
  end

  def list({__MODULE__, document_id}, true) do
    table = document_id_to_table(document_id)

    {status, result} = :mnesia.transaction(list_transaction(table))

    {status, result,
     fn {mod, ^document_id} = layer_id ->
       with {:atomic, r, _} <- mod.list(layer_id, document_id, false) do
         # TODO: cached data is priority
         (result ++ r)
         |> Enum.uniq()
         |> Enum.sort_by(fn %Commit{order: o} -> o end)
       end
     end}
  end

  def list(layer_id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(continuation?)

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/2`
  """
  def list({__MODULE__, document_id}, from, to, false) do
    table = document_id_to_table(document_id)

    from_id = Commit.id(from)
    to_id = Commit.id(to)

    case :mnesia.transaction(list_transaction(table, from_id, to_id)) do
      {:atomic, {result, _}} -> {:atomic, Enum.map(result, &from_record/1), nil}
      {status, result} -> {status, result, nil}
    end
  end

  def list({__MODULE__, document_id}, from, to, true) do
    table = document_id_to_table(document_id)

    from_id = Commit.id(from)
    to_id = Commit.id(to)

    case :mnesia.transaction(list_transaction(table, from_id, to_id)) do
      {:atomic, {result, to}} ->
        continuation =
          case {List.last(result), to} do
            {%{id: id}, %{id: id}} ->
              nil

            {%{id: from_id}, %{id: to_id}} ->
              fn {mod, ^document_id} = layer_id ->
                with {:atomic, r, _} <- mod.list(layer_id, from_id, to_id, false), do: result ++ r
              end
          end

        {:atomic, Enum.map(result, &from_record/1), continuation}

      {status, result} ->
        {status, result,
         fn {mod, ^document_id} = layer_id -> mod.list(layer_id, from_id, to_id, false) end}
    end
  end

  def list(layer_id, from, to, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(from, to, continuation?)

  @impl Commit
  @doc """
  Gets commit. If it exists, continuation is alwayus `nil`

  See `Delta.Commit.get/1`
  """
  def get({__MODULE__, document_id}, id, false) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    {status, result} = :mnesia.transaction(get_transaction(table, id))
    {status, result, nil}
  end

  def get({__MODULE__, document_id}, id, true) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    case :mnesia.transaction(get_transaction(table, id)) do
      {:atomic, result} ->
        {:atomic, result, nil}

      {status, result} ->
        {status, result, fn {mod, ^document_id} = layer_id -> mod.get(layer_id, id, false) end}
    end
  end

  def get(layer_id, id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> get(id, continuation?)

  @impl Commit
  @doc """
  Writes commit. Continuation wirtes commit on another data layer.

  See `Delta.Commit.write/1`
  """
  def write({__MODULE__, document_id} = layer_id, commit, continuation?) do
    with {:atomic, result} <- :mnesia.transaction(write_transaction(commit)) do
      id = Commit.id(result)

      continuation = fn {mod, ^document_id} = l ->
        with {:atomic, result, _} <- get(layer_id, id, false), do: mod.write(l, result, false)
      end

      add_continuation(layer_id, continuation)

      {:atomic, result, if(continuation?, do: continuation, else: nil)}
    else
      {status, result} -> {status, result, nil}
    end
  end

  def write(layer_id, commit, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> write(commit, continuation?)

  @impl Commit
  @doc """
  Deletes commit. Always successful. Continuation deletes commit on antother data layer.

  See `Delta.Commit.delete/1`
  """
  def delete({__MODULE__, document_id} = layer_id, id, continuation?) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    continuation = fn {mod, ^document_id} = layer_id -> mod.delete(layer_id, id, false) end

    {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
    add_continuation(layer_id, continuation)
    {status, result, if(continuation?, do: continuation, else: nil)}
  end

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
      index: [:id, :previous_commit_id, :autosquash?],
      disc_copies: [node()]
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:add_continuation, continuation}, %{continuations: cs} = state),
    do: {:noreply, struct(state, continuations: [continuation | cs])}

  defp list_transaction(table) do
    :mnesia.foldl(
      fn rec, acc -> [from_record(rec) | acc] end,
      [],
      table
    )
  end

  defp list_transaction(table, from_id, to_id) do
    fn ->
      from1 = :mnesia.index_read(table, from_id, 3)
      to1 = :mnesia.index_read(table, to_id, 3)

      [from] = if from1 == [], do: :mnesia.last(table), else: from1
      [to] = if to1 == [], do: :mnesia.first(table), else: to1

      from_order = elem(from, 1)
      to_order = elem(to, 1)

      {Enum.flat_map(from_order..to_order//-1, &:mnesia.read(table, &1)), to}
    end
  end

  defp get_transaction(table, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> from_record(r)
        [] -> :mnesia.abort(%DoesNotExist{struct: Commit, id: id})
      end
    end
  end

  defp write_transaction(commit) do
    fn ->
      commit
      |> to_record()
      |> :mnesia.write()

      commit
    end
  end

  defp delete_transaction(table, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> :mnesia.delete_object(r)
        _ -> :ok
      end
    end
  end

  defp add_continuation(layer_id, continuation),
    do: GenServer.cast(DataLayer.layer_id_pid(layer_id), {:add_continuation, continuation})

  defp from_record(
         {_, order, id, previous_commit_id, document_id, autosquash?, delta, reverse_delta, meta,
          updated_at}
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
           document_id: document_id,
           order: order,
           autosquash?: autosquash?,
           delta: delta,
           reverse_delta: reverse_delta,
           meta: meta,
           updated_at: updated_at
         }
       ) do
    {document_id_to_table(document_id), order, id, previous_commit_id, autosquash?, delta,
     reverse_delta, meta, updated_at}
  end

  defp document_id_to_table(id), do: :"#{__MODULE__}.#{id}"
end

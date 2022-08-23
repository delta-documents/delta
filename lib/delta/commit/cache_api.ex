defmodule Delta.Commit.CacheApi do
  @moduledoc """
  Cache API for Commits, duplicates Delta.Commit API
  """
  import Delta.Commit.CacheLayer, only: [table: 1]

  alias Delta.Commit
  alias Delta.Commit.CacheLayer
  alias Delta.Errors.{DoesNotExist, AlreadyExist}

  @behaviour Delta.Commit

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.
  """
  def list({CacheLayer, document_id} = layer_id, document_id, false) do
    table = table(layer_id)
    {status, result} = :mnesia.transaction(list_transaction(table, document_id))
    {status, result, nil}
  end

  def list({CacheLayer, document_id} = layer_id, document_id, true) do
    table = table(layer_id)
    {status, result} = :mnesia.transaction(list_transaction(table, document_id))

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

  defp list_transaction(table, document_id) do
    :mnesia.foldl(
      fn rec, acc -> [from_record(rec, document_id) | acc] end,
      [],
      table
    )
  end

  @impl Commit
  @doc """
  Continuation lists data on another data layer with priority to this data layer.
  Adds data from another data layer to this data layer.
  """
  def list({CacheLayer, document_id} = layer_id, from, to, false) do
    from_id = Commit.id(from)
    to_id = Commit.id(to)
    table = table(layer_id)

    case :mnesia.transaction(list_transaction(table, from_id, to_id)) do
      {:atomic, {result, _}} -> {:atomic, Enum.map(result, &from_record(&1, document_id)), nil}
      {status, result} -> {status, result, nil}
    end
  end

  def list({CacheLayer, document_id} = layer_id, from, to, true) do
    from_id = Commit.id(from)
    to_id = Commit.id(to)
    table = table(layer_id)

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

        {:atomic, Enum.map(result, &from_record(&1, document_id)), continuation}

      {status, result} ->
        {status, result, fn {mod, ^document_id} -> mod.list(layer_id, from_id, to_id, false) end}
    end
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

  @impl Commit
  def get({CacheLayer, document_id} = layer_id, id, false) do
    table = table(layer_id)
    id = Commit.id(id)

    {status, result} = :mnesia.transaction(get_transaction(table, document_id, id))

    {status, result, nil}
  end

  def get({CacheLayer, document_id} = layer_id, id, true) do
    table = table(layer_id)
    id = Commit.id(id)

    case :mnesia.transaction(get_transaction(table, document_id, id)) do
      {:atomic, result} ->
        {:atomic, result, nil}

      {status, result} ->
        {status, result, fn {mod, ^document_id} = layer_id -> mod.get(layer_id, id, false) end}
    end
  end

  defp get_transaction(table, document_id, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> from_record(r, document_id)
        [] -> :mnesia.abort(%DoesNotExist{struct: Commit, id: id})
      end
    end
  end

  @impl Commit
  def write(layer_id, commit, false) do
    table = table(layer_id)

    {status, result} = :mnesia.transaction(write_transaction(table, commit))

    {status, result, nil}
  end

  def write({CacheLayer, document_id} = layer_id, commit, true) do
    table = table(layer_id)

    with {:atomic, result} <- :mnesia.transaction(write_transaction(table, commit)) do
      id = Commit.id(result)
      {:atomic, result, fn {mod, ^document_id} = l ->
        with {:atomic, result, _} <- get(layer_id, id, false), do: mod.write(l, result, false)
      end}
    else
      {status, result} -> {status, result, nil}
    end
  end

  defp write_transaction(table, commit) do
    fn ->
      commit
      |> to_record(table)
      |> :mnesia.write()

      commit
    end
  end

  @impl Commit
  def delete(layer_id, id, false) do
    id = Commit.id(id)
    table = table(layer_id)

    {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
    {status, result, nil}
  end

  def delete({CacheLayer, document_id} = layer_id, id, true) do
    id = Commit.id(id)
    table = table(layer_id)

    {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
    {status, result, fn {mod, ^document_id} = layer_id -> mod.delete(layer_id, id, false) end}
  end

  defp delete_transaction(table, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> :mnesia.delete_object(r)
        _ -> :ok
      end
    end
  end

  @impl Commit
  def squash(layer_id, id, id, continuation?) do
  end

  def do_squash() do
  end

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
         table
       ) do
    {table, order, id, previous_commit_id, autosquash?, delta, reverse_delta, meta, updated_at}
  end
end

defmodule Delta.Document do
  use Delta.Storage.RecordHelper
  defstruct [:id, :collection_id, :latest_change_id, data: %{}]
  use Delta.Storage.MnesiaHelper, struct: Delta.Document

  alias Delta.{Change, Validators, Collection}
  alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation, Conflict}

  def new(d \\ %{}, id1 \\ nil, id2 \\ nil, id0 \\ UUID.uuid4()) do
    %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}
  end

  def validate(%__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}) do
    with {:ok, id0} <- Validators.uuid(id0, %Validation{struct: __MODULE__, field: :id}),
         {:ok, id1} <-
           Validators.uuid(id1, %Validation{struct: __MODULE__, field: :collection_id}),
         {:ok, id2} <-
           Validators.maybe_uuid(id2, %Validation{struct: __MODULE__, field: :latest_change_id}),
         {:ok, d} <- Validators.map(d, %Validation{struct: __MODULE__, field: :data}) do
      {:ok, %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}}
    end
  end

  def validate(_) do
    {
      :error,
      %Validation{struct: __MODULE__, field: :*, expected: __MODULE__, got: "not an instance of"}
    }
  end

  def list do
    :mnesia.transaction(fn -> MnesiaHelper.list() end)
  end

  def list(collection: %Collection{id: cid}), do: list(collection: cid)

  def list(collection: cid) do
    :mnesia.transaction(fn ->
      with {:collection, [^cid]} <- {:collection, Collection.collection_id(cid)} do
        # Erlang index is 1-based
        :mnesia.index_read(__MODULE__, cid, 2)
        |> Enum.map(&from_record/1)
      else
        {:collection, []} ->
          :mnesia.abort(%DoesNotExist{struct: Collection, id: cid})
      end
    end)
  end

  def get(m) do
    :mnesia.transaction(fn ->
      with [r] <- MnesiaHelper.get(m) do
        r
      else
        [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: m})
      end
    end)
  end

  def create(m) do
    :mnesia.transaction(fn ->
      case MnesiaHelper.get(m) do
        [] -> validated_write(m)
        [_] -> :mnesia.abort(%AlreadyExist{struct: __MODULE__, id: m})
      end
    end)
  end

  def update(m, attrs), do: update(struct(m, attrs))

  def update(m) do
    :mnesia.transaction(fn ->
      case MnesiaHelper.get(m) do
        [_] -> validated_write(m)
        [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: m})
      end
    end)
  end

  defp validated_write(%{collection_id: cid, latest_change_id: lid} = m) do
    with {:validate, {:ok, m}} <- {:validate, validate(m)},
         {:collection, [^cid]} <- {:collection, Collection.collection_id(cid)},
         {:latest_change, [^lid]} <- {:latest_change, Delta.Change.maybe_change_id(lid)} do
      MnesiaHelper.write(m)
    else
      {:validate, {:error, err}} ->
        :mnesia.abort(err)

      {:collection, []} ->
        :mnesia.abort(%DoesNotExist{struct: Collection, id: m})

      {:latest_change, []} ->
        :mnesia.abort(%DoesNotExist{struct: Change, id: m})
    end
  end


  def add_changes(document, changes) do
    :mnesia.transaction(fn ->
      case get(document) do
        {:atomic, d} -> do_add_changes(d, changes)
        {:aborted, reason} -> :mnesia.abort(reason)
      end
    end)
  end

  def do_add_changes(%__MODULE__{latest_change_id: latest_id}, changes),
    do: do_add_changes(latest_id, changes)

  def do_add_changes(latest_id, [
        %Change{id: next_id, previous_change_id: latest_id} = change | changes
      ]) do
    case Change.create(change) do
      {:atomic, _} -> [{:no_conflict, change} | do_add_changes(next_id, changes)]
      {:aborted, reason} -> :mnesia.abort(reason)
    end
  end

  def do_add_changes(latest_id0, [
        %Change{id: next_id, previous_change_id: latest_id1, path: p} = change | changes
      ]) do
    with {:history, {:atomic, history}} <-
           {:history, Change.list(from: latest_id0, to: latest_id1)},
         {:conflict, :resolvable} <- {:conflict, check_conflict(history, p)},
         resolved <- Map.put(change, :previous_id, latest_id0),
         {:create, {:atomic, _}} <- Change.create(resolved) do
      [{:resolved, resolved} | do_add_changes(next_id, changes)]
    else
      {:conflict, %{id: id}} -> :mnesia.abort(%Conflict{change_id: next_id, conflicts_with: id})
      {_, {:aborted, reason}} -> :mnesia.abort(reason)
    end
  end

  def delete(m) do
    :mnesia.transaction(fn -> do_delete(m) end)
  end

  def do_delete(%__MODULE__{id: id}), do: do_delete(id)

  def do_delete(id) do
    # Erlang index is 1-based
    :mnesia.index_read(Delta.Change, id, 2)
    |> Enum.map(&Delta.Change.do_delete(elem(&1, 1)))

    MnesiaHelper.delete(id)
  end

  def document_id(id) do
    case MnesiaHelper.get(id) do
      [%{id: id}] -> [id]
      x -> x
    end
  end

  defp check_conflict(history, path),
    do: Enum.find(history, :resolvable, fn %{path: p} -> Delta.Path.overlap?(path, p) end)
end

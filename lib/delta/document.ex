defmodule Delta.Document do
  use Delta.Storage.RecordHelper
  defstruct [:id, :collection_id, :latest_change_id, data: %{}]
  use Delta.Storage.MnesiaHelper, struct: Delta.Document

  alias Delta.{Change, Validators, Collection}
  alias Delta.Errors.{Validation, Conflict}

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
      %Validation{struct: __MODULE__, expected: __MODULE__, got: "not an instance of"}
    }
  end

  def list(%Collection{id: cid}), do: list(cid)

  def list(cid) do
    with {:collection, [^cid]} <- {:collection, Collection.id(cid)} do
      :mnesia.index_read(__MODULE__, cid, 3)
      |> Enum.map(&from_record/1)
    else
      {:collection, []} ->
        :mnesia.abort(%DoesNotExist{struct: Collection, id: cid})
    end
  end

  def list_transaction(collection), do: :mnesia.transaction(fn -> list(collection) end)

  def write(%{collection_id: cid, latest_change_id: lid} = m) do
    with {:validate, {:ok, m}} <- {:validate, validate(m)},
         {:collection, [^cid]} <- {:collection, Collection.id(cid)},
         {:latest_change, [^lid]} <- {:latest_change, Delta.Change.maybe_id(lid)} do
      super(m)
    else
      {:validate, {:error, err}} ->
        :mnesia.abort(err)

      {:collection, []} ->
        :mnesia.abort(%DoesNotExist{struct: Collection, id: cid})

      {:latest_change, []} ->
        :mnesia.abort(%DoesNotExist{struct: Change, id: lid})
    end
  end

  def delete(m) do
    case id(m) do
      [id] ->
        :mnesia.index_read(Delta.Change, id, 3)
        |> Enum.map(&Delta.Change.delete(elem(&1, 1)))

        super(id)

      _ ->
        :ok
    end
  end

  def add_changes(document, %Change{} = c), do: add_changes(document, [c])

  def add_changes(document, changes) do
    with [d] <- get(document) do
      do_add_changes(document, changes)
    else
      [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: document})
    end
  end

  def do_add_changes(document, history \\ %{}, changes), do: nil

  defp check_conflict(history, path),
    do: Enum.find(history, :resolvable, fn %{path: p} -> Delta.Path.overlap?(path, p) end)
end

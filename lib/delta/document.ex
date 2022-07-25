defmodule Delta.Document do
  use Delta.Storage.RecordHelper
  defstruct [:id, :collection_id, :latest_change_id, data: %{}]
  use Delta.Storage.MnesiaHelper, struct: Delta.Document

  alias Delta.{Change, Validators, Collection}
  alias Delta.Errors.{Validation, Conflict}

  def new(d \\ %{}, id1 \\ nil, id2 \\ nil, id0 \\ UUID.uuid4()), do: %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}

  def validate(%__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}) do
    with {:ok, id0} <- Validators.uuid(id0, %Validation{struct: __MODULE__, field: :id}),
         {:ok, id1} <- Validators.uuid(id1, %Validation{struct: __MODULE__, field: :collection_id}),
         {:ok, id2} <- Validators.maybe_uuid(id2, %Validation{struct: __MODULE__, field: :latest_change_id}),
         {:ok, d} <- Validators.map(d, %Validation{struct: __MODULE__, field: :data}) do
      {:ok, %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}}
    end
  end

  def validate(_), do: {:error, %Validation{struct: __MODULE__, expected: __MODULE__, got: "not an instance of"}}

  def list(%Collection{id: cid}), do: list(cid)

  def list(cid) do
    with {:collection, [^cid]} <- {:collection, Collection.id(cid)} do
      :mnesia.index_read(__MODULE__, cid, 3)
      |> Enum.map(&from_record/1)
    else
      {:collection, []} -> :mnesia.abort(%DoesNotExist{struct: Collection, id: cid})
    end
  end

  def list_transaction(collection), do: :mnesia.transaction(fn -> list(collection) end)

  def write(%{collection_id: cid, latest_change_id: lid} = m) do
    with {:validate, {:ok, m}} <- {:validate, validate(m)},
         {:collection, [^cid]} <- {:collection, Collection.id(cid)},
         {:latest_change, [^lid]} <- {:latest_change, Change.maybe_id(lid)} do
      super(m)
    else
      {:validate, {:error, err}} -> :mnesia.abort(err)
      {:collection, []} -> :mnesia.abort(%DoesNotExist{struct: Collection, id: cid})
      {:latest_change, []} -> :mnesia.abort(%DoesNotExist{struct: Change, id: lid})
    end
  end

  def delete(m) do
    case id(m) do
      [id] ->
        :mnesia.index_read(Change, id, 3)
        |> Enum.map(&Change.delete(elem(&1, 1)))

        super(id)

      _ ->
        :ok
    end
  end

  def add_changes(document, %Change{} = c), do: add_changes(document, [c])

  def add_changes(%{latest_change_id: lid} = document, changes) do
    changes
    |> Enum.each(fn c ->
      case Change.validate(c) do
        {:ok, _} -> :ok
        {:error, err} -> :mnesia.abort(err)
      end
    end)

    h = Change.homogenous(changes)

    case(get_transaction(document)) do
      {:atomic, document} ->
        :mnesia.lock({:record, __MODULE__, document.id}, :write)

        history = history(h, lid)
        {document, changes} = do_add_homogenous_changes(document, history, h)

        Enum.map(changes, &Delta.Change.create/1)

        update(document)

        changes

      {:aborted, err} ->
        :mnesia.abort(err)
    end
  end

  defp history(homogenous, latest_id) do
    homogenous
    |> Enum.map(fn [%{previous_change_id: id} | _] -> Change.list(id, latest_id) end)
  end

  def do_add_homogenous_changes(document, history, homogenous_changes) do
    Enum.zip(history, homogenous_changes)
    |> Enum.reduce({document, []}, fn {history, changes}, {document, changes_to_write} ->
      {new_document, c} = do_add_changes(document, history, changes)
      {new_document, c ++ changes_to_write}
    end)
  end

  defp do_add_changes(document, _, []), do: {document, []}

  defp do_add_changes(document, [%{id: id} | _] = history, [%{previous_change_id: id} = c | changes]) do
    c = Change.write(c)
    document = Change.apply_change(document, c)

    {document, changes} = do_add_changes(document, [c | history], changes)
    {document, [c | changes]}
  end

  defp do_add_changes(document, history, [%{path: p} = c | changes]) do
    case check_conflict(history, p) do
      :resolvable -> resolve(document, history, c, changes)
      %{id: conflicts_with} -> :mnesia.abort(%Conflict{change_id: c.id, conflicts_with: conflicts_with})
    end
  end

  defp resolve(document, [%{id: id} | _] = history, c, changes) do
    c = Map.update!(c, :previous_change_id, id)
    c = Change.write(c)
    document = Change.apply_change(document, c)

    {document, changes} = do_add_changes(document, [c | history], changes)
    {document, [c | changes]}
  end

  defp check_conflict(history, path), do: Enum.find(history, :resolvable, fn %{path: p} -> Delta.Path.overlap?(path, p) end)
end

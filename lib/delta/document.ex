defmodule Delta.Document do
  use Delta.Storage.RecordHelper
  defstruct [:id, :collection_id, :latest_change_id, data: %{}]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  def new(d \\ %{}, id1 \\ nil, id2 \\ nil, id0 \\ UUID.uuid4()) do
    %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}
  end

  def validate(%__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}) do
    with {:ok, id0} <- Delta.Validators.uuid(id0, "#{__MODULE__}.id"),
         {:ok, id1} <- Delta.Validators.uuid(id1, "#{__MODULE__}.collection_id"),
         {:ok, id2} <- Delta.Validators.maybe_uuid(id2, "#{__MODULE__}.latest_change_id"),
         {:ok, d} <- Delta.Validators.map(d, "#{__MODULE__}.data") do
      {:ok, %__MODULE__{id: id0, collection_id: id1, latest_change_id: id2, data: d}}
    end
  end

  def validate(_), do: {:error, "Not an instance of #{__MODULE__}"}

  def list do
    :mnesia.transaction(fn -> MnesiaHelper.list() end)
  end

  def list(collection: %Delta.Collection{id: cid}), do: list(collection: cid)

  def list(collection: cid) do
    :mnesia.transaction(fn ->
      with {:collection, [^cid]} <- {:collection, Delta.Collection.collection_id(cid)} do
        # Erlang index is 1-based
        :mnesia.index_read(__MODULE__, cid, 2)
        |> Enum.map(&from_record/1)
      else
        {:collection, []} ->
          :mnesia.abort("#{inspect(Delta.Collection)} with id = #{cid} does not exists")
      end
    end)
  end

  def get(m) do
    :mnesia.transaction(fn ->
      with [r] <- MnesiaHelper.get(m) do
        r
      else
        [] -> :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} does not exist")
      end
    end)
  end

  def create(%{collection_id: cid, latest_change_id: lid} = m) do
    :mnesia.transaction(fn ->
      with {:get, []} <- MnesiaHelper.get(m),
           {:validate, {:ok, m}} <- {:validate, validate(m)},
           {:collection, [^cid]} <- {:collection, Delta.Collection.collection_id(cid)},
           {:latest_change, [^lid]} <- {:latest_change, Delta.Change.maybe_change_id(lid)} do
        MnesiaHelper.write(m)
      else
        {:get, [_]} ->
          :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} already exists")

        {:validate, {:error, err}} ->
          :mnesia.abort(err)

        {:collection, []} ->
          :mnesia.abort("#{inspect(Delta.Collection)} with id = #{cid} does not exists")

        {:latest_change, []} ->
          :mnesia.abort("#{inspect(Delta.Collection)} with id = #{lid} does not exists")
      end
    end)
  end

  def update(%{collection_id: cid, latest_change_id: lid} = m) do
    :mnesia.transaction(fn ->
      with {:get, [_]} <- MnesiaHelper.get(m),
           {:validate, {:ok, m}} <- {:validate, validate(m)},
           {:collection, [^cid]} <- {:collection, Delta.Collection.collection_id(cid)},
           {:latest_change, [^lid]} <- {:latest_change, Delta.Change.maybe_change_id(lid)} do
        MnesiaHelper.write(m)
      else
        {:get, []} ->
          :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} does not exist")

        {:validate, {:error, err}} ->
          :mnesia.abort(err)

        {:collection, []} ->
          :mnesia.abort("#{inspect(Delta.Collection)} with id = #{cid} does not exists")

        {:latest_change, []} ->
          :mnesia.abort("#{inspect(Delta.Collection)} with id = #{lid} does not exists")
      end
    end)
  end

  def update(m, attrs), do: update(struct(m, attrs))

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
end

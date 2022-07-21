defmodule Delta.Change do
  use Delta.Storage.RecordHelper
  defstruct [:id, :document_id, :previous_change_id, :kind, :path, :value, :meta]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  def new(
        id0 \\ UUID.uuid4(),
        id1 \\ nil,
        id2 \\ nil,
        kind \\ :update,
        p1 \\ [],
        v \\ nil,
        m \\ nil
      ) do
    %__MODULE__{
      id: id0,
      document_id: id1,
      previous_change_id: id2,
      kind: kind,
      path: p1,
      value: v,
      meta: m
    }
  end

  def validate(%__MODULE__{
        id: id0,
        document_id: id1,
        previous_change_id: id2,
        kind: kind,
        path: p1,
        value: v,
        meta: m
      }) do
    with {:ok, id0} <- Delta.Validators.uuid(id0, "#{__MODULE__}.id"),
         {:ok, id1} <- Delta.Validators.uuid(id1, "#{__MODULE__}.document_id"),
         {:ok, id2} <- Delta.Validators.maybe_uuid(id2, "#{__MODULE__}.previous_change_id"),
         {:ok, p1} <- Delta.Validators.path(p1, "#{__MODULE__}.path"),
         {:ok, kind} <- Delta.Validators.kind(kind, "#{__MODULE__}.kind") do
      {:ok,
       %__MODULE__{
         id: id0,
         document_id: id1,
         previous_change_id: id2,
         kind: kind,
         path: p1,
         value: v,
         meta: m
       }}
    end
  end

  def list do
    :mnesia.transaction(fn -> MnesiaHelper.list() end)
  end

  def list(document: %Delta.Document{id: cid}), do: list(document: cid)

  def list(document: cid) do
    :mnesia.transaction fn ->
      with {:document, [^cid]} <- {:document, Delta.Document.document_id(cid)} do
        :mnesia.index_read(__MODULE__, cid, 2) # Erlang index is 1-based
        |> Enum.map(&from_record/1)
      else
        {:document, []} -> :mnesia.abort("#{inspect(Delta.Document)} with id = #{cid} does not exists")
      end
    end
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
           {:validate, {:ok, m}} <- {:validate, validate(m)} do
        MnesiaHelper.write(m)
      else
        {:get, [_]} -> :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} already exists")
        {:validate, {:error, err}} -> :mnesia.abort(err)
      end
    end)
  end

  def update(%{collection_id: cid, latest_change_id: lid} = m) do
    :mnesia.transaction(fn ->
      with {:get, [_]} <- MnesiaHelper.get(m),
           {:validate, {:ok, m}} <- {:validate, validate(m)} do
        MnesiaHelper.write(m)
      else
        {:get, []} -> :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} does not exist")
        {:validate, {:error, err}} -> :mnesia.abort(err)
      end
    end)
  end

  def update(m, attrs), do: update(struct(m, attrs))

  def delete(m) do
    :mnesia.transaction(fn -> do_delete(m) end)
  end

  def do_delete(m) do
    MnesiaHelper.delete(m)
  end

  def maybe_change_id(nil), do: [nil]
  def maybe_change_id(id), do: change_id(id)

  def change_id(id) do
    case MnesiaHelper.get(id) do
      [%{id: id}] -> [id]
      x -> x
    end
  end
end

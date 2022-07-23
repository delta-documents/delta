defmodule Delta.Change do
  use Delta.Storage.RecordHelper
  defstruct [:id, :document_id, :previous_change_id, :kind, :path, :value, :meta]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  alias Delta.{Document, Validators}
  alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation}

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
    with {:ok, id0} <- Validators.uuid(id0, %Validation{struct: __MODULE__, field: :id}),
         {:ok, id1} <- Validators.uuid(id1, %Validation{struct: __MODULE__, field: :document_id}),
         {:ok, id2} <- Validators.maybe_uuid(id2, %Validation{struct: __MODULE__, field: :previous_change_id}),
         {:ok, p1} <- Validators.path(p1, %Validation{struct: __MODULE__, field: :path}),
         {:ok, kind} <- Validators.kind(kind, %Validation{struct: __MODULE__, field: :kind}) do
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

  def list(document: %Document{id: cid}), do: list(document: cid)

  def list(document: did) do
    :mnesia.transaction(fn ->
      with {:document, [^did]} <- {:document, Document.document_id(did)} do
        # Erlang index is 1-based
        :mnesia.index_read(__MODULE__, did, 2)
        |> Enum.map(&from_record/1)
      else
        {:document, []} ->
          :mnesia.abort(%DoesNotExist{struct: Document, id: did})
      end
    end)
  end

  def list(from: from, to: to) do
    :mnesia.transaction(fn ->
      do_list_from_to(from, to)
    end)
  end

  def do_list_from_to(f, t) do
    case MnesiaHelper.get(f) do
      [%{previous_id: p} = c] -> [c | do_list_from_to(p, t)]
      [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: f})
    end
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

  def get(m) do
    :mnesia.transaction(fn ->
      case MnesiaHelper.get(m) do
        [r] -> r
        [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: m})
      end
    end)
  end

  def validated_write(%{document_id: did, previous_change_id: pid} = m) do
    :mnesia.transaction(fn ->
      with {:validate, {:ok, m}} <- {:validate, validate(m)},
           {:document, [^did]} <- {:document, Document.document_id(did)},
           {:previous, [^pid]} <- {:previous, maybe_change_id(pid)} do
        MnesiaHelper.write(m)
      else
        {:validate, {:error, err}} ->
          :mnesia.abort(err)

        {:document, []} ->
          :mnesia.abort(%DoesNotExist{struct: Document, id: did})

        {:previous, []} ->
          :mnesia.abort(%DoesNotExist{struct: Change, id: pid})
      end
    end)
  end

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

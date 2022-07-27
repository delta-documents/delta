defmodule Delta.Change do
  use Delta.Storage.RecordHelper

  defstruct [:id, :document_id, :previous_change_id, :order, kind: :update, path: [], value: %{}, meta: nil]

  use Delta.Storage.MnesiaHelper, struct: Delta.Change

  require Pathex

  alias Delta.{Document, Validators}
  alias Delta.Errors.{Validation}
  alias Delta.Path

  def new(id1 \\ nil, id2 \\ nil, kind \\ :update, p1 \\ [], v \\ nil, m \\ nil, id0 \\ UUID.uuid4()),
    do: %__MODULE__{id: id0, document_id: id1, previous_change_id: id2, kind: kind, path: p1, value: v, meta: m}

  def validate(%__MODULE__{id: id0, document_id: id1, previous_change_id: id2, kind: kind, path: p1, value: v, meta: m}) do
    with {:ok, id0} <- Validators.uuid(id0, %Validation{struct: __MODULE__, field: :id}),
         {:ok, id1} <- Validators.uuid(id1, %Validation{struct: __MODULE__, field: :document_id}),
         {:ok, id2} <- Validators.maybe_uuid(id2, %Validation{struct: __MODULE__, field: :previous_change_id}),
         {:ok, p1} <- Validators.path(p1, %Validation{struct: __MODULE__, field: :path}),
         {:ok, kind} <- Validators.kind(kind, %Validation{struct: __MODULE__, field: :kind}),
         {:cyclic, false} <- {:cyclic, id0 == id2} do
      {:ok, %__MODULE__{id: id0, document_id: id1, previous_change_id: id2, kind: kind, path: p1, value: v, meta: m}}
    else
      {:cyclic, true} -> {:error, %Validation{struct: __MODULE__, field: :previous_change_id, expected: "not to be equal to id", got: id0}}
      x -> x
    end
  end

  def validate(_), do: {:error, %Validation{struct: __MODULE__, expected: __MODULE__, got: "not an instance of"}}

  def list(%Document{id: cid}), do: list(cid)

  def list(did) do
    with {:document, [^did]} <- {:document, Document.id(did)} do
      # Erlang index is 1-based
      :mnesia.index_read(__MODULE__, did, 3)
      |> Enum.map(&from_record/1)
    else
      {:document, []} ->
        :mnesia.abort(%DoesNotExist{struct: Document, id: did})
    end
  end

  def list(from, to) do
    case maybe_id(to) do
      [to] -> do_list(from, to)
      _ -> []
    end
  end

  defp do_list(nil, _), do: []

  defp do_list(from, to) do
    case get(from) do
      [%{id: ^to} = c] -> [c]
      [%{previous_change_id: p} = c] -> [c | do_list(p, to)]
      [] -> []
    end
  end

  def history([from | _], to), do: list(from, to)

  def list_transaction(document), do: :mnesia.transaction(fn -> list(document) end)

  def list_transaction(from, to), do: :mnesia.transaction(fn -> list(from, to) end)

  def create(%{document_id: did, previous_change_id: pid} = m) do
    with {:validate, {:ok, m}} <- {:validate, validate(m)},
         {:exists, []} <- {:exists, get(m)},
         {:document, [%{id: ^did, change_count: count}]} <- {:document, Document.get(did)},
         {:previous, [^pid]} <- {:previous, maybe_id(pid)},
         m <- struct(m, %{order: count + 1}),
         :ok <- :mnesia.write(to_record(m)),
         Document.update(did, %{change_count: count + 1})do
      m
    else
      {:validate, {:error, err}} -> :mnesia.abort(err)
      {:document, []} -> :mnesia.abort(%DoesNotExist{struct: Document, id: did})
      {:previous, []} -> :mnesia.abort(%DoesNotExist{struct: Change, id: pid})
      {:exists, [_]} -> :mnesia.abort(%AlreadyExist{struct: __MODULE__, id: m.id})
    end
  end

  def write(%{document_id: did, previous_change_id: pid} = m) do
    with {:validate, {:ok, m}} <- {:validate, validate(m)},
         {:document, [^did]} <- {:document, Document.id(did)},
         {:previous, [^pid]} <- {:previous, maybe_id(pid)} do
      super(m)
    else
      {:validate, {:error, err}} -> :mnesia.abort(err)
      {:document, []} -> :mnesia.abort(%DoesNotExist{struct: Document, id: did})
      {:previous, []} -> :mnesia.abort(%DoesNotExist{struct: Change, id: pid})
    end
  end

  def apply_change(%Document{data: data} = d, %{id: id} = change) do
    with {:ok, applied} <- apply_change(data, change) do
      {:ok, struct(d, %{data: applied, latest_change_id: id})}
    end
  end

  def apply_change(data, %{kind: :update, path: p, value: v}), do: Pathex.force_set(data, Path.compile(p), v)

  def apply_change(data, %{kind: :delete, path: p, value: _}) do
    case Pathex.delete(data, Path.compile(p)) do
      {:ok, _} = ok -> ok
      _ -> {:ok, data}
    end
  end

  def apply_change(data, %{kind: :add, path: p, value: v}) do
    p = Path.compile(p)

    case Pathex.get(data, p, []) do
      list when is_list(list) -> Pathex.force_set(data, p, [v | list])
      _ -> Pathex.force_set(data, p, v)
    end
  end

  def apply_change(data, %{kind: :remove, path: p, value: v}) do
    p = Path.compile(p)

    case Pathex.view(data, p) do
      :error -> {:ok, data}
      {:ok, list} when is_list(list) -> Pathex.force_set(data, p, List.delete(list, v))
      {:ok, _} -> Pathex.delete(data, p)
    end
  end

  def homogenous([]), do: []

  def homogenous(changes) do
    root = root(changes)

    [root | changes |> List.delete(root) |> homogenous()]
  end

  def root?(%__MODULE__{previous_change_id: id}, changes), do: !Enum.any?(changes, fn %__MODULE__{id: id0} -> id0 == id end)

  def root(changes), do: Enum.find(changes, &root?(&1, changes))

  def roots(changes), do: Enum.filter(changes, &root?(&1, changes))
end

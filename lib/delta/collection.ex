defmodule Delta.Collection do
  use Delta.Storage.RecordHelper
  defstruct [:id, :name]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation}

  def new(name \\ "unnamed_collection", id \\ UUID.uuid4()) do
    %__MODULE__{id: id, name: name}
  end

  def validate(%__MODULE__{id: id, name: name}) do
    with {:ok, id} <- Delta.Validators.uuid(id, %Validation{struct: __MODULE__, field: :id}) do
      {:ok, %__MODULE__{id: id, name: name}}
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

  def get(m) do
    :mnesia.transaction(fn ->
      case MnesiaHelper.get(m) do
        [r] -> r
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

  defp validated_write(m) do
    case validate(m) do
      {:ok, m} -> MnesiaHelper.write(m)
      {:error, err} -> :mnesia.abort(err)
    end
  end

  def delete(m) do
    :mnesia.transaction(fn -> do_delete(m) end)
  end

  def do_delete(%__MODULE__{id: id}), do: do_delete(id)

  def do_delete(id) do
    # Erlang index is 1-based
    :mnesia.index_read(Delta.Document, id, 2)
    |> Enum.map(&Delta.Document.do_delete(elem(&1, 1)))

    MnesiaHelper.delete(id)
  end

  def collection_id(id) do
    case MnesiaHelper.get(id) do
      [%{id: id}] -> [id]
      x -> x
    end
  end
end

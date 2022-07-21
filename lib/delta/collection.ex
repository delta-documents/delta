defmodule Delta.Collection do
  use Delta.Storage.RecordHelper
  defstruct [:id, :name]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  alias Delta.Collection.MnesiaHelper

  def new(name \\ "unnamed_collection", id \\ UUID.uuid4()) do
    %__MODULE__{id: id, name: name}
  end

  def validate(%__MODULE__{id: id, name: name}) do
    with {:ok, id} <- Delta.Validators.uuid(id, "#{inspect(__MODULE__)}.id") do
      {:ok, %__MODULE__{id: id, name: name}}
    end
  end

  def validate(_), do: {:error, "Not an instance of #{inspect(__MODULE__)}"}

  def list do
    :mnesia.transaction(fn -> MnesiaHelper.list() end)
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

  def create(m) do
    :mnesia.transaction(fn ->
      with {:get, []} <- MnesiaHelper.get(m),
           {:validate, {:ok, m}} <- {:validate, validate(m)} do
        MnesiaHelper.write(m)
      else
        {:get, [_]} -> :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} does not exist")
        {:validate, {:error, err}} -> :mnesia.abort(err)
      end
    end)
  end

  def update(m) do
    :mnesia.transaction(fn ->
      with {:get, [_]} <- MnesiaHelper.get(m),
           {:validate, {:ok, m}} <- {:validate, validate(m)} do
        MnesiaHelper.write(m)
      else
        {:get, []} -> :mnesia.abort("#{inspect(__MODULE__)} with id = #{m.id} already exists")
        {:validate, {:error, err}} -> :mnesia.abort(err)
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

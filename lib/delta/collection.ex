defmodule Delta.Collection do
  use Delta.Storage.RecordHelper
  defstruct [:id, :name]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  alias Delta.Errors.Validation

  def new(name \\ "unnamed_collection", id \\ UUID.uuid4()), do: %__MODULE__{id: id, name: name}

  def validate(%__MODULE__{id: id, name: name}) do
    with {:ok, id} <- Delta.Validators.uuid(id, %Validation{struct: __MODULE__, field: :id}), do: {:ok, %__MODULE__{id: id, name: name}}
  end

  def validate(_), do: {:error, %Validation{struct: __MODULE__, expected: __MODULE__, got: "not an instance of"}}

  def write(m) do
    case validate(m) do
      {:ok, m} -> super(m)
      {:error, err} -> :mnesia.abort(err)
    end
  end

  def delete(m) do
    case id(m) do
      [id] ->
        :mnesia.index_read(Delta.Document, id, 3)
        |> Enum.map(&Delta.Document.delete(elem(&1, 1)))

        super(id)

      _ ->
        :ok
    end
  end
end

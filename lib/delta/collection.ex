defmodule Delta.Collection do
  defstruct [:id, :name]

  def new(name \\ "unnamed_collection", id \\ UUID.uuid4()) do
    %__MODULE__{id: id, name: name}
  end

  def validate(%__MODULE__{id: id, name: name}) do
    with {:ok, id} <- Delta.Validators.uuid(id, "#{__MODULE__}.id") do
      {:ok, %__MODULE__{id: id, name: name}}
    end
  end

  def validate(_), do: {:error, "Not an instance of #{__MODULE__}"}
end

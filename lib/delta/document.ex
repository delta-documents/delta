defmodule Delta.Document do
  defstruct [:id, :collection_id, :latest_change_id, data: %{}]

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
end

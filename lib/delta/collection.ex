defmodule Delta.Collection do
  defstruct [:id, :name]

  def list do
  end

  def get(%__MODULE__{id: id}), do: get(id)

  def get(id) do
  end

  def create(%__MODULE__{}) do
  end

  def update(%__MODULE__{}) do
  end

  def delete(%__MODULE__{}) do
  end

  def create_table do
    :mnesia.create_table(__MODULE__, attributes: [:id, :name], index: [:id, :name], disc_copies: [])
  end
end

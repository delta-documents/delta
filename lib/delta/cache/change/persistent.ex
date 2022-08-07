defmodule Delta.Cache.Change.Persistent do
  @changes []

  def init(), do: nil

  def bulk_write(records), do: {:ok, records} |> IO.inspect()

  def bulk_read(), do: @changes

  def bulk_read(ids), do: @changes |> Enum.filter(fn x -> x in ids end)
end

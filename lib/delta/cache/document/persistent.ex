defmodule Delta.Cache.Document.Persistent do
  @document []

  def init(), do: nil

  def bulk_write(id, document), do: {:ok, document} |> IO.inspect()

  def bulk_read(id), do: @document
end

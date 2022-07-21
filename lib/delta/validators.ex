defmodule Delta.Validators do
  def uuid(id, ctx) do
    case UUID.info(id) do
      {:ok, [uuid: u, binary: _, type: :default, version: 4, variant: _]} ->
        {:ok, u}

      {:ok, [uuid: _, binary: _, type: t, version: 4, variant: _]} ->
        {:error, "#{ctx}: Expected UUID #{id} to be of type default, got UUID of type #{t}"}

      {:ok, [uuid: _, binary: _, type: _, version: v, variant: _]} ->
        {:error, "#{ctx}: Expected UUID #{id} to be UUIDv4, got v#{v}"}

      {:error, "Invalid argument; Expected: String"} ->
        {:error, "#{ctx}: Invalid argument; Expected: UUID, got #{inspect(id)}"}

      {:error, err} ->
        {:error, ctx <> ": " <> err}
    end
  end

  def maybe_uuid(nil, _), do: {:ok, nil}
  def maybe_uuid(id, ctx), do: uuid(id, ctx)

  def map(%{} = map, _), do: {:ok, map}
  def map(map, ctx), do: {:error, "Expected #{ctx} to be a map, got #{inspect(map)}"}

  def path(p, ctx) do
    if Enum.all?(p, fn x -> is_bitstring(x) or is_integer(x) end) and is_list(ctx) do
      {:ok, p}
    else
      {:error, "Expected #{ctx} to be a list of strings or ints, got #{inspect(p)}"}
    end
  end

  def kind(kind, _) when kind in [:add, :update, :remove, :delete], do: {:ok, kind}
  def kind(kind, ctx), do: {:error, "Expected #{ctx} to be :add, update, remove, or delete, got #{kind}"}
end

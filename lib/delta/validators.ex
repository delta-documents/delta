defmodule Delta.Validators do
  def uuid(id, err) do
    case UUID.info(id) do
      {:ok, [uuid: u, binary: _, type: :default, version: 4, variant: _]} ->
        {:ok, u}

      {:ok, [uuid: _, binary: _, type: t, version: 4, variant: _]} ->
        {:error, Map.merge(err, %{expected: "default UUID", got: "UUID of type #{t}"})}

      {:ok, [uuid: _, binary: _, type: _, version: v, variant: _]} ->
        {:error, Map.merge(err, %{expected: "UUIDv4", got: "UUIDv#{v}"})}

      {:error, "Invalid argument; Expected: String"} ->
        {:error, Map.merge(err, %{expected: "UUID", got: "#{inspect(id)}"})}

      {:error, err} ->
        {:error, Map.merge(err, %{expected: "UUID", got: err})}
    end
  end

  def maybe_uuid(nil, _), do: {:ok, nil}
  def maybe_uuid(id, ctx), do: uuid(id, ctx)

  def map(%{} = map, _), do: {:ok, map}
  def map(map, err), do: {:error, Map.merge(err, %{expected: "a map", got: "#{inspect(map)}"})}

  def path(p, err) do
    if Enum.all?(p, fn x -> is_bitstring(x) or is_integer(x) end) and is_list(err) do
      {:ok, p}
    else
      {:error, Map.merge(err, %{expected: "a list of strings or integers", got: "inspect(p)"})}
    end
  end

  @kinds [:add, :update, :remove, :delete]

  def kind(kind, _) when kind in @kinds, do: {:ok, kind}
  def kind(kind, err), do: {:error, Map.merge(err, %{expected: "to be in #{inspect(@kinds)}", got: "#{inspect(kind)}"})}
end

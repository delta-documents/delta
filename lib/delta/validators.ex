defmodule Delta.Validators do
  alias Delta.Errors.Validation

  @spec uuid4(Delta.uuid4() | any(), Validation.t()) :: :ok | {:error, Validation.t()}
  def uuid4(uuid, err \\ %Validation{}) do
    case UUID.info(uuid) do
      {:ok, [uuid: _, binary: _, type: :default, version: 4, variant: _]} ->
        :ok

      {:ok, [uuid: _, binary: _, type: t, version: 4, variant: _]} ->
        {:error, struct(err, expected: "default UUID", got: "UUID of type #{t}")}

      {:ok, [uuid: _, binary: _, type: _, version: v, variant: _]} ->
        {:error, struct(err, expected: "UUIDv4", got: "UUIDv#{v}")}

      {:error, "Invalid argument; Expected: String"} ->
        {:error, struct(err, expected: "UUID", got: "#{inspect(uuid)}")}

      {:error, e} ->
        {:error, struct(err, expected: "UUID", got: e)}
    end
  end

  @spec maybe_uuid4(Delta.uuid4() | nil | any(), Validation.t()) ::
          :ok | {:error, Delta.Errors.Validation.t()}
  def maybe_uuid4(uuid, err \\ %Validation{})
  def maybe_uuid4(nil, _), do: :ok
  def maybe_uuid4(uuid, err), do: uuid4(uuid, err)

  @spec json_patch(Delta.Json.Patch.t() | any(), Validation.t()) ::
          :ok | {:error, Delta.Errors.Validation.t()}
  def json_patch(patch, err \\ %Validation{})

  def json_patch(patch, err) when is_list(patch),
    do: Enum.find_value(patch, :ok, &json_patch_op(&1, err))

  def json_patch(patch, err),
    do: {:error, struct(err, expected: "list of operations", got: patch)}

  @spec json_patch_op(Delta.Json.Patch.operation() | any(), Validation.t()) ::
          :ok | {:error, Delta.Errors.Validation.t()}
  def json_patch_op(operation, err \\ %Validation{})

  def json_patch_op({:add, p, _}, err), do: json_pointer(p, err)
  def json_patch_op({:remove, p}, err), do: json_pointer(p, err)
  def json_patch_op({:move, p1, p2}, err), do: two_json_pointers(p1, p2, err)
  def json_patch_op({:copy, p1, p2}, err), do: two_json_pointers(p1, p2, err)

  def json_patch_op(operation, err),
    do: {:error, struct(err, expected: "valid operation", got: operation)}

  def json_pointer(pointer, err \\ %Validation{}) do
    if Enum.all?(pointer, &(is_bitstring(&1) or is_integer(&1))) do
      :ok
    else
      struct(err, expected: "JsonPointer to be list of strings or integers", got: pointer)
    end
  end

  defp two_json_pointers(p1, p2, err) do
    with :ok <- json_pointer(p1, err),
         :ok <- json_pointer(p2, err) do
      :ok
    end
  end
end

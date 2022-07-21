defmodule Delta.Change do
  use Delta.Storage.RecordHelper
  defstruct [:id, :document_id, :previous_change_id, :kind, :path, :compiled_path, :value, :meta]
  use Delta.Storage.MnesiaHelper, struct: Delta.Collection

  def new(
        id0 \\ UUID.uuid4(),
        id1 \\ nil,
        id2 \\ nil,
        kind \\ :update,
        p1 \\ [],
        p2 \\ nil,
        v \\ nil,
        m \\ nil
      ) do
    %__MODULE__{
      id: id0,
      document_id: id1,
      previous_change_id: id2,
      kind: kind,
      path: p1,
      compiled_path: p2,
      value: v,
      meta: m
    }
  end

  def compile(%__MODULE__{path: p} = m), do: Map.put(m, :compiled_path, Delta.Path.compile(p))

  def validate(%__MODULE__{
        id: id0,
        document_id: id1,
        previous_change_id: id2,
        kind: kind,
        path: p1,
        compiled_path: p2,
        value: v,
        meta: m
      }) do
    with {:ok, id0} <- Delta.Validators.uuid(id0, "#{__MODULE__}.id"),
         {:ok, id1} <- Delta.Validators.uuid(id1, "#{__MODULE__}.document_id"),
         {:ok, id2} <- Delta.Validators.maybe_uuid(id2, "#{__MODULE__}.previous_change_id"),
         {:ok, p1} <- Delta.Validators.path(p1, "#{__MODULE__}.path"),
         {:ok, kind} <- Delta.Validators.kind(kind, "#{__MODULE__}.kind") do
      {:ok,
       %__MODULE__{
         id: id0,
         document_id: id1,
         previous_change_id: id2,
         kind: kind,
         path: p1,
         compiled_path: p2,
         value: v,
         meta: m
       }}
    end
  end

  def maybe_change_id(nil), do: [nil]

  def maybe_change_id(id) do
    case MnesiaHelper.get(id) do
      [%{id: id}] -> [id]
      x -> x
    end
  end
end

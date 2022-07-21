defmodule Delta.Storage.RecordHelper do
  defmacro __using__(_) do
    quote do
      import Kernel, except: [defstruct: 1]
      require Delta.Storage.RecordHelper
      import Delta.Storage.RecordHelper, only: [defstruct: 1]
    end
  end

  defmacro defstruct(fields) do
    keys =
      Enum.map(fields, fn
        {k, _d} -> k
        k -> k
      end)

    quote do
      Kernel.defstruct(unquote(fields))

      # TODO: inline matching
      def to_record(%__MODULE__{} = m) do
        [__MODULE__ | Enum.map(unquote(keys), &Map.fetch!(m, &1))] |> List.to_tuple()
      end

      def from_record(record) do
        [__MODULE__ | fields] = Tuple.to_list(record)

        struct(__MODULE__, Enum.zip(unquote(keys), fields))
      end
    end
  end
end

defmodule Delta.Storage.MnesiaHelper do
  defmacro __using__(_) do
    quote do
      def list, do: foldl([], &[&1 | &2])

      def foldl(acc0, fun) do
        :mnesia.transaction(fn ->
          :mnesia.foldl(fn r, acc -> fun.(from_record(r), acc) end, acc0, __MODULE__)
        end)
      end

      def foldr(acc0, fun) do
        :mnesia.transaction(fn ->
          :mnesia.foldr(fn r, acc -> fun.(from_record(r), acc) end, acc0, __MODULE__)
        end)
      end

      def get(%__MODULE__{id: id}), do: get(id)

      def get(id) do
        :mnesia.transaction(fn ->
          [r] = :mnesia.read(__MODULE__, id)
          from_record(r)
        end)
      end

      def write(%__MODULE__{} = m) do
        :mnesia.transaction(fn -> :mnesia.write(to_record(m)) end)
      end

      def delete(%__MODULE__{id: id}) do
        :mnesia.transaction(fn -> :mnesia.delete({__MODULE__, id}) end)
      end

      defoverridable([list: 0, foldl: 2, foldr: 2, get: 1, write: 1, delete: 1])
    end
  end

  defmacro deftable(mod, fields) do
    quote do
      defmodule unquote(mod) do
        require Delta.Storage.RecordHelper
        Delta.Storage.RecordHelper.defstruct(unquote(fields))
        use Delta.Storage.MnesiaHelper
      end
    end
  end
end

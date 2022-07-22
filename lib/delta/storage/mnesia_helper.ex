defmodule Delta.Storage.MnesiaHelper do
  defmacro __using__(struct: struct) do
      quote do
        defmodule MnesiaHelper do
        def list, do: foldl([], &[&1 | &2])

        def foldl(acc0, fun) do
          :mnesia.foldl(
            fn r, acc -> fun.(unquote(struct).from_record(r), acc) end,
            acc0,
            unquote(struct)
          )
        end

        def foldr(acc0, fun) do
          :mnesia.foldr(
            fn r, acc -> fun.(unquote(struct).from_record(r), acc) end,
            acc0,
            unquote(struct)
          )
        end

        def get(%unquote(struct){id: id}), do: get(id)

        def get(id) do
          :mnesia.read(unquote(struct), id)
          |> Enum.map(&unquote(struct).from_record(&1))
        end

        def write(%unquote(struct){} = m) do
          :mnesia.write(unquote(struct).to_record(m))
        end

        def delete(%unquote(struct){id: id}) do
          :mnesia.delete({unquote(struct), id})
        end

        def delete(id) do
          :mnesia.delete({unquote(struct), id})
        end

        defoverridable(list: 0, foldl: 2, foldr: 2, get: 1, write: 1, delete: 1)
      end

      alias __MODULE__.MnesiaHelper
    end
  end
end

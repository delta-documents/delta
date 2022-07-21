defmodule Delta.Storage.MnesiaHelper do
  defmacro __using__(struct: struct) do
      quote do
        defmodule MnesiaHelper do
        def list, do: foldl([], &[&1 | &2])

        def foldl(acc0, fun) do
          :mnesia.foldl(
            fn r, acc -> fun.(unquote(struct).from_record(r), acc) end,
            acc0,
            __MODULE__
          )
        end

        def foldr(acc0, fun) do
          :mnesia.foldr(
            fn r, acc -> fun.(unquote(struct).from_record(r), acc) end,
            acc0,
            __MODULE__
          )
        end

        def get(%unquote(struct){id: id}), do: get(id)

        def get(id) do
          [r] = :mnesia.read(unquote(struct), id)
          unquote(struct).from_record(r)
        end

        def write(%unquote(struct){} = m) do
          :mnesia.write(unquote(struct).to_record(m))
        end

        def delete(%unquote(struct){id: id}) do
          :mnesia.delete({unquote(struct), id})
        end

        defoverridable(list: 0, foldl: 2, foldr: 2, get: 1, write: 1, delete: 1)
      end
    end
  end
end

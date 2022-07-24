defmodule Delta.Storage.MnesiaHelper do
  defmacro __using__(struct: struct) do
    quote do
      # Inside transaction

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

      def create(m) do
        case get(m) do
          [] -> write(m)
          [_] -> :mnesia.abort(%AlreadyExist{struct: __MODULE__, id: m})
        end
      end

      def update(m, attrs \\ %{}) do
        case get(m) do
          [m] -> write(struct(m, attrs))
          [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: m})
        end
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

      def id(id) do
        case get(id) do
          [%{id: id}] -> [id]
          x -> x
        end
      end

      def maybe_id(nil), do: nil
      def maybe_id(id), do: id(id)

      alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation}

      # Transactions

      def list_transaction, do: :mnesia.transaction(fn -> list() end)

      def get_transaction(m) do
        :mnesia.transaction(fn ->
          case get(m) do
            [r] -> r
            [] -> :mnesia.abort(%DoesNotExist{struct: __MODULE__, id: m})
          end
        end)
      end

      def create_transaction(m), do: :mnesia.transaction(fn -> create(m) end)

      def update_transaction(m, attrs \\ %{}), do: :mnesia.transaction(fn -> update(m, attrs) end)

      def write_transaction(m), do: :mnesia.transaction(fn -> write(m) end)

      def delete_transaction(m), do: :mnesia.transaction(fn -> delete(m) end)

      defoverridable(
        list: 0,
        foldl: 2,
        foldr: 2,
        get: 1,
        write: 1,
        delete: 1,
        id: 1,
        maybe_id: 1,
        list_transaction: 0,
        get_transaction: 1,
        create_transaction: 1,
        update_transaction: 1,
        update_transaction: 2,
        delete_transaction: 1
      )
    end
  end
end

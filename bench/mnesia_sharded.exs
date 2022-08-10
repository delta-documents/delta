defmodule MnesiaShardedBench do
  def write({key1, key2, value}) do
    {:atomic, _} =
      :mnesia.transaction(fn->
        :mnesia.write({:large, {key1, key2}, key1, value})
      end)
  end

  def write_sharded({1, key2, value}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :mnesia.write({:sharded_1, key2, value})
      end)
  end

  def write_sharded({2, key2, value}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :mnesia.write({:sharded_2, key2, value})
      end)
  end

  def lookup({key1, key2}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :mnesia.read({:large, {key1, key2}})
      end)
  end

  def lookup_sharded({1, key2}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :mnesia.read({:sharded_1, key2})
      end)
  end

  def lookup_sharded({2, key2}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :mnesia.read({:sharded_2, key2})
      end)
  end

  def first({key1, _}) do
    {:atomic, _} =
      :mnesia.transaction(fn ->
        :large
        |> :mnesia.index_read(key1, :prefix)
        |> hd()
        |> elem(1)
      end)
  end

  def first_sharded({1, _}), do: {:atomic, _} = :mnesia.transaction(fn -> {1, :mnesia.first(:sharded_1)} end)
  def first_sharded({2, _}), do: {:atomic, _} = :mnesia.transaction(fn -> {1, :mnesia.first(:sharded_2)} end)
end

:mnesia.stop()
:mnesia.create_schema([node()])
:mnesia.start()

:mnesia.create_table(:large, attributes: [:key, :prefix, :value], index: [:prefix], type: :ordered_set, ram_copies: [node()])
:mnesia.create_table(:sharded_1, attributes: [:key, :value], type: :ordered_set, ram_copies: [node()])
:mnesia.create_table(:sharded_2, attributes: [:key, :value], type: :ordered_set, ram_copies: [node()])

data = [
  {1, 1, :crypto.strong_rand_bytes(1024)},
  {1, 2, :crypto.strong_rand_bytes(1024)},
  {1, 3, :crypto.strong_rand_bytes(1024)},
  {1, 4, :crypto.strong_rand_bytes(1024)},
  {1, 5, :crypto.strong_rand_bytes(1024)},
  {2, 1, :crypto.strong_rand_bytes(1024)},
  {2, 2, :crypto.strong_rand_bytes(1024)},
  {2, 3, :crypto.strong_rand_bytes(1024)},
  {2, 4, :crypto.strong_rand_bytes(1024)},
  {2, 5, :crypto.strong_rand_bytes(1024)},
]

keys = Enum.map(data, fn {k1, k2, _v} -> {k1, k2} end)

opts = [
  warmup: 0,
  time: 5,
  memory_time: 5,
  reduction_time: 5,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/mnesia_sharded.html"},
    {Benchee.Formatters.Console, extended_statistics: true}
  ]
]

Benchee.run(
  %{
    "write" => fn input -> Enum.map(input, &MnesiaShardedBench.write/1) end,
    "write_sharded" => fn input -> Enum.map(input, &MnesiaShardedBench.write_sharded/1) end
  },
  opts ++ [inputs: %{"data" => data}]
)

Benchee.run(
  %{
    "lookup" => fn input -> Enum.map(input, &MnesiaShardedBench.lookup/1) end,
    "lookup_sharded" => fn input -> Enum.map(input, &MnesiaShardedBench.lookup_sharded/1) end,
    "first" => fn input -> Enum.map(input, &MnesiaShardedBench.first/1) end,
    "first_sharded" => fn input -> Enum.map(input, &MnesiaShardedBench.first_sharded/1) end
  },
  opts ++ [inputs: %{"keys" => keys}]
)

:mnesia.stop()
File.rm_rf(Application.get_env(:mnesia, :dir))

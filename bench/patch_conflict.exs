defmodule PatchConflictBench do
  def conflict_paths?(patch1, patch2) do
    for {p1, _} <- patch1, {p2, _} <- patch2, reduce: false do
      acc -> acc or overlap?(p1, p2)
    end
  end

  def overlap?(p1, p2), do: List.starts_with?(p1, p2) or List.starts_with?(p2, p1)

  def conflict_unwrapped?(patch1, patch2) do
    u1 = unwrap(patch1) |> MapSet.new(&elem(&1, 0))
    u2 = unwrap(patch2) |> MapSet.new(&elem(&1, 0))

    (MapSet.intersection(u1, u2) |> MapSet.size()) > 0
  end

  def unwrap([]), do: []
  def unwrap([{path, %{} = value} | rest]), do: Enum.map(value, fn {k, v} -> {path ++ [k], v} end) ++ rest |> unwrap()
  def unwrap([{path, value} | rest]) when is_list(value), do: Enum.with_index(value, fn e, i -> {path ++ [i], e} end) ++ rest |> unwrap()
  def unwrap([{path, value} | rest]), do: [{path, value} | unwrap(rest)]

  def gen_linear(d), do: Enum.map(d, &{[&1], &1})

  def gen_nested([]), do: []
  def gen_nested([k | rest]) do
    [{[k], rest |> Enum.reverse() |> Enum.reduce(%{}, &Map.put(%{}, &1, &2))} | gen_nested(rest)]
  end

  def gen(d, fun), do: do_gen([nil | d], fun)

  defp do_gen([_ | rest], fun), do: [fun.(rest) | do_gen(rest, fun)]
  defp do_gen([], _), do: []
end

atoms = [:a, :b, :c, :d, :e, :f, :g, :k, :l, :m]
linear = PatchConflictBench.gen(atoms, &PatchConflictBench.gen_linear/1)
nested = PatchConflictBench.gen(atoms, &PatchConflictBench.gen_nested/1)

opts = [
  warmup: 0,
  time: 5,
  memory_time: 5,
  reduction_time: 5,
  formatters: [
    {Benchee.Formatters.HTML, file: "bench/output/patch_conflict.html"},
    {Benchee.Formatters.Console, extended_statistics: true}
  ]
]

Benchee.run(
  %{
    "conflict_paths?" => fn input -> Enum.map(input, &PatchConflictBench.conflict_paths?(&1, &1)) end,
    "conflict_unwrapped?" => fn input -> Enum.map(input, &PatchConflictBench.conflict_unwrapped?(&1, &1)) end
  },
  opts ++ [inputs: %{"linear" => linear, "nested" => nested}]
)

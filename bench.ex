defmodule MnesiaBench do
  def one_document(uuid, nwrites \\ 100, data_size \\ 1024 * 1024) do
    tab = String.to_atom(uuid)
    {t1, _} = :timer.tc fn -> :mnesia.create_table(tab, attributes: [:key, :value], disc_only_copies: [node()], ram_copies: [], storage_properties: [dets: [max_no_slots: ]]) end

    total_time =
      1..nwrites
      |> Enum.map(fn key -> {key, :crypto.strong_rand_bytes(data_size)} end)
      |> Enum.map(fn {key, data} ->
        (fn -> :mnesia.transaction(fn -> :mnesia.write({tab, key, data}) end) end)
        |> :timer.tc()
        |> elem(0)
      end)
      |> Enum.sum()

    {t1 / 1000, total_time / nwrites / 1000, :erlang.memory[:total] / 1024 / 1024}
  end

  def documents(ndocs, nwrites \\ 100, data_size \\ 1024 * 1024) do
    each = Enum.map(1..ndocs, fn _ -> one_document(UUID.uuid4(), nwrites, data_size) end)

    total = Enum.reduce(each, {0, 0, 0}, fn {a, b, c}, {d, e, f} -> {a + d, b + e, c + f} end)

    {total, each}
  end
end

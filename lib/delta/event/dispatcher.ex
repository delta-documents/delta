defmodule Delta.Event.Dispatcher do
  def dispatch(entries, from, message) do
    entries
    |> Enum.each(fn
      {^from, _} -> nil
      {pid, meta} -> if match_metadata?(message, meta), do: send(pid, message)
    end)

    :ok
  end

  def match_metadata?(_, nil), do: true
  def match_metadata?(_, :everything), do: true

  def match_metadata?(%Delta.Event{value: w}, m) do
    Enum.all?(m, fn {k, v} -> Map.get(w, k) == v end)
  end
end

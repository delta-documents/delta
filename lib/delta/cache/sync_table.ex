defmodule Delta.Cache.SyncTable do
  def init(nodes \\ [node()]) do
    :mnesia.create_table(__MODULE__, attributes: [:id, :synced_at], disc_copies: nodes)
  end

  def mark_synced(id) do
    :mnesia.write({__MODULE__, id, Delta.DateTimeHelper.now()})
  end

  def when_synced(id) do
    case :mnesia.read(__MODULE__, id) do
      [{_, _, time}] -> time
      _ -> :never
    end
  end
end

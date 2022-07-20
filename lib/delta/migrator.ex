defmodule Delta.Migrator do
  def migrate(nodes \\ [node()]) do
    :ok = :mnesia.create_schema(nodes)
    :rpc.multicall(nodes, Application, :start, [:mnesia])

    :mnesia.create_table(Delta.Collection, attributes: [:id, :name], index: [:id, :name], disc_copies: nodes)
    :mnesia.create_table(Delta.Document, attributes: [:id, :collection_id, :latest_change_id, :data], index: [:id, :collection_id, :latest_change_id], disc_copies: nodes)
    :mnesia.create_table(Delta.Change, attributes: [:id, :document_id, :previous_change_id, ], index: [:id, :name], disc_copies: nodes)

    :rpc.multicall(nodes, Application, :start, [:mnesia])
  end
end

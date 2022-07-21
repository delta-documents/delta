defmodule Delta.Storage do
  def migrate(nodes \\ [node()]) do
    :rpc.multicall(nodes, Application, :stop, [:mnesia])

    :mnesia.create_schema(nodes)

    :rpc.multicall(nodes, Application, :start, [:mnesia])

    :mnesia.create_table(Delta.Storage.Collection,
      attributes: [:id, :name],
      index: [:name],
      disc_copies: nodes
    )

    :mnesia.create_table(Delta.Storage.Document,
      attributes: [:id, :collection_id, :latest_change_id, :data],
      index: [:collection_id, :latest_change_id],
      disc_copies: nodes
    )

    :mnesia.create_table(Delta.Storage.Change,
      attributes:  [:id, :document_id, :previous_change_id, :kind, :path, :compiled_path, :value, :meta],
      index: [:document_id, :previous_change_id, :kind, :path],
      disc_copies: nodes
    )
  end
end

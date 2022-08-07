defmodule Delta.Storage do

  @type t :: module()

  def migrate(nodes \\ [node()]) do
    :rpc.multicall(nodes, Application, :stop, [:mnesia])

    :mnesia.create_schema(nodes)

    :rpc.multicall(nodes, Application, :start, [:mnesia])

    :mnesia.create_table(Delta.Collection,
      attributes: [:id, :name],
      index: [:name],
      disc_copies: nodes
    )

    :mnesia.create_table(Delta.Document,
      attributes: [:id, :collection_id, :latest_change_id, :change_count, :data],
      index: [:collection_id, :latest_change_id],
      disc_copies: nodes
    )

    :mnesia.create_table(Delta.Change,
      attributes: [:id, :document_id, :previous_change_id, :order, :kind, :path, :value, :meta],
      index: [:document_id, :previous_change_id, :order, :kind, :path],
      disc_copies: nodes
    )
  end
end

defmodule Delta.Storage do
  require Delta.Storage.MnesiaHelper
  import Delta.Storage.MnesiaHelper

  deftable(Collection, [:id, :name])
  deftable(Document, [:id, :collection_id, :latest_change_id, :data])
  deftable(Change, [:id, :document_id, :previous_change_id, :change])

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
      attributes: [:id, :document_id, :previous_change_id, :change],
      index: [:document_id, :previous_change_id],
      disc_copies: nodes
    )
  end
end

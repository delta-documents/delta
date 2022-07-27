defmodule Fixtures do
  alias Delta.{Collection, Document, Change}

  @collection %Delta.Collection{
    id: "3c9ef09f-1091-4a02-a01b-58a51da213e9",
    name: "collection"
  }

  @document %Delta.Document{
    id: "2983791f-9e7a-41f0-ac34-7c79025a14cb",
    collection_id: @collection.id,
    latest_change_id: nil,
    data: %{}
  }

  @change %Delta.Change{
    id: "f1e95048-f1a8-4635-bb3e-0246b266d5d6",
    document_id: @document.id,
    previous_change_id: nil,
    kind: :update,
    path: [],
    value: %{},
    meta: nil
  }

  def document, do: @document
  def collection, do: @collection
  def change, do: @change

  def create_document, do: Document.create_transaction(@document)
  def create_collection, do: Collection.create_transaction(@collection)
  def create_change, do: Change.create_transaction(@change)
end

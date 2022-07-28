defmodule Delta do
  alias Delta.{Collection, Document}

  def get_collection(collection), do: Collection.get_transaction(collection)
  def list_collection(), do: Collection.list_transaction()
  def create_collection(collection), do: Collection.create_transaction(collection)
  def update_collection(collection, attrs \\ %{}), do: Collection.update_transaction(collection, attrs)
  def delete_collection(collection), do: Collection.delete_transaction(collection)

  def get_document(document), do: Document.get_transaction(document)
  def list_document(collection), do: Document.list_transaction(collection)
  def create_document(document), do: Document.create_transaction(document)
  def update_document(document, attrs \\ %{}), do: Document.update_transaction(document, attrs)
  def delete_document(document), do: Document.delete_transaction(document)

  def add_changes_to_document(document, changes), do: Document.add_changes(document, changes)

  # def subscribe_document(%Delta.Document{id: id}), do: subscribe_document(id)
  # def subscribe_document(document_id), do: Delta.Event.subscribe("#{Delta.Document}", %{id: document_id})

  # def subscribe_documents(%Delta.Collection{id: id}), do: subscribe_documents(id)
  # def subscribe_documents(collection_id), do: Delta.Event.subscribe("#{Delta.Document}", %{collection_id: collection_id})

  def subscribe_document_changes(%Delta.Document{id: id}), do: subscribe_document_changes(id)
  def subscribe_document_changes(document_id), do: Phoenix.PubSub.subscribe(Delta.Event.PubSub, document_id)
end

defmodule DeltaTest.DocumentTest do
  use DeltaTest.Case

  import Fixtures

  alias Delta.Document

  test "Delta.Document.validate/1" do
    assert {:ok, _} = document() |> Document.validate()

    assert {:error, _} = %Document{id: "not_a_uuid"} |> Document.validate()
    assert {:error, _} = %Document{id: UUID.uuid4(), collection_id: nil} |> Document.validate()

    assert {:error, _} = %Document{id: UUID.uuid4(), collection_id: UUID.uuid4(), data: nil} |> Document.validate()

    assert {:error, _} = "not_a_document" |> Document.validate()
  end

  test "Delta.Document.new/4 generates unique and correct uuid" do
    d1 = %{id: id1} = Document.new(%{}, UUID.uuid4())
    d2 = %{id: id2} = Document.new(%{}, UUID.uuid4())

    assert id1 != id2
    assert {:ok, _} = Document.validate(d1)
    assert {:ok, _} = Document.validate(d2)
  end

  test "Delta.Document.get/1" do
    d = document()

    assert {:aborted, _} = Document.get_transaction(d)

    create_collection()
    create_document()

    assert {:atomic, ^d} = Document.get_transaction(d.id)
    assert {:atomic, ^d} = Document.get_transaction(d)
  end

  test "Delta.Document.list/0" do
    d = document()

    assert {:atomic, []} = Document.list_transaction()

    create_collection()
    create_document()

    assert {:atomic, [^d]} = Document.list_transaction()
  end

  test "Delta.Document.list/1 lists documents in collection" do
    c = collection()
    d = document()

    assert {:aborted, _} = Document.list_transaction(c)

    create_collection()

    assert {:atomic, []} = Document.list_transaction(c)

    create_document()

    assert {:atomic, [^d]} = Document.list_transaction(c)
    assert {:atomic, [^d]} = Document.list_transaction(c.id)
  end

  test "Delta.Document.create/1 creates document if one does not exist" do
    d = document()
    create_collection()

    assert {:atomic, ^d} = Document.create_transaction(d)
    assert {:aborted, _} = Document.create_transaction(d)
  end

  test "Delta.Document.create/1 of invalid document aborts transaction" do
    assert {:aborted, _} = Document.create_transaction(%Document{id: 123})

    assert {:aborted, _} = Document.create_transaction(%Document{id: UUID.uuid4(), collection_id: UUID.uuid4()})

    create_collection()

    assert {:aborted, _} = Document.create_transaction(%Document{id: UUID.uuid4(), collection_id: collection().id, latest_change_id: UUID.uuid4()})
  end

  test "Delta.Document.update/2 updates collection if one exists" do
    d = document()

    assert {:aborted, _} = Document.update_transaction(d, %{data: %{a: :b}})

    create_collection()
    create_document()

    assert {:atomic, _} = Document.update_transaction(d, %{data: %{a: :b}})
  end

  test "Delta.Document.delete/1 deletes changes cascade" do
    {:atomic, c} = create_collection()
    {:atomic, d} = create_document()
    {:atomic, m} = create_change()

    assert {:atomic, :ok} = Document.delete_transaction(d)

    assert {:atomic, _} = Delta.Collection.get_transaction(c)
    assert {:aborted, _} = Document.get_transaction(d)
    assert {:aborted, _} = Delta.Change.get_transaction(m)
  end

  test "Delta.Document.delete/1 of non-existing document is :ok" do
    assert {:atomic, :ok} = Document.delete_transaction("123")
  end

  test "Document.add_changes/2 aborts if document exists or changes are invalid" do
    c = change()
    d = document()

    assert {:aborted, _} = Document.add_changes_transaction(d, c)

    create_collection()
    create_document()

    assert {:aborted, _} = Document.add_changes_transaction(d, %Delta.Change{})
    assert {:aborted, _} = Document.add_changes_transaction(d, Map.put(c, :document_id, UUID.uuid4()))
  end

  test "Document.add_changes/2 adds valid changes" do
    create_collection()
    create_document()

    assert {:atomic, [change()]} == Document.add_changes_transaction(document(), change())
  end

  test "Document.add_changes/2 aborts in conflict is unresolvable" do
    create_collection()
    create_document()

    id1 = UUID.uuid4()
    id2 = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, %{id: id1, previous_change_id: c0.id})
    c2 = struct(c0, %{id: id2, previous_change_id: c0.id})

    assert {:aborted, %Delta.Errors.Conflict{}} = Document.add_changes_transaction(document(), [c0, c1, c2])
  end

  test "Document.add_changes/2 resolves conflicts" do
    create_collection()
    create_document()

    id1 = UUID.uuid4()
    id2 = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, %{id: id1, path: ["a"]})
    c2 = struct(c0, %{id: id2, path: ["b"]})

    assert {:atomic, [c1, Map.put(c2, :previous_change_id, c1.id)]} == Document.add_changes_transaction(document(), [c1, c2])
  end
end

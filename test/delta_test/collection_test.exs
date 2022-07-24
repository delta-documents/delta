defmodule DeltaTest.CollectionTest do
  use DeltaTest.Case
  doctest Delta.Collection

  import Fixtures

  alias Delta.Collection

  test "Collection.validate/1" do
    assert {:ok, _} = collection() |> Collection.validate()
    assert {:error, _} = %Collection{id: "not_an_uuid"} |> Collection.validate()
    assert {:error, _} = "not a collection" |> Collection.validate()
  end

  test "Collection.new/2 generates unique and correct uuid" do
    c1 = %{id: id1} = Collection.new()
    c2 = %{id: id2} = Collection.new()

    assert id1 != id2
    assert {:ok, ^c1} = Collection.validate(c1)
    assert {:ok, ^c2} = Collection.validate(c2)
  end

  test "Collection.get/1" do
    c = collection()

    assert {:aborted, _} = Collection.get_transaction(c)

    create_collection()

    assert {:atomic, ^c} = Collection.get_transaction(c.id)
    assert {:atomic, ^c} = Collection.get_transaction(c)
  end

  test "Collection.list/0" do
    c = collection()

    assert {:atomic, []} = Collection.list_transaction()

    create_collection()

    assert {:atomic, [^c]} = Collection.list_transaction()
  end

  test "Collection.create/1 creates collection if one does not exist" do
    c = collection()
    assert {:atomic, ^c} = Collection.create_transaction(c)
    assert {:aborted, _} = Collection.create_transaction(c)
  end

  test "Collection.create/1 of invalid collection aborts transaction" do
    assert {:aborted, _} = Collection.create_transaction(%Collection{id: 123})
  end

  test "Collection.update/2 updates collection if one exists" do
    c = collection()

    assert {:aborted, _} = Collection.update_transaction(c, %{name: 123})

    create_collection()

    assert {:atomic, _} = Collection.update_transaction(c, %{name: 123})
  end

  test "Collection.delete/1 deletes documents and changes cascade" do
    {:atomic, c} = create_collection()
    {:atomic, d} = create_document()
    {:atomic, m} = create_change()

    assert {:atomic, :ok} = Collection.delete_transaction(c)

    assert {:aborted, _} = Collection.get_transaction(c)
    assert {:aborted, _} = Delta.Document.get_transaction(d)
    assert {:aborted, _} = Delta.Change.get_transaction(m)
  end

  test "Collection.delete/1 of non-existing collection is :ok" do
    assert {:atomic, :ok} = Collection.delete_transaction("123")
  end
end

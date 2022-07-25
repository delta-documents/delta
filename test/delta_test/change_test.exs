defmodule DeltaTest.ChangeTest do
  use DeltaTest.Case

  import Fixtures

  alias Delta.Change

  defp create() do
    create_collection()
    create_document()
    create_change()
  end

  test "Delta.Change.validate/1" do
    assert {:ok, _} = change() |> Change.validate()

    assert {:error, _} = %Change{id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: UUID.uuid4(), document_id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: UUID.uuid4(), document_id: UUID.uuid4(), previous_change_id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: UUID.uuid4(), document_id: UUID.uuid4(), previous_change_id: UUID.uuid4(), kind: "error"} |> Change.validate()
    assert {:error, _} = %Change{id: UUID.uuid4(), document_id: UUID.uuid4(), previous_change_id: UUID.uuid4(), kind: :update, path: %{a: :b}} |> Change.validate()
    assert {:error, _} = "not a change" |> Change.validate()
  end

  test "Delta.Change.new/7 generates unique and correct uuid" do
    c1 = %{id: id1} = Change.new(UUID.uuid4())
    c2 = %{id: id2} = Change.new(UUID.uuid4())

    assert id1 != id2
    assert {:ok, _} = Change.validate(c1)
    assert {:ok, _} = Change.validate(c2)
  end

  test "Delta.Change.get/1" do
    c = change()

    assert {:aborted, _} = Change.get_transaction(c)

    create()

    assert {:atomic, ^c} = Change.get_transaction(c.id)
    assert {:atomic, ^c} = Change.get_transaction(c)
  end

  test "Delta.Change.list/0" do
    c = change()

    assert {:atomic, []} = Change.list_transaction()

    create()

    assert {:atomic, [^c]} = Change.list_transaction()
  end

  test "Delta.Change.list/1 lists changes of a document" do
    d = document()
    c = change()

    assert {:aborted, _} = Change.list_transaction(d)

    create_collection()
    create_document()

    assert {:atomic, []} = Change.list_transaction(d)

    create_change()

    assert {:atomic, [^c]} = Change.list_transaction(d.id)
    assert {:atomic, [^c]} = Change.list_transaction(d)
  end

  test "Delta.Change.list/2 lists changes from one to another" do
    create_collection()
    create_document()

    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()
    id = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, %{id: id1, previous_change_id: c0.id})
    c2 = struct(c0, %{id: id2, previous_change_id: c1.id})
    c3 = struct(c0, %{id: id3, previous_change_id: c2.id})
    c = struct(c0, %{id: id})

    assert {:aborted, _} = Change.list_transaction(id3, c0.id)

    assert {:atomic, _} = Change.create_transaction(c0)
    assert {:atomic, _} = Change.create_transaction(c1)
    assert {:atomic, _} = Change.create_transaction(c2)
    assert {:atomic, _} = Change.create_transaction(c3)
    assert {:atomic, _} = Change.create_transaction(c)

    assert {:aborted, _} = Change.list_transaction("not a change", nil)
    assert {:atomic, [c3, c2]} == Change.list_transaction(id3, c2.id)
    assert {:atomic, [c3, c2, c1, c0]} == Change.list_transaction(id3, c0.id)
    assert {:atomic, [c3, c2, c1, c0]} == Change.list_transaction(id3, nil)
  end

  test "Delta.Change.create/1 creates change if one does not exist" do
    c = change()

    create_collection()
    create_document()

    assert {:atomic, ^c} = Change.create_transaction(c)
    assert {:aborted, _} = Change.create_transaction(c)
  end

  test "Delta.Change.create/1 of invalid change aborts transaction" do
    assert {:aborted, _} = Change.create_transaction(%Change{id: 123})

    assert {:aborted, _} = Change.create_transaction(%Change{id: UUID.uuid4(), document_id: UUID.uuid4()})

    create_collection()
    create_document()

    assert {:aborted, _} = Change.create_transaction(%Change{id: UUID.uuid4(), document_id: document().id, previous_change_id: UUID.uuid4()})
  end

  test "Delta.Change.update/2 updates change if one exists" do
    c = change()

    assert {:aborted, _} = Change.update_transaction(c, %{a: :b})

    create()

    assert {:atomic, _} = Change.update_transaction(c, %{a: :b})
  end

  test "Delta.Change.delete/1 deletes chang" do
    create()

    assert {:atomic, :ok} = Change.delete_transaction(change())
  end

  test "Delta.Change.delete/1 of non-existing change is :ok" do
    assert {:atomic, :ok} = Change.delete_transaction("123")
  end

  test "Delta.Change.homogenous/1 returns homogenous lists of changes" do
    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()
    id = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, %{id: id1, previous_change_id: c0.id})
    c2 = struct(c0, %{id: id2, previous_change_id: c1.id})
    c3 = struct(c0, %{id: id3, previous_change_id: c2.id})
    c = struct(c0, %{id: id})

    assert [[c0, c1, c2, c3]] == Change.homogenous([c3, c2, c1, c0])
    assert [[c0, c1, c2, c3]] == Change.homogenous([c0, c1, c2, c3])
    assert [[c], [c0, c1, c2, c3]] == Change.homogenous([c, c0, c1, c2, c3])
  end
end

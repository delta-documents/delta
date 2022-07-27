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
    u = UUID.uuid4()

    assert {:ok, _} = change() |> Change.validate()

    assert {:error, _} = %Change{id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: u, document_id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: u, document_id: u, previous_change_id: "not_a_uuid"} |> Change.validate()
    assert {:error, _} = %Change{id: u, document_id: u, previous_change_id: UUID.uuid4(), kind: "error"} |> Change.validate()
    assert {:error, _} = %Change{id: u, document_id: u, previous_change_id: UUID.uuid4(), kind: :update, path: %{a: :b}} |> Change.validate()
    assert {:error, _} = %Change{id: u, document_id: u, previous_change_id: u, kind: :update, path: ["a", "b"]} |> Change.validate()
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
    c = struct(change(), order: 1)

    assert {:aborted, _} = Change.get_transaction(c)

    create()

    assert {:atomic, c} == Change.get_transaction(c.id)
    assert {:atomic, c} == Change.get_transaction(c)
  end

  test "Delta.Change.list/0" do
    c = struct(change(), order: 1)

    assert {:atomic, []} = Change.list_transaction()

    create()

    assert {:atomic, [c]} == Change.list_transaction()
  end

  test "Delta.Change.list/1 lists changes of a document" do
    d = document()
    c = struct(change(), order: 1)

    assert {:aborted, _} = Change.list_transaction(d)

    create_collection()
    create_document()

    assert {:atomic, []} = Change.list_transaction(d)

    create_change()

    assert {:atomic, [c]} == Change.list_transaction(d.id)
    assert {:atomic, [c]} == Change.list_transaction(d)
  end

  test "Delta.Change.list/2 lists changes from one to another" do
    create_collection()
    create_document()

    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()
    id = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, id: id1, previous_change_id: c0.id)
    c2 = struct(c0, id: id2, previous_change_id: c1.id)
    c3 = struct(c0, id: id3, previous_change_id: c2.id)
    c = struct(c0, id: id)

    assert {:atomic, []} = Change.list_transaction(id3, c0.id)

    assert {:atomic, c0} = Change.create_transaction(c0)
    assert {:atomic, c1} = Change.create_transaction(c1)
    assert {:atomic, c2} = Change.create_transaction(c2)
    assert {:atomic, c3} = Change.create_transaction(c3)
    assert {:atomic, _} = Change.create_transaction(c)

    assert {:atomic, []} = Change.list_transaction("not a change", nil)
    assert {:atomic, [c3, c2]} == Change.list_transaction(id3, c2.id)
    assert {:atomic, [c2, c3]} == Change.list_transaction(c2.id, id3)
    assert {:atomic, [c3, c2, c1, c0]} == Change.list_transaction(id3, c0.id)
    assert {:atomic, [c3, c2, c1, c0]} == Change.list_transaction(id3, nil)
  end

  test "Delta.Change.create/1 creates change if one does not exist" do
    c = change()

    create_collection()
    create_document()

    assert {:atomic, struct(c, order: 1)} == Change.create_transaction(c)
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

  test "Delta.Change.homogenous/1 returns homogenous list of changes" do
    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()
    id = UUID.uuid4()

    c0 = change()
    c1 = struct(c0, id: id1, previous_change_id: c0.id)
    c2 = struct(c0, id: id2, previous_change_id: c1.id)
    c3 = struct(c0, id: id3, previous_change_id: c2.id)
    c4 = struct(c0, id: id3, previous_change_id: c2.id)
    c = struct(c0, id: id)

    assert [c0, c1, c2, c3] == Change.homogenous([c3, c2, c1, c0])
    assert [c0, c1, c2, c3] == Change.homogenous([c0, c1, c2, c3])
    assert [c, c0, c1, c2, c3] == Change.homogenous([c, c0, c1, c2, c3])
    assert [c0, c1, c2, c3, c] == Change.homogenous([c0, c1, c2, c3, c])
    assert [c2, c3, c4] == Change.homogenous([c2, c3, c4])
    assert [c2, c4, c3] == Change.homogenous([c2, c4, c3])
  end

  test "Delta.Change.apply_change/2 applies change to any data" do
    data = %{a: %{b: 1}, b: 1}

    # Update
    assert {:ok, %{a: %{b: 1}, b: 1, c: 42}} == Change.apply_change(data, %Change{kind: :update, path: [:c], value: 42})
    assert {:ok, %{a: %{b: 42}, b: 1}} == Change.apply_change(data, %Change{kind: :update, path: [:a, :b], value: 42})
    assert {:ok, %{a: %{b: 1}, b: 42}} == Change.apply_change(data, %Change{kind: :update, path: [:b], value: 42})
    assert {:ok, %{a: 42, b: 1}} == Change.apply_change(data, %Change{kind: :update, path: [:a], value: 42})
    # Delete
    assert {:ok, %{a: %{b: 1}, b: 1}} = Change.apply_change(data, %Change{kind: :delete, path: [:c], value: 42})
    assert {:ok, %{a: %{}, b: 1}} == Change.apply_change(data, %Change{kind: :delete, path: [:a, :b]})
    assert {:ok, %{a: %{b: 1}}} == Change.apply_change(data, %Change{kind: :delete, path: [:b]})
    assert {:ok, %{b: 1}} == Change.apply_change(data, %Change{kind: :delete, path: [:a]})
    # Add
    assert {:ok, %{a: %{b: 1}, b: 1, c: [42]}} == Change.apply_change(data, %Change{kind: :add, path: [:c], value: 42})
    assert {:ok, %{a: %{b: 42}, b: 1}} == Change.apply_change(data, %Change{kind: :add, path: [:a, :b], value: 42})
    assert {:ok, %{a: %{b: 1}, b: 42}} == Change.apply_change(data, %Change{kind: :add, path: [:b], value: 42})
    assert {:ok, %{a: 42, b: 1}} == Change.apply_change(data, %Change{kind: :add, path: [:a], value: 42})
    # Remove
    assert {:ok, %{a: %{b: 1}, b: 1}} = Change.apply_change(data, %Change{kind: :remove, path: [:c], value: 42})
    assert {:ok, %{a: %{}, b: 1}} == Change.apply_change(data, %Change{kind: :remove, path: [:a, :b]})
    assert {:ok, %{a: %{b: 1}}} == Change.apply_change(data, %Change{kind: :remove, path: [:b]})
    assert {:ok, %{b: 1}} == Change.apply_change(data, %Change{kind: :remove, path: [:a]})
    assert {:ok, %{b: [1, 2]}} == Change.apply_change(%{b: [1, 2, 3]}, %Change{kind: :remove, path: [:b], value: 3})
  end

  test "Delta.Change.apply_change/2 applies change to data in document" do
    assert {:ok, %{data: %{a: 42}}} = Change.apply_change(document(), %Change{kind: :update, path: [:a], value: 42})
  end
end

defmodule DeltaTest.ValidatorsTest do
  use ExUnit.Case
  alias Delta.Validators

  test "Validators.uuid/2 validates uuid to be default and v4" do
    u = Validators.uuid(UUID.uuid4())
    assert {:ok, u} = u

    assert {:error, %{got: "UUID of type hex"}} = Validators.uuid(UUID.uuid4(:hex))
    assert {:error, %{got: "UUIDv1"}} = Validators.uuid(UUID.uuid1())
    assert {:error, %{got: "123"}} = Validators.uuid(123)
    assert {:error, _} = Validators.uuid("not_an_uuid")
  end

  test "Validators.maybe_uuid/2 validates uuid to be default and v4 or nil" do
    assert {:ok, _} = Validators.maybe_uuid(UUID.uuid4())
    assert {:ok, _} = Validators.maybe_uuid(nil)

    assert {:error, %{got: "UUID of type hex"}} = Validators.maybe_uuid(UUID.uuid4(:hex))
  end

  test "Validators.map/2" do
    assert {:ok, %{}} = Validators.map(%{})

    assert {:error, %{expected: "a map", got: "[]"}} = Validators.map([])
  end

  test "Validators.path/2" do
    assert {:ok, ["a", "b", 1]} = Validators.path(["a", "b", 1])

    assert {:error, %{got: "nil"}} = Validators.path(nil)
    assert {:error, %{got: "[1, %{}]"}} = Validators.path([1, %{}])
  end

  test "Validators.kind/2" do
    assert {:ok, :add} = Validators.kind(:add)
    assert {:ok, :update} = Validators.kind(:update)
    assert {:ok, :remove} = Validators.kind(:remove)
    assert {:ok, :delete} = Validators.kind(:delete)

    assert {:error, %{got: "smth"}} = Validators.kind(:smth)
  end
end

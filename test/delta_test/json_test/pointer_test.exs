defmodule DeltaTest.JsonTest.PointerTest do
  use ExUnit.Case

  alias Delta.Json.Pointer

  test "Delta.Json.Pointer.parse/1" do
    assert {:ok, ["a", 1, "~1", "/"]} == Pointer.parse("/a/1/~01/~1")
  end

  test "Delta.Json.Pointer.overlap?/2" do
    assert Pointer.overlap?([:a], [:a])
    assert Pointer.overlap?([:a, :b], [:a])
    assert !Pointer.overlap?([:a, :b], [:a, :c])
  end
end

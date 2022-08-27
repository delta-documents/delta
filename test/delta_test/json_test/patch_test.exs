defmodule DeltaTest.JsonTest.PatchTest do
  use ExUnit.Case

  alias Delta.Json.Patch

  @patch """
  [
    { "op": "test", "path": "/a/b/c", "value": "foo" },
    { "op": "remove", "path": "/a/b/c" },
    { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
    { "op": "replace", "path": "/a/b/c", "value": 42 },
    { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
    { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
  ]
  """

  @wrong_patch """
  [
    { "op": "test", "path": "/a/b/c", "value": "foo" },
    { "op": "remove", "path": "/a/b/c" },
    { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
    { "op": "replace", "path": "/a/b/c", "value": 42 },
    { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
    { "op": "blah", "from": "/a/b/d", "path": "/a/b/e" }
  ]
  """

  @json Jason.decode!(@patch)

  test "Delta.Json.Patch.parse/1" do
    assert {:ok,
            [
              {:remove, ["a", "b", "c"]},
              {:add, ["a", "b", "c"], ["foo", "bar"]},
              {:add, ["a", "b", "c"], 42},
              {:move, ["a", "b", "d"], ["a", "b", "c"]},
              {:copy, ["a", "b", "e"], ["a", "b", "d"]}
            ]} == Patch.parse(@patch)

    assert {:ok,
            [
              {:remove, ["a", "b", "c"]},
              {:add, ["a", "b", "c"], ["foo", "bar"]},
              {:add, ["a", "b", "c"], 42},
              {:move, ["a", "b", "d"], ["a", "b", "c"]},
              {:copy, ["a", "b", "e"], ["a", "b", "d"]}
            ]} == Patch.parse(@json)

    assert {:error, _} = Patch.parse(@wrong_patch)
  end

  test "Delta.Json.Patch.normalize/1" do
    assert [{:add, [:a], 1}, {:remove, [:b]}] =
             Patch.normalize([
               {:remove, [:a]},
               {:add, [:a], 1},
               {:remove, [:b]}
             ])

    assert [{:remove, [:b]}, {:add, [:a], 1}] =
             Patch.normalize([
               {:remove, [:a]},
               {:remove, [:b]},
               {:add, [:a], 1}
             ])
  end

  test "Delta.Json.Patch.squash/2" do
    assert [{:remove, [:a]}, {:remove, [:b]}] ==
             Patch.squash([{:remove, [:a]}, {:remove, [:b]}], [])

    assert [{:remove, [:a]}, {:remove, [:b]}] ==
             Patch.squash([{:remove, [:a]}], [{:remove, [:b]}])

    assert [{:remove, [:b]}, {:remove, [:a]}] ==
             Patch.squash([{:remove, [:b]}], [{:remove, [:a]}])

    assert [{:add, [:a], 5}] == Patch.squash([{:remove, [:a]}], [{:add, [:a], 5}])
  end

  test "Delta.Json.Patch.overlap?/2" do
    assert Patch.overlap?([{:remove, [:a]}], [{:remove, [:a]}])
    assert Patch.overlap?([{:remove, [:a]}], [{:remove, [:a]}, {:remove, [:b]}])
    assert !Patch.overlap?([{:remove, [:a]}], [{:remove, [:b]}])
  end
end

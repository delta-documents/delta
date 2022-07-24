defmodule DeltaTest.StorageTest do
  use ExUnit.Case, async: true

  use Delta.Storage.RecordHelper

  alias __MODULE__, as: S

  defstruct [:a, b: 2]

  test "to_record/1" do
    assert {S, 1, 2} == to_record(%S{a: 1, b: 2})
  end

  test "from_record" do
    assert %S{a: 1, b: 2} == from_record({S, 1, 2})
  end
end

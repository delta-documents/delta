defmodule DeltaTest.ErrorsTest do
  use ExUnit.Case, async: true

  alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation, Conflict}
  alias Delta.Errors

  test "Delta.Errors.DoesNotExist" do
    assert "A with id = 0 does not exist. msg" ==
             to_string(%DoesNotExist{struct: A, id: 0, message: "msg"})
  end

  test "Delta.Errors.AlreadyExist" do
    assert "A with id = 0 already exists. msg" ==
             to_string(%AlreadyExist{struct: A, id: 0, message: "msg"})
  end

  test "Delta.Errors.Validation" do
    assert "Expected A.a to be one, got: another. msg" ==
             to_string(%Validation{
               struct: A,
               field: :a,
               expected: "one",
               got: "another",
               message: "msg"
             })
  end

  test "Delta.Errors.Conflict" do
    assert "Delta.Change with id = 1 conflicts with Delta.Change with id = 2. msg" ==
             to_string(%Conflict{change_id: 1, conflicts_with: 2, message: "msg"})
  end

  test "Delta.Errors.get_struct/1" do
    assert DoesNotExist == Errors.get_struct(DoesNotExist)
    assert DoesNotExist == Errors.get_struct(%DoesNotExist{})
  end

  test "Delta.Errors.inspect_struct/1" do
    assert "Delta.Errors.DoesNotExist" == Errors.inspect_struct(DoesNotExist)
  end

  test "Delta.Errors.maybe_message/2" do
    assert "" == Errors.maybe_message("", nil)
    assert "m1 m2" == Errors.maybe_message("m1", "m2")
  end

  test "Delta.Errors.get_id/1" do
    assert 1 == Errors.get_id(%{id: 1})
    assert 1 == Errors.get_id(1)
  end
end

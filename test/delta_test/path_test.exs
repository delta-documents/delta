defmodule DeltaTest.PathTest do
  use ExUnit.Case, async: true
  doctest Delta.Path

  import Delta.Path

  test "Delta.Path.parse/1 reports errors" do
    {:error, _} = parse("$.store.book[*].author")
    {:error, _} = parse("$..author")
    {:error, _} = parse("$.store.*")
    {:error, _} = parse("$.store..price")
    {:error, _} = parse("$..book[2]")
    {:error, _} = parse("$..book[(@.length-1)]")
    {:error, _} = parse("$..book[-1:]")
    {:error, _} = parse("$..book[0,1]")
    {:error, _} = parse("$..book[:2]")
    {:error, _} = parse("$..book[?(@.isbn)]")
    {:error, _} = parse("$..book[?(@.price<10)]")
    {:error, _} = parse("$..*")
  end

  test "Delta.Path.parse/1 root is optional" do
    {:ok, path1} = parse("$.A")
    {:ok, path2} = parse(".A")

    assert path1 == path2
  end

  test "Delta.Path.parse/1 does not make difference of .child and ['child']" do
    {:ok, path1} = parse(".a")
    {:ok, path2} = parse("['a']")

    assert path1 == path2
  end

  test "Delta.Path.parse/1 return correct Pathex path" do
    {:ok, path1} = parse("")
    {:ok, path2} = parse(".a")
    {:ok, path3} = parse(".a.b")
    {:ok, path4} = parse(".a.b[1]")

    assert path1 == []
    assert path2 == ["a"]
    assert path3 == ["a", "b"]
    assert path4 == ["a", "b", 1]
  end

  test "Delta.Path.compile/1 compiles correct Pathex path" do
    assert compile([]) |> Pathex.inspect() == "matching(_)"
    assert compile(["a", "b"]) |> Pathex.inspect() == ~S/path("a") ~> path("b")/
  end

  test "Delta.Path.path! parses path and raises" do
    assert_raise MatchError, fn -> parse!("A") end
    assert ["A"] = parse!(".A")
  end

  test "Delta.Path.sigil_p/2 parses and compiles path" do
    assert ~p($.a.b) |> Pathex.inspect() == ~S/path("a") ~> path("b")/
  end

  test "Delta.Path.overlap?/2 is true if path points to same value or sub-value" do
    assert overlap?([:a, :b], [:a, :b])
    assert overlap?([:a, :b, :c], [:a, :b])
    assert overlap?([:a, :b], [:a, :b, :c])
    assert overlap?([], [:a])

    assert not overlap?([:a, :b], [:a, :c])
  end
end

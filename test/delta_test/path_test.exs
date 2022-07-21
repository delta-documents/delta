defmodule DeltaTest.PathTest do
  import Delta.Path
  use ExUnit.Case
  doctest Delta.Path

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
end

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

    assert Pathex.inspect(path1) == Pathex.inspect(path2)
  end
end

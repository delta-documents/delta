defmodule Delta.Json.Patch do
  @moduledoc """
  Helper functions for Json Patch (RFC 6902)

  Note that strictly speaking it is not RFC 6902-compliant.
    - appliance of Delta.Json.Patch to data can never fail
    - test operation is ignored
    - replace and add considered to be the same operations

  This is due to optimisation reasons.
  """

  @typedoc """
  List of operations that will be applied in order they are defined.
  """
  @type t() :: [operation()]

  @type operation() :: add() | remove() | move() | copy()

  @typedoc """
  Adds a value and **creates** all that is required to make the pointer valid.
  """
  @type add() :: {:add, Json.Pointer.t(), any()}

  @typedoc """
  Removes value from path. NOOP if the value does not exists.
  """
  @type remove() :: {:remove, Json.Pointer.t()}

  @typedoc """
  Moves the value from a path to another path. If the from path cant be resolved, the moved value will be `nil`.
  """
  @type move() :: {:move, Json.Pointer.t(), from :: Json.Pointer.t()}

  @typedoc """
  Copies the value from a path to another path. If the from path cant be resolved, the copied value will be `nil`.
  """
  @type copy() :: {:copy, Json.Pointer.t(), from :: Json.Pointer.t()}

  @doc """
  Parses json patch into Delta.Json.Patch.t()

  Note:
   - test operation is ignored
   - replace and add considered to be the same operations
  """
  @spec parse(String.t() | list()) :: {:ok, t()} | {:error, any()}
  def parse(s) when is_bitstring(s) do
    with {:ok, o} <- Jason.decode(s), do: parse(o)
  end

  def parse(o) when is_list(o) do
    try do
      {:ok,
       o
       |> Enum.map(fn
         %{"op" => "test"} ->
           nil

         %{"op" => "remove", "path" => path} ->
           {:remove, path} |> parse_path()

         %{"op" => "add", "path" => path, "value" => value} ->
           {:add, path, value} |> parse_path()

         %{"op" => "replace", "path" => path, "value" => value} ->
           {:add, path, value} |> parse_path()

         %{"op" => "move", "from" => from, "path" => path} ->
           {:move, path, from} |> parse_path()

         %{"op" => "copy", "from" => from, "path" => path} ->
           {:copy, path, from} |> parse_path()

         item ->
           throw({:error, item})
       end)
       |> Enum.filter(fn x -> x != nil end)}
    catch
      x -> x
    end
  end

  @doc """
  Joins two patches together
  """
  @spec squash(t(), t()) :: t()
  def squash(patch1, patch2) do
    normalize(patch1 ++ patch2)
  end

  @doc """
  If a paths of two operations are the same, keeps the last one
  """
  @spec normalize(t()) :: t()
  def normalize(patch) do
    patch
    |> Enum.with_index(fn
      op, i -> {elem(op, 1), {op, i}}
    end)
    |> Enum.into(%{})
    |> Enum.sort_by(fn {_, {_, i}} -> i end)
    |> Enum.map(fn {_, {op, _}} -> op end)
  end

  @doc """
  Returns true if two patches have operations on overlapping paths
  """
  @spec overlap?(t(), t()) :: boolean()
  def overlap?(patch1, patch2) do
    for p1 <- patch1, p2 <- patch2 do
      if Delta.Json.Pointer.overlap?(elem(p1, 1), elem(p2, 1)), do: throw(true)
    end

    false
  catch
    x -> x
  end

  defp parse_path({:remove, path}) do
    with {:ok, path} <- Delta.Json.Pointer.parse(path) do
      {:remove, path}
    else
      x -> throw(x)
    end
  end

  defp parse_path({:add, path, value}) do
    with {:ok, path} <- Delta.Json.Pointer.parse(path) do
      {:add, path, value}
    else
      x -> throw(x)
    end
  end

  defp parse_path({:move, path1, path2}) do
    with {:ok, path1} <- Delta.Json.Pointer.parse(path1),
         {:ok, path2} <- Delta.Json.Pointer.parse(path2) do
      {:move, path1, path2}
    else
      x -> throw(x)
    end
  end

  defp parse_path({:copy, path1, path2}) do
    with {:ok, path1} <- Delta.Json.Pointer.parse(path1),
         {:ok, path2} <- Delta.Json.Pointer.parse(path2) do
      {:copy, path1, path2}
    else
      x -> throw(x)
    end
  end
end

defmodule Delta.Path do
  import NimbleParsec

  require Pathex
  require Pathex.Lenses

  @moduledoc """
  Parser for DeltaPaths

  Each path may start with "$": "$.A" === ".A"
  Each path has zero or more children defined in it: "$", "$.A.B" === "$['A']['B']", "$[1][2].C"
  """

  @doc """
  Parses DeltaPaths into Pathex path. Returns {:ok, path} or {:error, message}
  """

  @spec parse(String.t()) :: {:ok, Pathex.t()} | {:error, String.t()}
  def parse(str) do
    case do_parse(str) do
      {:ok, [], _, _, _, _} -> {:ok, Pathex.Lenses.matching(_)}

      {:ok, paths, _, _, _, _} ->
        p =
          paths
          |> Enum.map(&Pathex.path(&1, :json))
          |> Enum.reduce(&Pathex.concat/2)

        {:ok, p}

      {:error, msg, _, _, _} -> {:error, msg}
    end
  end

  root = ignore(string("$"))

  dot_notation = ignore(string(".")) |> utf8_string([?A..?z, ?0..?9, not: ?\.], min: 1)

  key = ignore(string("'")) |> utf8_string([?A..?z, ?0..?9, not: ?\'], min: 1) |> ignore(string("'"))
  index = utf8_string([?0..?9], min: 1) |> post_traverse({:int, []})

  bracket_notation = ignore(string("[")) |> choice([index, key]) |> ignore(string("]"))
  child = choice([dot_notation, bracket_notation])

  defparsecp :do_parse, optional(root) |> choice([
   eos(),
   times(child, min: 1)
  ]), inline: true

  defp int(rest, args, context, _line, _offset) do
    {rest, args |> Enum.map(&String.to_integer/1), context}
  end
end

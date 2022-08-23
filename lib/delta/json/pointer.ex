defmodule Delta.Json.Pointer do
  @moduledoc """
  Parser for Json Pointer (RFC 6901)
  """

  @type t() :: [String.t() | integer()]

  @spec parse(String.t()) :: {:ok, t()} | {:error, any()}
  def parse(s) do
    result =
      s
      |> String.split("/")
      |> Enum.map(fn s ->
        case Integer.parse(s) do
          {int, ""} ->
            int

          _ ->
            s
            |> String.replace("~1", "/")
            |> String.replace("~0", "~")
        end
      end)

    {:ok, result}
  end
end

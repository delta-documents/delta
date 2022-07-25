defmodule Delta.Errors do
  defmodule DoesNotExist, do: defstruct([:struct, :id, :message])
  defmodule AlreadyExist, do: defstruct([:struct, :id, :message])
  defmodule Validation, do: defstruct([:struct, :field, :expected, :got, :message])
  defmodule Conflict, do: defstruct([:change_id, :conflicts_with, :message])

  def get_struct(%{__struct__: s}), do: s
  def get_struct(s), do: s

  def inspect_struct(s), do: s |> get_struct() |> inspect_without_nil()

  def inspect_without_nil(nil), do: ""
  def inspect_without_nil(v), do: inspect(v)

  def i_s(s), do: inspect_struct(s)

  def maybe_message(string, nil), do: string
  def maybe_message(string, msg), do: "#{string} #{msg}"

  def get_id(%{id: id}), do: id
  def get_id(id), do: id

  def m_m(s, m), do: maybe_message(s, m)
end

alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation, Conflict}
alias Delta.Errors, as: E

defimpl String.Chars, for: DoesNotExist do
  def to_string(%{struct: s, id: id, message: m}),
    do: "#{E.i_s(s)} with id = #{E.get_id(id)} does not exist." |> E.m_m(m)
end

defimpl String.Chars, for: AlreadyExist do
  def to_string(%{struct: s, id: id, message: m}),
    do: "#{E.i_s(s)} with id = #{E.get_id(id)} already exists." |> E.m_m(m)
end

defimpl String.Chars, for: Validation do
  def to_string(%{struct: s, field: f, expected: e, got: g, message: m}),
    do: "Expected #{E.i_s(s)}.#{f} to be #{e}, got: #{g}." |> E.m_m(m)
end

defimpl String.Chars, for: Conflict do
  def to_string(%{change_id: id0, conflicts_with: id1, message: m}),
    do:
      "Delta.Change with id = #{E.get_id(id0)} conflicts with Delta.Change with id = #{E.get_id(id1)}."
      |> E.m_m(m)
end

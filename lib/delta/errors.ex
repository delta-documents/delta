defmodule Delta.Errors do
  @moduledoc """
  Helpers for working with errors
  """

  defmodule DoesNotExist do
    @type t() :: %__MODULE__{struct: module(), id: Delta.uuid4(), message: String.t()}
    defstruct([:struct, :id, :message])
  end

  defmodule AlreadyExist do
    @type t() :: %__MODULE__{struct: module(), id: Delta.uuid4(), message: String.t()}
    defstruct([:struct, :id, :message])
  end

  defmodule Validation do
    @type t() :: %__MODULE__{struct: module(), field: atom(), got: any(), message: String.t()}
    defstruct([:struct, :field, :expected, :got, :message])
  end

  defmodule Conflict do
    @type t() :: %__MODULE__{commit_id: Delta.uuid4(), conflicts_with: Delta.uuid4(), message: String.t()}
    defstruct([:commit_id, :conflicts_with, :message])
  end


  @doc false
  def get_struct(%{__struct__: s}), do: s
  def get_struct(s), do: s

  @doc false
  def inspect_struct(s), do: s |> get_struct() |> inspect_without_nil()

  @doc false
  def inspect_without_nil(nil), do: ""
  def inspect_without_nil(v), do: inspect(v)

  @doc false
  def i_s(s), do: inspect_struct(s)

  @doc false
  def maybe_message(string, nil), do: string
  def maybe_message(string, msg), do: "#{string} #{msg}"

  @doc false
  def get_id(%{id: id}), do: id
  def get_id(id), do: id

  @doc false
  def m_m(s, m), do: maybe_message(s, m)
end

alias Delta.Errors.{DoesNotExist, AlreadyExist, Validation, Conflict}
alias Delta.Errors, as: E

defimpl String.Chars, for: DoesNotExist do
  def to_string(%{struct: s, id: id, message: m}), do: "#{E.i_s(s)} with id = #{E.get_id(id)} does not exist." |> E.m_m(m)
end

defimpl String.Chars, for: AlreadyExist do
  def to_string(%{struct: s, id: id, message: m}), do: "#{E.i_s(s)} with id = #{E.get_id(id)} already exists." |> E.m_m(m)
end

defimpl String.Chars, for: Validation do
  def to_string(%{struct: s, field: f, expected: e, got: g, message: m}), do: "Expected #{E.i_s(s)}.#{f} to be #{e}, got: #{g}." |> E.m_m(m)
end

defimpl String.Chars, for: Conflict do
  def to_string(%{commit_id: id0, conflicts_with: id1, message: m}), do: "Delta.Commit with id = #{E.get_id(id0)} conflicts with Delta.Commit with id = #{E.get_id(id1)}." |> E.m_m(m)
end

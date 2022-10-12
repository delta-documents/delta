defmodule Delta.Document do
  @moduledoc """
  Internal documents API
  """

  alias Delta.Validators
  alias Delta.Errors.Validation

  @type t() :: %__MODULE__{
          id: Delta.uuid4(),
          collection: String.t(),
          data: any(),
          updated_at: DateTime.t()
        }

  @type id() :: Delta.uuid4() | t()

  @type collection() :: String.t()

  defstruct [:id, :collection, :data, :updated_at]

  @doc """
  Validates `document.id` to be UUIDv4 in default form
  """
  @spec validate(t()) :: {:ok, t()} | {:error, Validation.t()}
  def validate(%__MODULE__{id: id} = d) do
    with :ok <- Validators.uuid4(id), do: {:ok, d}
  end

  def validate(x) do
    {:error, %Validation{struct: __MODULE__, expected: "Value to be %#{__MODULE__}{}", got: x}}
  end

  @doc """
  Returns ids of all documents for efficiency reasons
  """
  @spec list() :: {:atomic, [Delta.uuid4()]} | {:aborted, reason :: any()}
  def list(), do: nil

  @doc """
  Returns ids of all documents in collection for efficiency reasons
  """
  @spec list(collection()) :: {:atomic, [t()]} | {:aborted, reason :: any()}
  def list(collection), do: nil

  @spec get(id()) :: {:atomic, t()} | {:aborted, Delta.Errors.DoesNotExist.t()}
  def get(document_id), do: nil

  @doc """
  Creates document.

  Aborts with `%Delta.Errors.AlreadyExists{}` if document with `id = document.id` already exist.
  """
  @spec create(t()) :: {:atomic, t()} | {:aborted, Delta.Errors.AlreadyExists.t()}
  def create(document), do: nil

  @doc """
  Updates document.

  Aborts with `%Delta.Errors.DoesNotExist{}` if document with `id = document.id` does not exist.
  """
  @spec update(id(), map() | keyword()) ::
          {:atomic, t()} | {:aborted, Delta.Errors.DoesNotExist.t()}
  def update(document_id, attrs \\ []), do: nil

  @doc """
  Deletes document and its changes with `id = document_id`.
  Reutrns {:atomic, :ok} even if document with `id = document_id` does not exist.
  """
  @spec delete(id()) :: {:atomic, :ok} | {:aborted, reason :: any()}
  def delete(document_id), do: nil

  @doc """
  Adds list of changes `changes` to document with `id = document_id` in transactional manner.

  Aborts with `%Delta.Errors.Conflict{}`
  if `changes` do not form linear history
  or one or more changes conflict with existing changes.

  Aborts with `%Delta.Errors.DoesNotExist{}` if document with `id = document_id` does not exist.
  """
  @spec add_changes(id(), [Delta.Change.t()]) ::
          {:atomic, [Delta.Change.t()]}
          | {:aborted, Delta.Errors.DoesNotExist.t() | Delta.Errors.Conflict.t()}
  def add_changes(document_id, changes), do: nil
end

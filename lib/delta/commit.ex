defmodule Delta.Commit do
  @moduledoc """
  Internal API for working with commits

  An interface to work on top of `Delta.DataLayer` which should also implement `Delta.Commit`
  """

  @typedoc """
  Represents a commit made by user to a document.

  ## Fields
    - `:id` – UUIDv4 in default form. **Required**
    - `:previous_commit_id` – UUIDv4 in default form. Used to order commits of particular document to form a history. **Required**
    - `:document_id` – UUIDv4 in default from. **Required**
    - `:order` – Order of commit in document's history. *Autogenerated*
    - `:autosquash?` – Should the commits be squashed with the last commit with `:delta` with same paths
    - `:delta` – Changes to document in RFC 6902 json patch format. **Required**
    - `:reverse_delta` – Json delta to revert document to previous state. Autogenerated
    - `:meta` – any metadata, e. g. user who made it
    - `:updated_at` – when the commit was updated.

  ## Autosquashing
  Autosquashing is delta's feature for continious and frequent document updates. It reduces the number of commits by squashing (see `Delta.Commit.squash/2`).
  In order for two commits to be autosquashed, they must be marked `autosquash?: true` and have `delta` with same paths.
  If there will be a commit with `autosquahs?: false` and its delta will have any path which is being autosquahed at the moment, the commit will not be squashed.
  For autosquash commit no checks of `previous_commit_id` are performed.
  """

  alias Delta.DataLayer
  alias Delta.Errors.{Validation, DoesNotExist, AlreadyExist}

  @type t() :: %__MODULE__{
          id: Delta.uuid4(),
          previous_commit_id: Delta.uuid4(),
          document_id: Delta.uuid4(),
          order: non_neg_integer,
          autosquash?: boolean,
          delta: rfc_6092 :: any,
          reverse_delta: rfc_6092 :: any,
          meta: any,
          updated_at: DateTime.t()
        }

  @type id() :: Delta.uuid4() | t()

  defstruct [
    :id,
    :previous_commit_id,
    :document_id,
    :order,
    :autosquash?,
    :delta,
    :reverse_delta,
    :meta,
    :updated_at
  ]

  @doc """
  Same as `Delta.Commit.list/1`, but returns data with continuation
  """
  @callback list(DataLayer.layer_id(), continuation? :: boolean()) ::
              {:atomic, [t()], DataLayer.continuation()}
              | {:aborted, DoesNotExist.t(), DataLayer.continuation()}
  @doc """
  Same as `Delta.Commit.list/2`, but returns data with continuation
  """
  @callback list(DataLayer.layer_id(), id(), id(), continuation? :: boolean()) ::
              {:atomic, [t()], DataLayer.continuation()}
              | {:aborted, DoesNotExist.t(), DataLayer.continuation()}
  @doc """
  Same as `Delta.Commit.get/1`, but returns data with continuation
  """
  @callback get(DataLayer.layer_id(), id(), continuation? :: boolean()) ::
              {:atomic, t(), DataLayer.continuation()}
              | {:aborted, DoesNotExist.t(), DataLayer.continuation()}

  @callback write(DataLayer.layer_id(), t(), continuation? :: boolean()) ::
              {:atomic, t(), DataLayer.continuation()}
              | {:aborted, DoesNotExist.t() | AlreadyExist.t(), DataLayer.continuation()}
  @doc """
  Same as `Delta.Commit.squash/2`, but returns data with continuation
  """
  @callback squash(DataLayer.layer_id(), id(), id(), continuation? :: boolean()) ::
              {:atomic, t(), DataLayer.continuation()}
              | {:aborted, DoesNotExist.t(), DataLayer.continuation()}
  @doc """
  Same as `Delta.Commit.delete/1`, but returns data with continuation
  """
  @callback delete(DataLayer.layer_id(), id(), continuation? :: boolean()) ::
              {:atomic, :ok, DataLayer.continuation()}

  @doc """
  Validates commit according to the following rules:

  - `:id` – must be UUIDv4 in default form
  - `:previous_commit_id` – must be UUIDv4 in default form of previous commit or `nil`
  - `:delta` – must be valid RFC 6092 Json delta
  - `:document_id` – must be valid UUIDv4 of document in default form.
  """
  @spec validate(t() | any()) :: {:ok, t()} | {:error, Validation.t()}
  def validate(commit), do: nil

  @doc """
  Lists commits of `Delta.Documnent` with `id = document_id`. Expensive operation.
  If document does not exists, returns empty list

  Aborts if document with `id = document_id` does not exist.
  """
  @spec list(Delta.Document.id()) :: {:atomic, [t()]} | {:aborted, DoesNotExist.t()}
  def list(document_id), do: nil

  @doc """
  Lists commit from newest – `from_commit_id` to oldest – `to_commit_id`.

  If commit with `id = from_commit_id` does not exist, assumes it to be the latest commit.
  If commit with `id = to_commit_id` does not exist, assumes it to be the first commit.
  """
  @spec list(id(), id()) :: {:atomic, [t()]} | {:aborted, DoesNotExist.t()}
  def list(from_commit_id, to_commit_id), do: nil

  @spec get(id()) :: {:atomic, t()} | {:aborted, DoesNotExist.t()}
  def get(commit_id), do: nil

  @doc """
  Writies commit commit.
  """
  @spec write(t()) :: {:atomic, t()} | {:aborted, any()}
  def write(commit), do: nil

  @doc """
  Squashes Delta.Commit with `id = commit_id_2` into one with `id = commit_id_1`.
  Resulting commit will have metadata of the second commit.

  The second commit may not exist.

  Aborts with `%Delta.Errors.DoesNotExist{}` if commit with `id = commit_id_1` or `id = commit_id_2` does not exist.
  """
  @spec squash(id(), id()) :: {:atomic, t()} | {:aborted, DoesNotExist.t()}
  def squash(commit_id_1, commit_id_2), do: nil

  @doc """
  Deletes commit with `id = commit_id`.
  Returns {:atomic, :ok} even if commit with `id = commit_id` does not exist.
  """
  @spec delete(id()) :: {:atomic, :ok}
  def delete(change_id), do: nil

  @doc """
  Gets id from id()
  """
  @spec id(id) :: Delta.uuid4()
  def id(%__MODULE__{id: id}), do: id
  def id(id), do: id
end

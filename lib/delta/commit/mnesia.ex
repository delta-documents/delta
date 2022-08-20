defmodule Delta.Commit.Mnesia do
  @moduledoc """
  Mnesia API for Commits, duplicates Delta.Commit API
  """
@doc """
  Lists commits of `Delta.Documnent` with `id = document_id`. Expensive operation.
  If document does not exists, returns empty list

  Aborts if document with `id = document_id` does not exist.
  """
  @spec list(Delta.Document.id()) ::
          {:atomic, [Delta.Commit.t()]} | {:aborted, Delta.Errors.DoesNotExist.t()}

  def list(document_id), do: nil

  @doc """
  Lists commit from newest – `from_commit_id` to oldest – `to_commit_id`.

  Aborts with `%Delta.Errors.DoesNotExist{}` if commit with `id = from_commit_id` or `id = to_commit_id` does not exist.
  """
  @spec list(Delta.Commit.id(), Delta.Commit.id()) ::
          {:atomic, [Delta.Commit.t()]} | {:aborted, Delta.Errors.DoesNotExist.t()}

  def list(from_commit_id, to_commit_id), do: nil

  @spec get(Delta.Commit.id()) :: {:atomic, Delta.Commit.t()} | {:aborted, Delta.Errors.DoesNotExist.t()}
  def get(commit_id), do: nil

  @doc """
  Creates commit.

  Aborts with `%Delta.Errors.DoesNotExist{}` if
  commit with `id = commit.previous_commit_id`
  or document with `id = commit.document_id` does not exist.

  Aborts with `%Delta.Errors.AlreadyExists{}` if commit with `id = commit.id` already exists.
  """
  @spec create(Delta.Commit.t()) ::
          {:atomic, Delta.Commit.t()} | {:aborted, Delta.Errors.DoesNotExist.t() | Delta.Errors.AlreadyExist.t()}

  def create(commit), do: nil

  @doc """
  Updates commit.

  Aborts with `%Delta.Errors.DoesNotExist{}` if
  commit with `id = commit.previous_commit_id`
  or document with `id = commit.document_id`
  or commit with `id = commit.id` does not exist.
  """
  @spec update(Delta.Commit.id(), map() | keyword()) :: {:atomic, Delta.Commit.t()} | {:aborted, Delta.Errors.DoesNotExist.t()}
  def update(commit, attrs \\ []), do: nil

  @doc """
  Squashes Delta.Commit with `id = commit_id_2` into one with `id = commit_id_1`.
  Resulting commit will have metadata of the second commit.

  Aborts with `%Delta.Errors.DoesNotExist{}` if commit with `id = commit_id_1` or `id = commit_id_2` does not exist.
  """
  @spec squash(Delta.Commit.id(), Delta.Commit.id()) ::
          {:atomic, Delta.Commit.t()} | {:aborted, Delta.Errors.DoesNotExist.t()}
  def squash(commit_id_1, commit_id_2), do: nil

  @doc """
  Deletes commit with `id = commit_id`.
  Returns {:atomic, :ok} even if commit with `id = commit_id` does not exist.
  """
  @spec delete(Delta.Commit.id()) :: {:atomic, :ok}
  def delete(change_id), do: nil
end

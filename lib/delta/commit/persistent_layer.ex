defmodule Delta.Commit.PersistentLayer do
  @moduledoc """
  Persistent layer for Delta.Commit

  Works on top of MongoDB.
  """
  import Delta.DataLayer
  require Logger
  use GenServer

  alias Delta.Commit
  alias Delta.DataLayer
  alias Delta.Errors.DoesNotExist

  @behaviour DataLayer
  @behaviour Delta.Commit

  @impl DataLayer
  @doc """
  Starts this DataLayer with specific document id.

  Has no options.
  """
  def start_link(document_id, _ \\ nil) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl DataLayer
  @doc """
  Returns anonymous function /0, which deletes mnesia table used by the layer.
  """
  def crash_handler(%{table: t}) do
    fn ->
      :mnesia.delete_table(t)
    end
  end

  @impl Commit
  @doc """
  Lists all commits on this data layer.

  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/1`
  """
  def list({__MODULE__, document_id}, continuation?) do
  end

  def list(layer_id, continuation?), do: layer_id |> layer_id_normal() |> list(continuation?)

  @impl Commit
  @doc """
  Lists commits from one to another.

  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/3`
  """
  def list({__MODULE__, document_id}, from, to, continuation?) do
  end

  def list(layer_id, from, to, continuation?),
    do: layer_id |> layer_id_normal() |> list(from, to, continuation?)

  @impl Commit
  @doc """
  Gets commit.

  If it exists, continuation is always `nil`

  See `Delta.Commit.get/1`
  """
  def get({__MODULE__, document_id}, id, continuation?) do
  end

  def get(layer_id, id, continuation?),
    do: layer_id |> layer_id_normal() |> get(id, continuation?)

  @impl Commit
  @doc """
  Writes commit.

  Continuation writes commit on another data layer.

  See `Delta.Commit.write/1`
  """
  def write(
        {__MODULE__, document_id} = layer_id,
        %Commit{document_id: document_id} = commit,
        continuation?
      ) do
  end

  def write(layer_id, commit, continuation?),
    do: layer_id |> layer_id_normal() |> write(commit, continuation?)

  @impl Commit
  @doc """
  Writes a list of commits. Commits are assumed to have equal `document_id`.

  Continuation writes commits on another data layer

  See `Delta.Commit.write_many/1`
  """
  def write_many(
        {__MODULE__, document_id} = layer_id,
        [%Commit{document_id: document_id} | _] = commits,
        continuation?
      ) do
  end

  def write_many(_, [], _), do: {:atomic, [], nil}

  def write_many(layer_id, commits, continuation?),
    do: layer_id |> layer_id_normal() |> write_many(commits, continuation?)

  @impl Commit
  @doc """
  Deletes commit. Always successful. Continuation deletes commit on another data layer.

  See `Delta.Commit.delete/1`
  """
  def delete({__MODULE__, document_id} = layer_id, id, continuation?) do
  end

  def delete(layer_id, commit, continuation?),
    do: layer_id |> layer_id_normal() |> delete(commit, continuation?)

  def add_commits({__MODULE__, _}, [], _), do: {:atomic, [], nil}

  def add_commits({__MODULE__, _} = layer_id, commits, continuation?) do
  end

  @impl GenServer
  def init(%{document_id: id, table: table} = state) do
    Swarm.register_name({__MODULE__, id}, self())
    Swarm.join(DataLayer, self())
  end

  @impl GenServer
  def handle_cast({:add_continuation, continuation}, %{continuations: cs} = state),
    do: {:noreply, struct(state, continuations: [continuation | cs])}

  def from_mongo(%{
        "_id" => id,
        "previous_commit_id" => previous_commit_id,
        "document_id" => document_id,
        "order" => order,
        "autosquash?" => autosquash?,
        "patch" => patch,
        "reverse_patch" => reverse_patch,
        "meta" => meta,
        "updated_at" => updated_at
      }) do
    %Commit{
      id: id,
      previous_commit_id: previous_commit_id,
      document_id: document_id,
      order: order,
      autosquash?: autosquash?,
      patch: patch_from_mongo(patch),
      reverse_patch: patch_from_mongo(reverse_patch),
      meta: meta,
      updated_at: updated_at
    }
  end

  def to_mongo(%Commit{
        id: id,
        previous_commit_id: previous_commit_id,
        document_id: document_id,
        order: order,
        autosquash?: autosquash?,
        patch: patch,
        reverse_patch: reverse_patch,
        meta: meta,
        updated_at: updated_at
      }) do
    %{
      _id: id,
      previous_commit_id: previous_commit_id,
      document_id: document_id,
      order: order,
      autosquash?: autosquash?,
      patch: patch_to_mongo(patch),
      reverse_patch: patch_to_mongo(reverse_patch),
      meta: meta,
      updated_at: updated_at
    }
  end

  defp patch_to_mongo(nil), do: nil
  defp patch_to_mongo(patch), do: Enum.map(patch, &Tuple.to_list/1)

  defp patch_from_mongo(nil), do: nil

  defp patch_from_mongo(patch),
    do: Enum.map(patch, &List.to_tuple([String.to_existing_atom(hd(&1)) | tl(&1)]))
end

defmodule Delta.Connection do
  @moduledoc """
  Behaviour for connections to Delta.
  Instances is expected to:
    - manage connection from user
    - join Swarm group `Delta.Connection` to be able to recieve notifications
    - to handle notificatons asyncronously
  """

  @typedoc """
  Events for clients:
    - `{:created, document_id}` – `Delta.Document.t()` with `id = document_id` is created
    - `{:created, document_id}` – `Delta.Document.t()` with `id = document_id` is deleted
    - `{:added, commit}` – `Delta.Commit.t()` was added
    - `{:squashed, into, what}` – `Delta.Commit.t()` `what` was squashed `into`
  """
  @type event() ::
          {:created, document_id :: Delta.uuid4()}
          | {:deleted, document_id :: Delta.uuid4()}
          # Commit events
          | {:added, Delta.Commit.t()}
          | {:squashed, into :: Delta.Commit.t(), Delta.Commit.t()}

  @callback handle_call({:notify, event()}, any(), any()) :: {:reply, :ok, any()}

  @doc """
  Sends event to every connection
  """
  @spec notify(event()) :: [:ok]
  def notify(event), do: Swarm.multi_call(__MODULE__, {:notify, event}, 100)
end

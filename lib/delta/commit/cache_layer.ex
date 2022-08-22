defmodule Delta.Commit.CacheLayer do
  require Logger
  use GenServer

  alias Delta.DataLayer

  @behaviour DataLayer

  @moduledoc """
  Caching layer for Delta.Commit
  """

  defstruct [:document_id, :table]

  @impl DataLayer
  def start_link(document_id, _ \\ nil) do
    table = :"#{__MODULE__}.#{document_id}"

    GenServer.start_link(__MODULE__, [
      %__MODULE__{document_id: document_id, table: table}
    ])
  end

  @impl DataLayer
  def replicate(_nodes), do: :ok

  @impl DataLayer
  def crash_handler(state) do
    fn ->
      Logger.log(:error, "#{__MODULE__} crashed: #{state}")
    end
  end

  @impl DataLayer
  def continue(layer_id, continuation) do
    GenServer.call(DataLayer.layer_id_pid(layer_id), continuation)
  end

  @impl GenServer
  def init(%{document_id: id, table: table} = state) do
    Swarm.register_name({__MODULE__, id}, self())
    Swarm.join(DataLayer, self())

    DataLayer.CrashHandler.add(self(), crash_handler(state))

    :mnesia.create_table(table,
      attributes: [
        :order,
        :id,
        :previous_commit_id,
        :autosquash?,
        :delta,
        :reverse_delta,
        :meta,
        :updated_at
      ],
      index: [:id, :previous_commit_id],
      disc_copies: [node()]
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:continue, continuation}, _from, state) do
    layer_id = self()

    {:reply, continuation.(layer_id), state}
  end

  @spec table(DataLayer.layer_id()) :: :mnesia.table()
  def table(layer_id) do
    {__MODULE__, document_id} = DataLayer.layer_id_normal(layer_id)

    :"#{__MODULE__}.#{document_id}"
  end
end

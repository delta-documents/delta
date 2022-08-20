defmodule Delta.Commit.CacheLayer do
  @behaviour Delta.DataLayer
  use GenServer

  defstruct [:document_id, :table, :write_timeout]

  @impl Delta.DataLayer
  def start_link(document_id, opts \\ []) do
    write_timeout = Keyword.get(opts, :write_timeout, 5_000)
    table = :"#{__MODULE__}.document_id"

    GenServer.start_link(__MODULE__, [
      %__MODULE__{document_id: document_id, table: table, write_timeout: write_timeout}
    ])
  end

  @impl GenServer
  def init(%{document_id: id} = state) do
    Swarm.register_name({__MODULE__, id}, self())
    Swarm.join(Delta.DataLayer, self())

    {:ok, state}
  end

  @impl true
  def handle_call({:continue, continuation}, _from, state) do
    layer_id = self()

    {:reply, continuation.(layer_id), state}
  end

  @impl Delta.DataLayer
  def replicate(_nodes), do: :ok

  @impl Delta.DataLayer
  def crash_handler(_layer_id), do: fn -> IO.inspect(:crash_handler) end
end

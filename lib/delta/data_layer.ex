defmodule Delta.DataLayer do
  @moduledoc """
  Behaviour of Delta Data Layers.

  *Data layer* is a GenServer isolating all reads, writes and deletes to a certain entites associated with document.
  Each instance is expected to control its uniuqe portion of data.
  """

  @doc """
  Starts *data layer* for isolating any data related to document.
  """
  @callback start_link(document_id :: Delta.Document.t() | Delta.uuid4(), opts :: keyword()) :: {:ok, pid} | {:error, any()}

  @doc """
  Terminates *data layer* gracefully:
   - all data will be saved
   - no operations after starting graceful stop will be performed
   - all auxiilary data will be cleaned.
  """
  @callback graceful_stop(pid()) :: :ok

  @doc """
  Reads data from instance of *data layer*.
  """
  @callback read(pid(), any()) :: {:atomic, any()} | {:aborted, any()}

  @doc """
  Writes data to instance of *data layer*.
  """
  @callback write(pid(), any()) :: :ok | {:atomic, any()} | {:aborted, any()}

  @doc """
  Asks *data layer* to free some memory.
  """
  @callback dump(pid()) :: :ok

  @doc """
  Deletes data from instance of *data layer*.
  """
  @callback delete(pid(), any()) :: :ok | {:atomic, any()} | {:aborted, any()}

  @doc """
  Returns true if data on particular *data layer* exists.
  """

  @callback exists?(pid(), any()) :: boolean()

  @doc """
  Performs all required actions for *data layer* to be available on all nodes in list.
  """
  @callback replicate([node()]) :: :ok

  @doc """
  Returns function that should be called on process which monitors *data layer*.
  """
  @callback crash_handler(pid()) :: function()
end

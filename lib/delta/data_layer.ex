defmodule Delta.DataLayer do
  @moduledoc """
  Behaviour of Delta Data Layers.

  *Data layer* is a GenServer isolating all reads, writes and deletes to a certain entites associated with document.
  Each instance is expected to control its uniuqe portion of data.
  """

  @typedoc """
  Identifier for layer instance, canbe either `pid()` of DataLayer process, `Delta.uuid4()` of document (or `Delta.Document.t()`, from which the id will be extracted)
  """
  @type layer_id :: pid() | Delta.uuid4() | Delta.Document.t()

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
  @callback graceful_stop(layer_id()) :: :ok

  @doc """
  Reads data from instance of *data layer*.
  """
  @callback read(layer_id(), any()) :: {:atomic, any()} | {:aborted, any()}

  @doc """
  Writes data to instance of *data layer*.
  """
  @callback write(layer_id(), any()) :: :ok | {:atomic, any()} | {:aborted, any()}

  @doc """
  Asks *data layer* to free some memory.
  """
  @callback dump(layer_id()) :: :ok

  @doc """
  Deletes data from instance of *data layer*.
  """
  @callback delete(layer_id(), any()) :: :ok | {:atomic, any()} | {:aborted, any()}

  @doc """
  Returns true if data on particular *data layer* exists.
  """

  @callback exists?(layer_id(), any()) :: boolean()

  @doc """
  Performs all required actions for *data layer* to be available on all nodes in list.
  """
  @callback replicate([node()]) :: :ok

  @doc """
  Returns function that should be called on process which monitors *data layer*.
  """
  @callback crash_handler(layer_id()) :: function()
end

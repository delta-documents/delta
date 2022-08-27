defmodule Delta.DataLayer do
  @moduledoc """
  Behaviour of Delta Data Layers.

  *Data layer* is a GenServer, managing operations with entites associated with document.
  Each instance is expected to:
    - control its uniuqe portion of data.
    - join Swarm group `Delta.DataLayer` for proper layer_id form resolution.
  """

  @typedoc """
  Identifier for layer instance, can be one of:
    - `{module(), Delta.uuid4()}`, where `module()` is data layer module (normal form)
    - `pid()` of data layer process
    - `{module(), Delta.Document.t()}` – same as normal form, but id will be extracted from a document.

  Note that any `Delta.uuid4()` is valid id in type context, in other words, there is no checks if document exists to be performed.
  """
  @type layer_id :: {module(), Delta.uuid4()} | pid() | {module(), Delta.Document.t()}

  @typedoc """
  Specifies operation continuation on another data layer. Is executed on data layer with `layer_id`.
  """
  @type continuation :: (layer_id() -> any()) | nil

  @doc """
  Starts *data layer* for isolating any data related to document.
  """
  @callback start_link(document_id :: Delta.Document.t() | Delta.uuid4(), opts :: keyword()) ::
              {:ok, pid} | {:error, any()}

  @doc """
  Returns function that should be called on process which monitors *data layer*.
  """
  @callback crash_handler(any()) :: fun()

  @doc """
  Runs continuation on *data layer*.
  """
  @callback continue(layer_id(), continuation()) :: any()

  @doc """
  Runs continuation on data layer with `layer_id`.
  """
  @spec continue(layer_id(), continuation()) :: any()
  def continue(_, nil), do: nil

  def continue(layer_id, continuation) do
    {m, _} = layer_id_normal(layer_id)

    m.continue(layer_id, continuation)
  end

  @doc """
  Converts `layer_id` to pid form.
  """
  @spec layer_id_pid(layer_id()) :: pid()
  def layer_id_pid(pid) when is_pid(pid), do: pid
  def layer_id_pid({mod, %Delta.Document{id: id}}), do: layer_id_pid({mod, id})
  def layer_id_pid({_mod, _id} = layer_id), do: Swarm.whereis_name(layer_id)

  @doc """
  Converts `layer_id` to normal form.
  """
  @spec layer_id_normal(layer_id()) :: layer_id()
  def layer_id_normal({mod, %Delta.Document{id: id}}), do: {mod, id}
  def layer_id_normal({_mod, _id} = layer_id), do: layer_id

  def layer_id_normal(pid) when is_pid(pid) do
    {name, _} =
      __MODULE__
      |> Swarm.members()
      |> Enum.find(fn {_, p} -> p == pid end)

    name
  end
end

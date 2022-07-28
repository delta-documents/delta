defmodule Delta.Event do
  defstruct [:kind, :value]

  def subscribe(entity, match \\ :everything), do: Phoenix.PubSub.subscribe(Delta.Event.PubSub, entity, metadata: match)
  def unsubscribe(entity), do: Phoenix.PubSub.unsubscribe(Delta.Event.PubSub, entity)

  def broadcast_from(entity, kind, value), do: broadcast_from(entity, %__MODULE__{kind: kind, value: value})
  def broadcast_from(entity, %__MODULE__{} = message), do: Phoenix.PubSub.broadcast_from(Delta.Event.PubSub, self(), entity, message, Delta.Event.Dispatcher)

  def broadcast(entity, kind, value), do: broadcast(entity, %__MODULE__{kind: kind, value: value})
  def broadcast(entity, %__MODULE__{} = message), do: Phoenix.PubSub.broadcast(Delta.Event.PubSub, entity, message, Delta.Event.Dispatcher)
end

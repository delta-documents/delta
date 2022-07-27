defmodule Delta.Event do
  defstruct [:kind, :value]

  defmodule Subscription do
    defstruct [:subscriber_pid, :match]
  end
end

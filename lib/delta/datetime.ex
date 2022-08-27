defmodule Delta.Datetime do
  def now(), do: DateTime.now(Application.get_env(:delta, :timezone, "Etc/UTC"))
end

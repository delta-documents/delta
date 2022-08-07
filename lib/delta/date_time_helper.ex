defmodule Delta.DateTimeHelper do
  def now(), do: Application.get_env(Delta, :timezone, "Etc/UTC") |> DateTime.now()
end

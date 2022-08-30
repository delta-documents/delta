defmodule Delta.Datetime do
  @moduledoc """
  Helpers for working with `DateTime`
  """

  @spec now(Calendar.time_zone()) ::
          {:error, :time_zone_not_found | :utc_only_time_zone_database} | {:ok, DateTime.t()}
  @doc """
  Returns `DateTime` in configured timezone.
  By default it is `"Etc/UTC"`
  """
  def now(default_tz \\ "Etc/UTC"), do: DateTime.now(Application.get_env(:delta, :timezone, default_tz))

  @spec now!(Calendar.time_zone()) :: DateTime.t()
  def now!(default_tz \\ "Etc/UTC"), do: DateTime.now!(Application.get_env(:delta, :timezone, default_tz))
end

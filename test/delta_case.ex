defmodule DeltaTest.Case do
  use ExUnit.CaseTemplate

  setup do
    on_exit(&clear/0)
  end

  def clear() do
    :mnesia.clear_table(Delta.Collection)
    :mnesia.clear_table(Delta.Document)
    :mnesia.clear_table(Delta.Change)
  end
end

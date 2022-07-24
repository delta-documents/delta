defmodule MnesiaTestHelper do
  defmacro __using__(_) do
    quote do
      setup do
        on_exit(&MnesiaTestHelper.clear/0)
      end
    end
  end

  def clear() do
    :mnesia.clear_table(Delta.Collection)
    :mnesia.clear_table(Delta.Document)
    :mnesia.clear_table(Delta.Change)
  end
end

defmodule Delta.Cache do
  @type t :: [opts]

  @type opts :: {:strategy, strategy()} | {:nodes, [node()]}
  @type strategy :: {:timer, secodns()} | {:memory_limit, bytes()} | {:write_on_memory_limit, percentage()}

  @type secodns :: non_neg_integer()
  @type bytes :: non_neg_integer()
  @type percentage :: non_neg_integer()

  def defaults(opts \\ []) do
    nodes = Keyword.get(opts, :nodes, [node()])
    strategy = Keyword.get(opts, :strategy, [])

    timer = Keyword.get(strategy, :timer, 5)
    bytes = Keyword.get(strategy, :memory_limit, 1 * 1024 * 1024 * 1024)
    write_on_memory_limit = Keyword.get(strategy, :write_on_memory_limit, 50)

    [nodes: nodes, strategy: [timer: timer, bytes: bytes, write_on_memory_limit: write_on_memory_limit]]
  end

  def get_env(), do: Application.get_env(Delta, :cache, []) |> defaults()
end

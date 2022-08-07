defmodule Delta.Cache do
  use DynamicSupervisor

  @type opts :: [{:strategy, strategy()} | {:nodes, [node()]}]
  @type strategy :: {:timer, milliseconds :: non_neg_integer()} | {:memory_limit, bytes :: non_neg_integer()} | {:dump_on_memory_limit, percentage :: non_neg_integer()}

  @type cache_id :: String.t() | atom()

  @default_args strategy: :one_for_one

  def start_link(init_args \\ []) do
    DynamicSupervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(args) do
    @default_args
    |> Keyword.merge(args)
    |> DynamicSupervisor.init()
  end

  def create(mod, cache_id, opts \\ []), do: start_child(mod, cache_id, opts)

  def start_child(mod, cache_id, opts \\ []) do
    DynamicSupervisor.start_child(__MODULE__, {mod, [cache_id, get_env() |> Keyword.merge(opts)]})
  end

  def defaults(opts \\ []) do
    [
      nodes: [node()],
      change: [
        write_timeout: 5_000,
        memcheck_timeout: 5_000,
        memory_limit: 8 * 1024 * 1024,
        dump_on_memory_limit: 50
      ],
      document: [
        write_timeout: 5_000,
        memcheck_timeout: 5_000,
        memory_limit: 16 * 1024 * 1024,
      ],
      system: [
        memcheck_timeout: 1_000,
        memory_limit: 1 * 1024 * 1024 * 1024
      ]
    ]
    |> Keyword.merge(opts)
  end

  def get_env(), do: Application.get_env(Delta, :cache, []) |> defaults()
end

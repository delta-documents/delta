defmodule Delta do
  @moduledoc """
  Delta Elixir API

  ## Configuration

  Delta uses MongoDB for persistence and Mnesia for caching.

  To configure Mnesia storage, add the following to your config:

  ```elixir
  config :mnesia, dir: './data/\#{config_env()}/\#{node()}'
  ```

  Note that the `:dir` is charlist, not a string.
  If directory does not exist, it will be created.

  To configure MongoDB connection params, set the `:mongo_params` key in your config:

  ```elixir
  config :delta, :mongo_params, [
    database: "delta_\#{config_env()}",
    hostname: "localhost",
    port: 27017
  ]
  ```

  More information on MongoDB connection params can be found in the [mongodb-driver docs](https://hexdocs.pm/mongodb_driver/Mongo.html#start_link/1)
  """

  @type uuid4() :: bitstring()
end

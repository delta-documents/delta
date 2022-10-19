import Config

config :mnesia, dir: './data/#{config_env()}/#{node()}'

config :delta, :mongo_params, [
  database: "delta_#{config_env()}",
  hostname: "localhost",
  port: 27017
]

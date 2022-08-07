import Config

config :mnesia, dir: './data/#{config_env()}/#{node()}'

import_config "#{config_env()}.exs"

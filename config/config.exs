import Config

config :mnesia, dir: './data/#{node()}'

import_config "#{config_env()}.exs"

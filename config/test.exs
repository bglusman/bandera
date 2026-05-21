import Config

config :bandera, start_on_boot: false

config :bandera, Bandera.TestRepo,
  database: Path.expand("../bandera_test.db", __DIR__),
  pool_size: 1

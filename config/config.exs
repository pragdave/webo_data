use Mix.Config

config :webo_data, Webo.Data.InfluxConnection,
        database:  "webo",
        host:      "localhost",
        http_opts: [insecure: true],
        pool:      [max_overflow: 10, size: 50],
        port:      8086,
        scheme:    "http",
        writer:    Instream.Writer.Line

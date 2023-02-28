import Config

nerves_hub_app = System.get_env("NERVES_HUB_APP")

config :nerves_hub_www, app: nerves_hub_app

logger_level = System.get_env("LOG_LEVEL", "info") |> String.to_atom()

config :logger, level: logger_level

host = System.fetch_env!("HOST")
port = 80

sync_nodes_optional =
  case System.fetch_env("SYNC_NODES_OPTIONAL") do
    {:ok, sync_nodes_optional} ->
      sync_nodes_optional
      |> String.split(" ", trim: true)
      |> Enum.map(&String.to_atom/1)

    :error ->
      []
  end

config :kernel,
  sync_nodes_optional: sync_nodes_optional,
  sync_nodes_timeout: 5000,
  inet_dist_listen_min: 9100,
  inet_dist_listen_max: 9155

config :nerves_hub_www, NervesHub.Firmwares.Upload.S3, bucket: System.fetch_env!("S3_BUCKET_NAME")

config :nerves_hub_www, NervesHub.Workers.FirmwaresTransferS3Ingress,
  bucket: System.fetch_env!("S3_LOG_BUCKET_NAME")

config :ex_aws, region: System.fetch_env!("AWS_REGION")

config :nerves_hub_www, NervesHub.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: System.fetch_env!("SES_SERVER"),
  port: System.fetch_env!("SES_PORT"),
  username: System.fetch_env!("SMTP_USERNAME"),
  password: System.fetch_env!("SMTP_PASSWORD")

config :nerves_hub_www,
  host: host,
  port: port,
  from_email: System.get_env("FROM_EMAIL", "no-reply@nerves-hub.org"),
  allow_signups?: System.get_env("ALLOW_SIGNUPS", "false") |> String.to_atom()

config :nerves_hub_www, NervesHub.Tracer, env: System.get_env("DD_ENV") || "dev"

if nerves_hub_app == "web" do
  config :nerves_hub_www, NervesHubWeb.Endpoint,
    url: [host: host, port: port],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
    live_view: [signing_salt: System.fetch_env!("LIVE_VIEW_SIGNING_SALT")]
end

if nerves_hub_app == "device" do
  config :nerves_hub_www, NervesHubWeb.DeviceEndpoint,
    url: [host: host],
    https: [
      port: 443,
      otp_app: :nerves_hub_www,
      # Enable client SSL
      # Older versions of OTP 25 may break using using devices
      # that support TLS 1.3 or 1.2 negotiation. To mitigate that
      # potential error, we enforce TLS 1.2. If you're using OTP >= 25.1
      # on all devices, then it is safe to allow TLS 1.3 by removing
      # the versions constraint and setting `certificate_authorities: false`
      # since we don't expect devices to send full chains to the server
      # See https://github.com/erlang/otp/issues/6492#issuecomment-1323874205
      #
      # certificate_authorities: false,
      verify: :verify_peer,
      fail_if_no_peer_cert: true,
      keyfile: "/etc/ssl/#{host}-key.pem",
      certfile: "/etc/ssl/#{host}.pem",
      cacertfile: "/etc/ssl/ca.pem"
    ]
end

if nerves_hub_app == "api" do
  cacert_pems = [
    "/etc/ssl/user-root-ca.pem",
    "/etc/ssl/root-ca.pem"
  ]

  cacerts =
    cacert_pems
    |> Enum.map(&File.read!/1)
    |> Enum.map(&X509.Certificate.from_pem!/1)
    |> Enum.map(&X509.Certificate.to_der/1)

  config :nerves_hub_www, NervesHubWeb.API.Endpoint,
    url: [host: host],
    https: [
      port: 443,
      otp_app: :nerves_hub_www,
      # Enable client SSL
      verify: :verify_peer,
      keyfile: "/etc/ssl/#{host}-key.pem",
      certfile: "/etc/ssl/#{host}.pem",
      cacerts: cacerts ++ :certifi.cacerts()
    ]

  ca_host = System.fetch_env!("CA_HOST")

  config :nerves_hub_www, NervesHub.CertificateAuthority,
    host: ca_host,
    port: 8443,
    ssl: [
      keyfile: "/etc/ssl/#{host}-key.pem",
      certfile: "/etc/ssl/#{host}.pem",
      cacertfile: "/etc/ssl/ca.pem"
    ]
end
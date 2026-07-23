# OpenBao — configuración modo PRODUCCIÓN (no `-dev`).
# Mismo archivo en dev y prod; lo que cambia por entorno son los certs TLS
# (./openbao/tls/) y los secretos, no esta config.

ui = true

# Integrated Storage (Raft) — persistente, sin dependencias externas.
# Path = /openbao/file: ya existe en la imagen owned por openbao:100, así el
# named volume hereda ese ownership al inicializarse. El mlock queda activo
# gracias al cap IPC_LOCK del compose.
storage "raft" {
  path    = "/openbao/file"
  node_id = "cak-openbao-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_cert_file   = "/openbao/tls/openbao.crt"
  tls_key_file    = "/openbao/tls/openbao.key"
  tls_min_version = "tls13"

  # Permite que Prometheus scrapee /v1/sys/metrics sin token (solo métricas).
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Dentro de la red Docker se llega por el hostname del servicio: openbao.
api_addr     = "https://openbao:8200"
cluster_addr = "https://openbao:8201"

# Métricas Prometheus nativas (sin exporter aparte).
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}

#!/bin/bash
# docker-CodeAlkimia — levanta el entorno de desarrollo local
#
# Uso:
#   ./scripts/dev-up.sh                    # levanta TODOS los servicios
#   ./scripts/dev-up.sh postgres seaweedfs # levanta solo los indicados
#
# Desde la raíz del repo docker-codealkimia.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker no está corriendo."
    exit 1
fi

echo "🚀 Levantando entorno docker-CodeAlkimia desde: $ROOT_DIR"

# Config de infra: si no existe `.env`, se crea desde dev.env (compose lo auto-lee).
# Para prod: `cp prod.env .env` con los valores reales (prod.env está gitignored).
if [ ! -f "$ROOT_DIR/.env" ]; then
    cp "$ROOT_DIR/dev.env" "$ROOT_DIR/.env"
    echo "📋 Creado .env desde dev.env (config de dev)."
fi

# OpenBao (modo prod): cert TLS self-signed para dev + dir de secrets.
"$ROOT_DIR/openbao/gen-tls.sh"
mkdir -p "$ROOT_DIR/openbao/.secrets"

# Cache del contenedor de build, owned por el usuario del host.
mkdir -p "$ROOT_DIR/node-cache"

if [ "$#" -gt 0 ]; then
    docker compose up -d "$@"
else
    docker compose up -d
fi

echo ""
echo "⏳ Esperando healthchecks..."
sleep 3
docker compose ps

# OpenBao: bootstrap idempotente (init/unseal + transit + claves + kv-v2 + AppRole).
if docker ps --format '{{.Names}}' | grep -q '^cak-openbao$'; then
    echo ""
    echo "🔐 Esperando a que OpenBao responda y corriendo bootstrap..."
    for _ in $(seq 1 30); do
        docker exec cak-openbao sh -c 'bao status 2>&1 | grep -q Sealed' && break
        sleep 2
    done
    docker exec cak-openbao sh /openbao/bootstrap.sh || echo "⚠️  Bootstrap de OpenBao falló (revisar 'docker logs cak-openbao')."
fi

cat <<'EOF'

🎉 Entorno listo. Endpoints expuestos:

  Datos
    PostgreSQL ........... localhost:5432   (cak_user / password / db: codealkimia)
    SeaweedFS S3 ......... http://localhost:8333   (cak-dev-key / cak-dev-secret)

  Secrets + KMS
    OpenBao .............. https://localhost:8200  (Raft+TLS; AppRole en openbao/.secrets/cak-core.env)

  Build
    cak-node ............. container idle, listo para `make build`

  Observabilidad
    Prometheus ........... http://localhost:9090
    Grafana .............. http://localhost:3000   (admin / admin)
    Alertmanager ......... http://localhost:9093
    Mailpit .............. http://localhost:8025   (bandeja de alertas en dev)
    cAdvisor ............. http://localhost:8081   (uso por contenedor)

📋 Comandos útiles:
  make ps / make logs                  # estado y logs
  make unseal                          # desella OpenBao si se reinició el container (DEV)
  ./scripts/dev-down.sh                # apagar todo (mantiene datos)

EOF

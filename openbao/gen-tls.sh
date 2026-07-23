#!/usr/bin/env bash
# Genera un certificado self-signed para el listener TLS de OpenBao (SOLO dev).
# Idempotente: si ya existe, no lo regenera. En producción el operador provee
# certs reales en este mismo path (./openbao/tls/), y este script no se usa.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tls"
mkdir -p "$DIR"

if [ -f "$DIR/openbao.crt" ] && [ -f "$DIR/openbao.key" ]; then
    echo "✅ TLS de OpenBao ya existe en $DIR (no regenero)."
    exit 0
fi

echo "🔐 Generando cert self-signed para OpenBao (dev)..."
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$DIR/openbao.key" -out "$DIR/openbao.crt" \
    -days 3650 -subj "/CN=openbao" \
    -addext "subjectAltName=DNS:openbao,DNS:localhost,IP:127.0.0.1" 2>/dev/null

chmod 644 "$DIR/openbao.crt"
chmod 640 "$DIR/openbao.key"
echo "✅ Cert generado en $DIR (gitignored). La app monta openbao.crt como CA de confianza."

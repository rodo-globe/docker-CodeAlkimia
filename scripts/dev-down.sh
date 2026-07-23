#!/bin/bash
# docker-CodeAlkimia — apaga el entorno de desarrollo local
#
# Uso:
#   ./scripts/dev-down.sh        # apaga los containers, mantiene volúmenes
#   ./scripts/dev-down.sh --wipe # apaga y BORRA volúmenes (datos persistidos)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ "${1:-}" = "--wipe" ]; then
    echo "⚠️  Apagando containers y BORRANDO volúmenes..."
    docker compose down -v
    echo "✅ Entorno limpio. Próximo dev-up.sh arranca de cero."
else
    echo "🛑 Apagando containers (volúmenes preservados)..."
    docker compose down
    echo "✅ Entorno detenido. Datos persistidos en volúmenes."
fi

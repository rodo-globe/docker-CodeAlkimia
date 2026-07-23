#!/bin/sh
# Desella OpenBao en DEV leyendo la unseal key de .secrets/init.json (gitignored).
# Corre dentro del container: docker exec cak-openbao sh /openbao/unseal.sh
#
# Idempotente: si no está inicializado o ya está desellado, no hace nada.
#
# Por qué existe: OpenBao en modo Raft+Shamir arranca SELLADO tras cada restart
# del container. dev-up.sh lo desella en el bring-up completo (vía bootstrap.sh);
# si solo se reinició el container, el atajo es `make unseal`.
#
# DEV ÚNICAMENTE. En PROD el unseal lo hace OpenBao solo vía el bloque `seal`
# del config (auto-unseal contra KMS de nube / HSM). Ver CodeAlkimia/docs/06 §3.
set -e

export BAO_ADDR="https://127.0.0.1:8200"
export BAO_SKIP_VERIFY="true"
INIT_FILE=/openbao/.secrets/init.json

if ! bao status 2>/dev/null | grep -q 'Initialized.*true'; then
    echo "⚠️  OpenBao no está inicializado. Corré 'make up' (dev-up.sh) primero."
    exit 0
fi

if bao status 2>/dev/null | grep -q 'Sealed.*false'; then
    echo "✅ OpenBao ya está desellado — nada que hacer."
    exit 0
fi

if [ ! -f "$INIT_FILE" ]; then
    echo "❌ No encuentro $INIT_FILE (la unseal key de dev). ¿Se borró openbao/.secrets?"
    echo "   Si se perdieron las keys, hay que re-inicializar: make down-wipe && make up."
    exit 1
fi

UNSEAL_KEY=$(tr -d '\n' < "$INIT_FILE" | sed -n 's/.*"unseal_keys_b64": *\[ *"\([^"]*\)".*/\1/p')
echo "🔓 Unsealing OpenBao..."
bao operator unseal "$UNSEAL_KEY" >/dev/null

if bao status 2>/dev/null | grep -q 'Sealed.*false'; then
    echo "✅ OpenBao desellado."
else
    echo "❌ OpenBao sigue sellado (revisar 'docker logs cak-openbao')."
    exit 1
fi

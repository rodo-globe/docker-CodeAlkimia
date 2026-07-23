#!/bin/sh
# Bootstrap de OpenBao — IDEMPOTENTE. Corre dentro del container (CLI `bao`).
# Primera vez: inicializa (Raft) y stashea unseal-key + root-token. Siempre:
# desella y asegura transit + claves + kv-v2 + policy + AppRole del core.
#
# DEV: los secretos (init.json, cak-core.env) quedan en /openbao/.secrets (gitignored).
# PROD: el operador inyecta unseal-key y secret-id; este script NO los deja en disco.
set -e

export BAO_ADDR="https://127.0.0.1:8200"
export BAO_SKIP_VERIFY="true"          # cert self-signed, conexión local del propio container

SECRETS=/openbao/.secrets
INIT_FILE="$SECRETS/init.json"
APPROLE_FILE="$SECRETS/cak-core.env"
mkdir -p "$SECRETS"

# 1) Init (solo la primera vez)
if ! bao status 2>/dev/null | grep -q 'Initialized.*true'; then
    echo "⏳ Inicializando OpenBao (Raft, 1 unseal key para dev)..."
    bao operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_FILE"
    echo "✅ Inicializado. Unseal key + root token en $INIT_FILE (DEV — gitignored)."
fi

RAW=$(tr -d '\n' < "$INIT_FILE")
UNSEAL_KEY=$(printf '%s' "$RAW" | sed -n 's/.*"unseal_keys_b64": *\[ *"\([^"]*\)".*/\1/p')
ROOT_TOKEN=$(printf '%s' "$RAW" | sed -n 's/.*"root_token": *"\([^"]*\)".*/\1/p')

# 2) Unseal (cada arranque; con Raft + Shamir hay que desellar tras cada restart)
if bao status 2>/dev/null | grep -q 'Sealed.*true'; then
    echo "🔓 Unsealing..."
    bao operator unseal "$UNSEAL_KEY" >/dev/null
fi

export BAO_TOKEN="$ROOT_TOKEN"

# 3) transit: clave de firma del ledger (anclas + evidencia) y master key (envelope)
bao secrets list -format=json 2>/dev/null | grep -q '"transit/"' || bao secrets enable transit
bao read transit/keys/cak-ledger-anchor >/dev/null 2>&1 || bao write -f transit/keys/cak-ledger-anchor type=ed25519
bao read transit/keys/cak-master-key    >/dev/null 2>&1 || bao write -f transit/keys/cak-master-key type=aes256-gcm96

# 4) kv-v2 (secret manager) en path secret/ — secretos de la app y claves BYOK
bao secrets list -format=json 2>/dev/null | grep -q '"secret/"' || bao secrets enable -path=secret kv-v2

# 5) policy + AppRole del core (auth sin root token)
bao policy write cak-core /openbao/policies/cak-core.hcl
bao auth list -format=json 2>/dev/null | grep -q '"approle/"' || bao auth enable approle
bao write auth/approle/role/cak-core \
    token_policies=cak-core token_ttl=1h token_max_ttl=4h secret_id_ttl=0

ROLE_ID=$(bao read -field=role_id auth/approle/role/cak-core/role-id)
SECRET_ID=$(bao write -f -field=secret_id auth/approle/role/cak-core/secret-id)
cat > "$APPROLE_FILE" <<EOF
CAK_OPENBAO_ROLE_ID=$ROLE_ID
CAK_OPENBAO_SECRET_ID=$SECRET_ID
EOF

echo "✅ Bootstrap OK: transit + cak-ledger-anchor (ed25519) + cak-master-key + kv-v2 + policy + AppRole."
echo "   AppRole creds (DEV) en $APPROLE_FILE."

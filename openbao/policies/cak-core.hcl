# Policy del core de CodeAlkimia: accesos mínimos (no root).
# El token AppRole del core la usa. Los runners NUNCA tienen credenciales
# de OpenBao (doc 06 §2).

# --- Firma del ledger: anclas y evidencia (doc 04 §6, doc 03 §6.2) ---
path "transit/sign/cak-ledger-anchor" {
  capabilities = ["update"]
}
path "transit/verify/cak-ledger-anchor" {
  capabilities = ["update"]
}

# --- Envelope encryption (si se cifra en reposo a nivel de campo/blob) ---
path "transit/datakey/plaintext/cak-master-key" {
  capabilities = ["create", "update"]
}
path "transit/encrypt/cak-master-key" {
  capabilities = ["update"]
}
path "transit/decrypt/cak-master-key" {
  capabilities = ["update"]
}

# --- Secret Manager (kv-v2): secretos de la app y claves BYOK por tenant/proyecto ---
# El core administra las claves de proveedores de IA (alta, rotación, baja);
# la capa de proveedor las lee para inyectarlas server-side (doc 06 §3).
path "secret/data/cak/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/cak/*" {
  capabilities = ["read", "delete", "list"]
}

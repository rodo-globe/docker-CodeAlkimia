# docker-CodeAlkimia

Entorno de desarrollo local e infraestructura de despliegue contenedorizada para **CodeAlkimia** (repo de aplicación: [`CodeAlkimia`](https://github.com/rodo-globe/CodeAlkimia)).

## Filosofía

- **En el host solo Docker**: build, tests y ejecución ocurren en contenedores. Los comandos viven en el `Makefile` (`make help`).
- **Un container por componente** de infraestructura, con healthchecks y volúmenes nombrados.
- **El compose es el artefacto**: el mismo entorno sirve para desarrollo y despliegue; entre entornos cambian certificados y secretos, nunca el mecanismo.
- **Configs bind-monteados**: tras editar uno, `docker compose restart <servicio>` — los editores atómicos cambian el inode y el hot-reload puede mentir.

> **Convivencia con MTF**: ambos stacks usan los puertos estándar (5432, 8200, 9090, 3000…). En una misma máquina corren **de a uno por vez**.

## Estructura

```
docker-codealkimia/
├── docker-compose.yml     # todos los servicios (ver abajo)
├── dev.env                # valores de desarrollo; dev-up.sh los copia a .env
├── Makefile               # targets de entorno, build y utilidades
├── scripts/               # dev-up.sh (bootstrap incluido) / dev-down.sh [--wipe]
├── openbao/               # config.hcl (Raft+TLS), bootstrap.sh, unseal.sh, gen-tls.sh, policies/
├── seaweedfs/             # s3.json (identidades S3; en prod lo reemplaza el operador)
├── prometheus/            # prometheus.yml (scrape) + alert-rules.yml (alertas)
├── alertmanager/          # ruteo de alertas (email → Mailpit en dev)
├── grafana/               # provisioning (datasource + dashboards) y tableros JSON
└── spikes/                # experimentos con evidencia reproducible (seaweedfs/)
```

## Servicios

| Servicio | Imagen | Puerto | Rol |
|---|---|---|---|
| postgres | postgres:17-alpine | 5432 | Base primaria: dominio, ledger, cola pg-boss (`cak_user`/`password`, db `codealkimia`) |
| seaweedfs | chrislusf/seaweedfs:4.39 | 8333 | Object storage S3 (blobs); métricas nativas en :9324 |
| openbao | openbao/openbao:2.6.0 | 8200 | Bóveda de secretos + firma del ledger (Raft + TLS 1.3, **HTTPS**) |
| prometheus | prom/prometheus:v3.0.1 | 9090 | Métricas y evaluación de alertas |
| alertmanager | prom/alertmanager:v0.28.0 | 9093 | Agrupa, inhibe y rutea alertas |
| mailpit | axllent/mailpit:v1.30.5 | 8025 / 1025 | Bandeja de correo de dev (alertas; luego harness y consola) |
| grafana | grafana/grafana:11.4.0 | 3000 | Tableros aprovisionados desde archivo (`admin`/`admin`) |
| postgres-exporter | prometheuscommunity/postgres-exporter | 9187 | Métricas de Postgres (`pg_up`) |
| node-exporter | prom/node-exporter:v1.12.1 | 9100 | Métricas del host (CPU/RAM/disco/red) |
| cadvisor | gcr.io/cadvisor/cadvisor:v0.55.1 | 8081 | Uso por contenedor |
| cak-node | node:22-bookworm | — | Contenedor de build del monorepo (idle; `make build`) |

## Uso

```bash
make up          # levanta todo + bootstrap idempotente de OpenBao
make ps          # estado (todo "(healthy)")
make build       # build del monorepo en cak-node (placeholder hasta US-002)
make unseal      # desella OpenBao tras un reinicio del container (DEV)
make down        # apaga manteniendo datos
make down-wipe   # apaga y borra volúmenes
```

Tras `make up`, los secretos de desarrollo de OpenBao quedan en `openbao/.secrets/` (gitignored): `init.json` (unseal key + root token) y `cak-core.env` (AppRole de la aplicación).

## Convenciones

- **Sin secretos reales en este repo** — las credenciales de acá son de desarrollo. En producción los secretos viven en OpenBao y los certificados los provee el operador.
- Versiones de imágenes **pinneadas**; healthchecks en todos los servicios en línea; volúmenes nombrados.
- La documentación de arquitectura y decisiones vive en el repo de aplicación: [`docs/`](https://github.com/rodo-globe/CodeAlkimia/tree/main/docs) (en particular `04-arquitectura.md` y `anexo-aprovechamiento-mtf.md`).

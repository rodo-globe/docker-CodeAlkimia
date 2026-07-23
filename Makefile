# =============================================================================
# Makefile — docker-CodeAlkimia
#
# Orquesta el entorno de desarrollo y los builds del monorepo CodeAlkimia.
# Política del proyecto: en el host solo Docker; build, tests y runtime
# pasan por containers.
# =============================================================================

.PHONY: help up down down-wipe ps logs unseal \
        build install arch test typecheck shell-node

COMPOSE := docker compose

# Los builds corren como el uid/gid del host para que node_modules y artefactos
# queden owned por el usuario, no por root. HOME=/tmp evita depender del home
# de root; pnpm se invoca vía corepack (cache en ./node-cache, bind del host).
NODE := docker exec -u $(shell id -u):$(shell id -g) -e HOME=/tmp cak-node

help:
	@echo "Makefile docker-CodeAlkimia — comandos disponibles:"
	@echo ""
	@echo "Entorno:"
	@echo "  make up               Levanta postgres, seaweedfs, openbao, observabilidad y cak-node"
	@echo "  make down             Apaga todos los services (mantiene datos)"
	@echo "  make down-wipe        Apaga y borra volúmenes (¡pierde datos!)"
	@echo "  make ps               Estado de los services"
	@echo "  make logs             Logs en vivo de todos los services"
	@echo "  make unseal           Desella OpenBao tras un restart del container (DEV)"
	@echo ""
	@echo "Build del monorepo (corre dentro de cak-node):"
	@echo "  make install          pnpm install"
	@echo "  make build            arquitectura (dependency-cruiser) + build de todos los paquetes"
	@echo "  make arch             solo la verificación de arquitectura"
	@echo "  make test             tests (Vitest) de todos los paquetes"
	@echo "  make typecheck        tsc --noEmit de todos los paquetes"
	@echo ""
	@echo "Shells de utilidad:"
	@echo "  make shell-node       Shell en el container cak-node"

# -----------------------------------------------------------------------------
# Entorno
# -----------------------------------------------------------------------------

up:
	@./scripts/dev-up.sh

down:
	@./scripts/dev-down.sh

down-wipe:
	@./scripts/dev-down.sh --wipe

ps:
	@$(COMPOSE) ps

logs:
	@$(COMPOSE) logs -f

# Desella OpenBao tras un restart del container (arranca sellado en Raft+Shamir).
# Sólo DEV: lee la unseal key de openbao/.secrets/init.json. En prod lo hace el
# seal stanza (KMS/HSM). Ver CodeAlkimia/docs/06-seguridad.md §3.
unseal:
	@docker exec cak-openbao sh /openbao/unseal.sh

# -----------------------------------------------------------------------------
# Build del monorepo (en container cak-node; pnpm vía corepack, versión fijada
# por el packageManager del package.json raíz)
# -----------------------------------------------------------------------------

install:
	@$(NODE) pnpm install

# `pnpm run build` = verificación de arquitectura (dependency-cruiser) + build
# de todos los paquetes. Una violación de límites ROMPE el build.
build:
	@$(NODE) sh -c 'pnpm install && pnpm run build'

arch:
	@$(NODE) pnpm run arch

test:
	@$(NODE) sh -c 'CI=1 pnpm run test'

typecheck:
	@$(NODE) pnpm run typecheck

# -----------------------------------------------------------------------------
# Runtime de desarrollo (dentro de cak-node)
# -----------------------------------------------------------------------------

# Arranca el core: migraciones como owner, app como cak_app (RLS aplica)
run-core:
	@docker exec -d -u $(shell id -u):$(shell id -g) -e HOME=/tmp \
		-e CAK_DATABASE_URL=postgresql://cak_app:app_password@postgres:5432/codealkimia \
		-e CAK_OWNER_DATABASE_URL=postgresql://cak_user:password@postgres:5432/codealkimia \
		cak-node sh -c 'cd core && node dist/main.js'
	@echo "cak-core arrancando en :3001 (interno). Logs: docker exec cak-node sh -c 'true' — usar make stop-core para detener."

# Sirve la consola en http://<host>:4200 (proxy /api → core :3001)
serve-console:
	@docker exec -d -u $(shell id -u):$(shell id -g) -e HOME=/tmp \
		cak-node sh -c 'cd console && node_modules/.bin/ng serve --host 0.0.0.0 --port 4200'
	@echo "Consola sirviéndose en http://localhost:4200 (o http://macpro:4200)."

stop-dev:
	@docker exec -u root cak-node sh -c 'pkill -f "node dist/mai[n].js" || true; pkill -f "ng serv[e]" || true; true'
	@echo "Procesos de desarrollo detenidos."

# -----------------------------------------------------------------------------
# Shells de utilidad
# -----------------------------------------------------------------------------

shell-node:
	@docker exec -it -u $(shell id -u):$(shell id -g) -e HOME=/tmp cak-node bash

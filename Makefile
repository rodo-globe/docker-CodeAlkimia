# =============================================================================
# Makefile — docker-CodeAlkimia
#
# Orquesta el entorno de desarrollo y los builds del monorepo CodeAlkimia.
# Política del proyecto: en el host solo Docker; build, tests y runtime
# pasan por containers.
# =============================================================================

.PHONY: help up down down-wipe ps logs unseal \
        build install test shell-node

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
	@echo "  make build            pnpm install + build de todos los paquetes"
	@echo "  make test             pnpm test de todos los paquetes"
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
# Build del monorepo (en container cak-node)
# Mientras el monorepo no exista (llega en US-002), los targets informan el
# estado del contenedor de build y salen limpio.
# -----------------------------------------------------------------------------

install:
	@$(NODE) sh -c 'if [ -f package.json ]; then corepack pnpm install; else echo "placeholder US-002: aun no hay monorepo en /workspace. Contenedor de build OK (node $$(node --version), pnpm $$(corepack pnpm --version))."; fi'

build:
	@$(NODE) sh -c 'if [ -f package.json ]; then corepack pnpm install && corepack pnpm -r build; else echo "placeholder US-002: aun no hay monorepo en /workspace. Contenedor de build OK (node $$(node --version), pnpm $$(corepack pnpm --version))."; fi'

test:
	@$(NODE) sh -c 'if [ -f package.json ]; then corepack pnpm -r test; else echo "placeholder US-002: aun no hay monorepo en /workspace."; fi'

# -----------------------------------------------------------------------------
# Shells de utilidad
# -----------------------------------------------------------------------------

shell-node:
	@docker exec -it -u $(shell id -u):$(shell id -g) -e HOME=/tmp cak-node bash

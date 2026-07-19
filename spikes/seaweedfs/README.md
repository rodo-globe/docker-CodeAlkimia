# Spike: SeaweedFS como object storage on-premise

**Fecha**: 2026-07-19 · **Resultado**: ✅ adoptado (decisión #26 de la bitácora del repo de aplicación)

Valida la cobertura del API S3 de SeaweedFS contra los criterios de `CodeAlkimia/docs/07-stack-y-despliegue.md` §5, usando el AWS SDK for JavaScript v3 (v3.1090) — el mismo cliente que usará el producto.

## Resultados

Versión probada: SeaweedFS 4.39 (`chrislusf/seaweedfs:latest`), modo single-container (`server -s3`) con autenticación por `s3.config`.

| Criterio | Resultado |
|---|---|
| PUT/GET/Range GET básicos | ✅ |
| URL prefirmada GET | ✅ |
| URL prefirmada PUT (roundtrip verificado) | ✅ * |
| URL prefirmada vencida → rechazada (HTTP 403) | ✅ |
| Multipart upload vía SDK (10 MB) | ✅ |
| Multipart con parte subida por URL prefirmada | ✅ * |
| Versionado (enable + múltiples versiones listadas) | ✅ |
| Lifecycle (PUT/GET de reglas con API estándar S3) | ✅ |
| CORS (PUT/GET de configuración con API estándar) | ✅ |
| 200 archivos de 1 KB secuenciales | ✅ ~1,35 s |
| Footprint en reposo | 268 MiB RAM · imagen 362 MB |
| Licencia | Apache 2.0 (edición comunitaria; todo lo probado corre en ella) |

**\* Nota de implementación obligatoria**: el SDK v3 moderno activa por defecto checksums CRC32 que SeaweedFS rechaza en subidas por URL prefirmada (`BadDigest`). El cliente S3 del producto debe configurarse con:

```js
requestChecksumCalculation: "WHEN_REQUIRED",
responseChecksumValidation: "WHEN_REQUIRED",
```

Con esa configuración, 14/14 criterios pasan.

## Reproducir

```bash
docker network create spike
docker run -d --name seaweedfs --network spike \
  -v $PWD/s3.json:/etc/s3.json \
  chrislusf/seaweedfs:latest server -s3 -s3.config=/etc/s3.json
docker run --rm -v $PWD:/app -w /app node:lts npm install
docker run --rm --network spike -v $PWD:/app -w /app \
  -e S3_ENDPOINT=http://seaweedfs:8333 -e CHECKSUM_MODE=compat \
  node:lts node spike.mjs
docker rm -f seaweedfs && docker network rm spike
```

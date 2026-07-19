# docker-CodeAlkimia

Entorno de desarrollo local e infraestructura de despliegue contenedorizada para **CodeAlkimia** (repo de aplicación: [`CodeAlkimia`](https://github.com/rodo-globe/CodeAlkimia)).

> **Estado**: repo inicial. El entorno se construirá cuando comience la implementación, siguiendo la convención Globe de entornos multi-container.

## Filosofía

- **En el host solo Docker**: ninguna herramienta de base instalada en la máquina de desarrollo; build, tests y ejecución ocurren en contenedores.
- **Un container por componente** de infraestructura, con healthchecks y volúmenes nombrados.
- **El compose es el artefacto**: el mismo entorno contenedorizado sirve para desarrollo y despliegue, cambiando configuración y secretos, nunca el mecanismo.

La arquitectura de referencia y las decisiones de stack están documentadas en el repo de aplicación, [`docs/04-arquitectura.md`](https://github.com/rodo-globe/CodeAlkimia/blob/main/docs/04-arquitectura.md).

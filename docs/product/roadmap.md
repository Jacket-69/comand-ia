# Roadmap — COMAND-IA

> El roadmap vivo (sprints, issues y estado) vive en el **GitHub Projects** del repo (tablero `COMAND-IA — Sprints`). Los [milestones](https://github.com/Jacket-69/comand-ia/milestones) y los [issues `COMA-NNN`](https://github.com/Jacket-69/comand-ia/issues) son la fuente de verdad de qué entra en cada sprint. Este archivo solo fija el norte académico estable, que no cambia sprint a sprint.

## Norte del semestre

| Fecha | Corte | Resultado esperado |
|---|---|---|
| 2026-05-26 | Avance 2 | Capa 1 demoable: login controlado, mesas, toma de pedido offline, sync y KDS básico |
| 2026-07-07 | Defensa final | MVP Capa 1 + Capa 2: operación completa + dashboard owner |

Regla de scope: si un sprint se aprieta, se recorta funcionalidad antes que tests, RLS, documentación o CI.

## Alcance del MVP

Los issues `COMA-NNN` cierran el MVP académico: **Capa 1** (operación) + **Capa 2** (analítica mínima). El detalle por sprint, las prioridades y el estado viven en los milestones y el tablero —no acá— para no desincronizarse.

## Criterio para replanificar

Replanificar si ocurre cualquiera de estos:

- El spike de una dependencia clave supera su time-box sin solución estable.
- Una historia P0 queda bloqueada más de un día.
- La cobertura baja de los mínimos (60% global / 70% dominio).
- Un mockup contradice un flujo del SRS.

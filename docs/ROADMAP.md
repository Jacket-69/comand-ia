# Roadmap — COMAND-IA

Última actualización: 2026-05-02.

## Norte del semestre

| Fecha | Corte | Resultado esperado |
|---|---|---|
| 2026-05-26 | Avance 2 | Capa 1 demoable: login mock/real controlado, mesas, toma de pedido offline, sync y KDS básico |
| 2026-07-07 | Defensa final | MVP Capa 1 + Capa 2: operación completa y dashboard owner |

Regla de scope: si el sprint se aprieta, se recorta funcionalidad antes que tests, RLS, documentación o CI.

## GitHub Projects

Tablero oficial: `COMAND-IA — Sprints`.

Campos mínimos:

| Campo | Uso |
|---|---|
| Status | `Todo`, `In Progress`, `Done` |
| Milestone | Sprint académico donde se espera cerrar |
| Labels | feature, prioridad, tipo de trabajo y sprint |
| Linked pull requests | Evidencia de cierre técnico |

Uso esperado:

- Todo trabajo empieza como issue con prefijo `COMA-NNN`.
- El issue debe tener por qué, story points y criterios de aceptación.
- Una historia `Done` debe tener CI verde, docs actualizadas cuando aplique y link al PR/commit.
- Los issues de documentación y preparación académica también viven en el tablero; no quedan como notas sueltas.

## Roadmap por sprint

| Sprint | Fecha objetivo | Objetivo | Entregables principales |
|---|---|---|---|
| Sprint 1 — Fundación | 2026-05-04 | Base técnica confiable | Flutter scaffold, auth mock, Supabase local, RLS base, spike Drift, vistas base |
| Sprint 2 — Toma de pedido offline | 2026-05-11 | Garzón puede armar pedido sin red | Drift validado, menú local, formulario de pedido, cola `pending_op` |
| Sprint 3 — Sync + KDS realtime | 2026-05-18 | Pedido llega a cocina y cambia estado | Sync FIFO, Supabase realtime, KDS básico, RLS cross-venue hardening |
| Sprint 4 — Estabilización Avance 2 | 2026-05-25 | Demo Capa 1 defendible | flujo completo pulido, errores/empty states, pruebas manuales, guion demo |
| Sprint 5 — Arranque Capa 2 | 2026-06-01 | KPIs owner desde datos reales | RPC dashboard, pantalla owner, cards KPI |
| Sprint 6 — Cierre + CSV | 2026-06-08 | Pedido cerrado y analítica exportable | cierre terminal, método de pago, CSV, filtros temporales |
| Sprint 7 — Hardening UX | 2026-06-15 | Producto estable en dispositivos objetivo | responsive polish, accesibilidad, Sentry, onboarding básico |
| Sprint 8 — Tests faltantes | 2026-06-22 | Reducir riesgo antes del freeze | integration tests críticos, golden tests, cobertura sostenida |
| Sprint 9 — Code freeze | 2026-06-29 | Congelar features | solo bugs P0/P1, video demo, slides v1 |
| Sprint 10 — Defensa | 2026-07-06 | Presentar sin sorpresas | ensayo, checklist final, tag de release |

## Backlog inmediato

| Prioridad | Historia | Resultado |
|---|---|---|
| P0 | Validar Drift en Flutter web | Decidir Drift vs Hive antes de construir offline encima |
| P0 | Implementar toma de pedido offline | Mesa → menú → ítems → total local → cola pendiente |
| P0 | Implementar sync FIFO hacia Supabase | Vaciar `pending_op` al reconectar y reflejar errores |
| P0 | Implementar KDS básico | Cocina ve pedidos `sent/preparing` y marca `ready` |
| P1 | Adaptar UI desde `../comand-ia_vistas` | Layouts responsivos para móvil, tablet y desktop |
| P1 | Dashboard owner inicial | KPIs desde `dashboard_kpis` con filtro de periodo |

## Criterio para replanificar

Replanificar si ocurre cualquiera de estos casos:

- Drift web consume más de 4h efectivas sin prototipo estable.
- Supabase realtime no cumple ≤2s en prueba local/staging.
- Cobertura baja de 60% global o 70% en `domain/`.
- Una historia P0 queda bloqueada más de un día.
- Las vistas Figma/PNG contradicen un flujo del SRS.

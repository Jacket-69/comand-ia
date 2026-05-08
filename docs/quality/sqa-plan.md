# Plan SQA — COMAND-IA

> Versión liviana — **no IEEE 730**. La calidad es propiedad emergente de las prácticas, no checkpoint final. Para academia + 2 personas + 10 sprints, este plan es el contrato de calidad operativo del proyecto.

## Objetivos de calidad

| Atributo (ISO 25010) | Métrica clave | Verificación |
|---|---|---|
| Functional Suitability | RFs cubiertos por al menos 1 historia + 1 CA | Trazabilidad RF → HU → CA → test. |
| Reliability | Cero pérdida de pedidos durante desconexión + uptime ≥99% | Integration test offline + uptimerobot. |
| Performance | KDS ≤2 s, dashboard ≤1.5 s con 30 días | Medición manual en staging + dataset seed. |
| Security | RLS deny-by-default + PIN nunca en plano + sin secretos en repo | pgTAP nightly + secret scan en CI. |
| Maintainability | Cobertura ≥70% dominio / ≥60% global · 0 warnings | CI gate. |
| Compatibility | Build verde para web/Android/iOS | CI matrix + smoke navegadores. |
| Usability | Garzón hace 1er pedido en ≤5 min sin manual | Prueba de usuario antes de Avance 2. |
| Portability | `domain/` sin imports de plataforma | Code review + `flutter analyze`. |

## SQA durante el ciclo (por fase de la metodología)

| Fase | Práctica SQA aplicada |
|---|---|
| **F0 — Preparación** | Pipeline CI con format + analyze + tests + cobertura + secret scan + pgTAP desde el primer commit. lefthook con format y analyze pre-commit. |
| **F1 — Descubrimiento** | Cada historia entra al sprint con criterios de aceptación Given-When-Then en `acceptance-criteria.md`. Sin criterios → no DoR. |
| **F2 — Diseño** | C4 en `architecture/`. ADRs por decisión costosa de revertir. Trazabilidad RF → HU → CA → test. RLS y triggers diseñados al inicio del sprint, no al final. |
| **F3 — Desarrollo** | Tests acompañan código (DoD). Code review obligatoria. Documentación en el mismo PR. Conventional Commits + GitHub Flow + ramas cortas. |
| **F4 — Release** | Smoke tests post-deploy en staging y prod (1–5 min). Rollback documentado en [release-process.md](../devops/release-process.md). |
| **F5 — Mejora** | Métricas DORA observadas como hábito mental (no accionables por n=2). Deuda técnica visible en backlog. |

## Roles y responsabilidades

| Rol | Persona | Responsabilidad SQA |
|---|---|---|
| Product Owner + Backend Lead + Tech Lead | Benjamín López | Decisión de scope, ADRs, schema y RLS, code review backend. |
| Frontend Lead + UX | Fernando Godoy | Code review frontend, cumplimiento RNF-USAB, flujos UI. |
| Cross-cutting reviewer | el dev que no escribió la historia | Code review obligatoria de cada PR. |
| Agente IA | Claude / OpenCode (cuando aplique) | Reviewer adicional si trabaja un solo dev; nunca decide merge. |

## Métricas de calidad observadas (no accionables)

Métricas DORA durante el semestre se observan como hábito mental, **no como métrica accionable** (n=2 personas → ruido estadístico). Ver [opt-outs académicos](../../README.md#metodología-y-opt-outs).

Lo que sí se observa con disciplina:

- **Vida útil de rama** (≤5 días por convención). Si pasa ese umbral, replan.
- **Cobertura por PR** (no debe bajar respecto a `main`).
- **Warnings nuevos en analyze** (cero tolerancia).
- **Pedidos perdidos en demo offline** (cero tolerancia).
- **Tests skipped sin issue** (cero tolerancia).

## Verificaciones automáticas (CI gate)

| Check | Bloquea merge | Comentario |
|---|---|---|
| `dart format` | Sí | Formato consistente. |
| `flutter analyze --fatal-warnings` | Sí | Warnings = errores. |
| `flutter test --coverage` | Sí | Tests verdes. |
| Cobertura ≥70% dominio / ≥60% global | Sí | Gate de RNF-MAIN-001. |
| Secret scan (git grep + Sentry) | Sí | RNF-SEC-004. |
| `supabase db reset` + `supabase test db` | Sí | Migraciones limpias + pgTAP verde. |
| Vercel preview deploy | No (warning) | Útil para reviewer pero no bloqueante. |
| Codecov upload | No (warning) | Visibilidad, no gate. |

## Verificaciones manuales (review gate)

- Revisar el code review checklist completo (ver [../../CONTRIBUTING.md](../../CONTRIBUTING.md)).
- Demo en preview Vercel del happy path + 1 caso de error.
- Si toca UI, screenshot y verificación de estados loading/error/empty.
- Si toca dominio, verificar que no haya lógica en widgets.

## Cuándo se actualiza este plan

- Si entra una práctica nueva (ej. lint rule de imports, threat model recurrente).
- Si se levanta un opt-out por contexto (ej. backend propio post-defensa).
- Si una métrica deja de ser observable (ej. CI cambia de runner).

Cada cambio al plan SQA es un PR como cualquier otro, con su review.

## Referencias

- [Definition of Done](definition-of-done.md).
- [Testing strategy](testing-strategy.md).
- [Security baseline](../security/security.md).
- [CI/CD](../devops/ci-cd.md).
- [Roadmap](../product/roadmap.md) — fases por sprint.

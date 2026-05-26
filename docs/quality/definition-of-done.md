# Definition of Done — COMAND-IA

> Una historia es **Done** si y solo si pasa todos los puntos de esta lista. CI verde + review aprobada lo son. "Funciona en mi máquina" no.

## Checklist canónico

- [ ] Cumple todos los **criterios de aceptación** de la historia (criterios de aceptación definidos en el issue de la historia).
- [ ] **Tests relevantes** escritos:
  - Unit en `domain/` para reglas de negocio nuevas o modificadas.
  - Integration cuando toca Supabase, Drift o realtime.
  - Test pgTAP cuando toca schema, policy RLS, trigger o RPC (mismo PR).
- [ ] **CI verde:**
  - `dart format --set-exit-if-changed .`
  - `flutter analyze --fatal-warnings`
  - `flutter test --coverage`
  - `dart run tool/check_coverage.dart coverage/lcov.info --global-min=60 --domain-min=70`
  - Secret scan (`! git grep` patrones de credenciales).
  - `supabase db reset` + `supabase test db` (pgTAP) cuando toca `supabase/`.
- [ ] **Cobertura** ≥70% en `domain/` y ≥60% global (RNF-MAIN-001). 0 tests skipped sin issue tracker.
- [ ] **1 review aprobada** por el otro dev. Self-merge prohibido.
- [ ] **Demo verificada** por el reviewer en preview Vercel (o build local si toca nativo).
- [ ] **Documentación actualizada** en el mismo PR si cambió comportamiento, contrato, dependencia, configuración o flujo:
  - `docs/requirements/srs.md` si cambió un requisito funcional o no funcional.
  - `docs/architecture/` si cambió C4, modelo de datos o invariantes.
  - `docs/architecture/decisions/` con un ADR nuevo si la decisión es costosa de revertir.
  - `docs/api/contracts.md` si cambió un RPC, una tabla o un canal realtime.
  - `docs/database/` si tocaste schema o RLS.
  - `docs/product/glossary.md` si introdujiste un término nuevo del dominio.
  - `CHANGELOG.md` si la historia es user-facing.
- [ ] **No introduce secretos ni datos sensibles** (PIN, JWT, service role keys, tokens, PII).
- [ ] **Logs estructurados** para los eventos relevantes del cambio. Sin `print`.
- [ ] **Sin TODOs huérfanos**: todo TODO debe linkear a un issue (`COMA-NNN`).
- [ ] **Issue cerrado** en GitHub Project con link al PR.

## Reglas específicas por área

### Si el cambio toca multi-tenant / RLS

- [ ] Toda tabla nueva con datos de negocio tiene `venue_id` + RLS habilitada + policy USING.
- [ ] Test pgTAP cross-venue cubre la tabla nueva.
- [ ] Si la tabla guarda datos sensibles (como `staff_pin`), evaluar caso especial (ver [database/rls.md § Casos especiales](../database/rls.md)).

### Si el cambio toca UI

- [ ] Screenshot adjunto en el PR.
- [ ] Estados loading / error / empty cubiertos (RNF-USAB-003).
- [ ] Tap targets ≥44 px en mobile (RNF-USAB-001).
- [ ] Contraste WCAG AA (RNF-USAB-004).

### Si el cambio toca dominio

- [ ] No hay lógica de negocio en widgets (RNF-MAIN-004).
- [ ] Repositorio extiende interfaz abstracta (no se inyecta implementación concreta).
- [ ] Sin imports cruzados entre features.

## Si algo falla

La historia sigue en `in progress`. **No se forza el merge.** Si el sprint aprieta, se recortan features antes que tests, RLS, docs o CI (regla de scope del [roadmap](../product/roadmap.md)).

## Referencias

- Los criterios de aceptación (Given-When-Then) están definidos en el issue de cada historia.
- [Testing strategy](testing-strategy.md) — pirámide y cobertura objetivo.
- [../../CONTRIBUTING.md](../../CONTRIBUTING.md) — DoR, branching, code review checklist.

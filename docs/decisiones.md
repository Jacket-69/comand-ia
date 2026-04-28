# Decisiones arquitectónicas — COMAND-IA

> ADRs en formato Nygard compacto. Una decisión por sección. No archivos separados.

## Convenciones

- **Estado:** `Proposed` | `Accepted` | `Deprecated` | `Superseded by ADR-NNNN`
- Nuevas decisiones se agregan al final con número siguiente.
- Las decisiones nunca se borran. Si cambia, se marca `Superseded` y se agrega la nueva al final.
- Para abrir un ADR nuevo: ver instrucciones en [CONTRIBUTING.md](../CONTRIBUTING.md#cómo-abrir-un-adr).

---

## ADR-0001 — Flutter multiplataforma como frontend

**Estado:** Accepted · 2026-04-27

**Contexto:**
El producto debe funcionar en tablet de garzón (mobile), tablet de cocina (mobile), desktop del owner y opcionalmente web. Mantener cuatro codebases distintos (Android, iOS, web, desktop) es inviable para un equipo de dos personas en 10 sprints. El stack debe producir una sola base de código que compile en todos los targets sin bifurcación de lógica de dominio.

**Decisión:**
Flutter 3.x con un único codebase para Android, iOS, web (CanvasKit) y desktop. La lógica de dominio es pura Dart sin dependencias de plataforma. Las adaptaciones de layout (responsive) se manejan con `LayoutBuilder` y breakpoints, no con código duplicado.

**Consecuencias:**
- **Pro:** Un solo codebase: el equipo no fragmenta su atención entre plataformas.
- **Pro:** Dart es type-safe; el compilador captura errores en tiempo de compilación.
- **Pro:** El KDS y el dashboard del owner se pueden optimizar para tablet/desktop con el mismo código que mobile.
- **Tradeoff:** Flutter web con CanvasKit tiene bundle inicial pesado (~2 MB WASM). Mitigación: preloader + lazy loading de features.
- **Tradeoff:** Algunas librerías de Flutter no tienen soporte completo en web. Se evalúa compatibilidad web en cada dependencia nueva antes de agregarla.
- **Tradeoff:** El rendering CanvasKit no usa widgets HTML nativos, lo que puede afectar accesibilidad screen reader en web. Se mitiga con `Semantics` widgets explícitos.

---

## ADR-0002 — Supabase como backend (sin microservicios)

**Estado:** Accepted · 2026-04-27

**Contexto:**
El equipo tiene dos personas y ~20h/sprint. Diseñar, desplegar y operar microservicios propios (API Gateway, servicio de auth, servicio de pedidos, etc.) consumiría la mayor parte del tiempo en infra en lugar de features. El dominio del problema (comandas + analítica para un local) no requiere escala horizontal independiente por servicio.

**Decisión:**
Backend único: Supabase (Postgres + Auth + Realtime + Storage). El frontend usa el SDK `supabase-dart` directamente. No hay capa REST artesanal ni microservicios. El aislamiento de tenants se hace por RLS sobre `venue_id`, no por bases de datos separadas.

**Consecuencias:**
- **Pro:** Cero tiempo en configurar servidores, load balancers ni deployment de API.
- **Pro:** Auth, realtime y storage resueltos con config, no con código.
- **Pro:** Supabase free tier es suficiente para academia (500 MB, 200 conexiones realtime).
- **Pro:** `supabase gen types --lang dart` genera tipos type-safe desde el schema real.
- **Tradeoff:** Acoplamiento al proveedor. Mitigación: la capa `data/datasources/remote/` abstrae el SDK; cambiar de backend no toca el dominio.
- **Tradeoff:** Realtime limitado a 200 conexiones simultáneas en free tier. Documentado en [SRS § 2.4](SRS.md).
- **Tradeoff:** Edge functions (Deno) son optativas; solo se usan si Postgres + RLS no alcanzan.

---

## ADR-0003 — Riverpod 2.x con codegen para state management

**Estado:** Accepted · 2026-04-27

**Contexto:**
El estado de la app (sesión, menú, pedidos activos, sync) debe ser reactivo, testeable y aislado de la UI. Se evaluaron Provider, BLoC, Riverpod y GetX. Provider es el ancestro de Riverpod pero tiene limitaciones en composición. BLoC introduce mucho boilerplate para un equipo pequeño. GetX mezcla state management con routing y DI, dificultando el testing unitario.

**Decisión:**
Riverpod 2.x con `@riverpod` codegen. Los providers se generan en `*.g.dart` via `build_runner`. Los controllers extienden `AsyncNotifier` o `Notifier` según el caso. Los repositorios se inyectan como providers; los controllers nunca instancian implementaciones concretas.

**Consecuencias:**
- **Pro:** Testing sin contexto de Widget: los providers son testeables con `ProviderContainer`.
- **Pro:** Codegen elimina boilerplate y reduce errores en la declaración de providers.
- **Pro:** Riverpod es compatible con todas las plataformas Flutter (web incluido).
- **Tradeoff:** `build_runner` debe correr después de cada cambio de interfaz anotada. Integrado en el flujo de dev como `flutter pub run build_runner watch`.
- **Tradeoff:** La curva de aprendizaje del codegen es mayor que Provider clásico. Fernando (frontend lead) toma ownership del patrón de controllers.

---

## ADR-0004 — Drift como persistencia local (spike Sprint 1; fallback Hive)

**Estado:** Accepted · 2026-04-27

**Contexto:**
El sistema es offline-first: los pedidos deben persistir localmente cuando no hay internet. Se necesita una solución de storage local que: (a) sobreviva reinicios de la app, (b) soporte queries para recuperar la cola FIFO de operaciones pendientes, (c) funcione en Flutter web (IndexedDB) además de mobile (SQLite).

Drift es un ORM type-safe que compila queries a SQL en mobile y a IndexedDB en web. Hive es un key-value store más simple y con mejor historial en web, pero sin queries relacionales. Los pedidos tienen estructura relacional (`customer_order` → `order_item`), lo que favorece Drift.

**Decisión:**
Usar Drift como motor de persistencia local. En Sprint 1, dedicar un día de spike a validar que Drift compila y opera correctamente en Flutter web (CanvasKit + IndexedDB). Si la fricción supera 4h de bloqueo sin solución, migrar a Hive con queries en memoria para "pedidos del día".

Si el spike falla, se abrirá ADR-0004-superseded y esta decisión pasa a `Superseded`.

**Consecuencias:**
- **Pro:** Drift provee type-safety en queries; los errores de schema se detectan en compilación.
- **Pro:** La misma interfaz de repositorio (ADR-0001 SOLID-O) permite cambiar a Hive sin tocar el dominio.
- **Tradeoff:** Drift en Flutter web está en desarrollo activo; puede tener issues con multi-tab o IndexedDB en algunos navegadores.
- **Tradeoff:** El spike de 1 día es el gate: si hay problemas insolubles, el fallback es Hive.

---

## ADR-0005 — Multi-tenancy por `venue_id` + RLS deny-by-default

**Estado:** Accepted · 2026-04-27

**Contexto:**
COMAND-IA es multi-tenant: múltiples locales gastronómicos comparten la misma base de datos. El aislamiento de datos entre tenants es un requisito de seguridad crítico (un local no puede ver pedidos ni menú de otro local). Se evaluaron: base de datos por tenant (alto costo operativo), schema por tenant (complejidad de migrations), y shared DB con RLS.

**Decisión:**
Shared DB con RLS deny-by-default en Postgres. Todas las tablas con datos de negocio tienen columna `venue_id`. La policy genérica en cada tabla es:

```sql
USING (venue_id IN (SELECT venue_id FROM app_user WHERE id = auth.uid()))
```

RLS habilitada desde Sprint 1, no "después". Verificación automática en CI nightly con pgTAP.

**Consecuencias:**
- **Pro:** Un solo schema; las migraciones son simples y uniformes para todos los tenants.
- **Pro:** El aislamiento es enforced por Postgres, no por lógica de aplicación. Es más difícil de bypassear accidentalmente.
- **Pro:** Soporta Capa 3 (datos agregados) sin cambios de schema: las vistas de analítica ya tienen `venue_id`.
- **Tradeoff:** JOINs entre tablas pueden filtrar filas inesperadamente si una de las tablas del JOIN no tiene policy equivalente. Cada migración con nueva tabla incluye test pgTAP cross-venue desde Sprint 1.
- **Tradeoff:** `staff_pin` requiere tratamiento especial: SELECT completamente bloqueado, acceso solo via `verify_pin()` SECURITY DEFINER para no exponer hashes.

---

## ADR-0006 — License AGPL-3.0

**Estado:** Accepted · 2026-04-27

**Contexto:**
El proyecto es académico y open-source. El equipo quiere garantizar que cualquier derivado (incluyendo despliegues SaaS) también sea open-source. MIT y Apache-2.0 no cubren el caso SaaS (loophole "ASP"). AGPL-3.0 cierra ese loophole: todo despliegue público de código derivado debe publicar el código fuente.

**Decisión:**
Licencia AGPL-3.0. El archivo `LICENSE` en la raíz del repo contiene el texto completo. El README incluye el badge de licencia y una nota explicativa.

**Consecuencias:**
- **Pro:** Cualquier derivado comercial SaaS debe open-source el código, alineado con los valores del proyecto.
- **Pro:** Señal clara en el mercado: el software es libre pero no se puede privatizar.
- **Tradeoff:** Algunas empresas tienen políticas que prohíben usar código AGPL. Para el contexto académico esto es irrelevante.
- **Tradeoff:** Si se decide cambiar de licencia post-defensa, requiere consenso de todos los contribuidores.

---

## ADR-0007 — GitHub Flow + squash merge + Conventional Commits en español

**Estado:** Accepted · 2026-04-27

**Contexto:**
Con un equipo de dos personas, el proceso de desarrollo debe ser simple y sin fricción, pero suficientemente estructurado para que el historial de git sea legible y `main` siempre esté en estado desplegable. Se evaluaron GitFlow (demasiado complejo para 2 personas), trunk-based (sin PRs, demasiado riesgoso sin code review) y GitHub Flow (PR obligatorio + `main` siempre desplegable).

**Decisión:**
GitHub Flow: toda rama nace de `main`, tiene vida útil ≤5 días, y se mergea a `main` via squash merge con PR obligatorio y CI verde. Los commits siguen Conventional Commits en español (ver [CONTRIBUTING.md](../CONTRIBUTING.md)). No se hace force push a `main`.

**Consecuencias:**
- **Pro:** `main` siempre desplegable. El deploy a preview es automático en cada PR via Vercel.
- **Pro:** Squash merge produce un historial limpio y legible. Cada squash commit = una historia completa.
- **Pro:** Conventional Commits permite generar changelogs automáticos para el tag de release.
- **Tradeoff:** El squash elimina el historial granular de la rama. Para bugs complejos, el historial de la rama está en el PR de GitHub, no en `git log`.
- **Tradeoff:** Sin Scrum Master formal, la disciplina de no saltarse el PR depende del equipo. La regla de no auto-merge está documentada en DoD.

---

## ADR-0008 — Sync offline-first: cola FIFO + LWW por `updated_at` server-side

**Estado:** Accepted · 2026-04-27

**Contexto:**
La toma de pedido debe funcionar sin internet. Al reconectarse, las operaciones pendientes deben llegar a Supabase en orden y sin pérdida. Se necesita una política de resolución de conflictos cuando la misma fila es modificada offline en dos dispositivos distintos. Se evaluaron: CRDT (complejidad alta para un equipo de 2), operational transforms (más complejo aún), y LWW (Last Write Wins) por timestamp de servidor.

**Decisión:**
Cola FIFO local en Drift (`pending_op`). El `SyncService` (Riverpod background provider) escucha conectividad y vacía la cola en orden de `created_at`. Resolución de conflictos por LWW: el campo `updated_at` es generado por el servidor vía trigger `set_updated_at()`. Si el servidor tiene `updated_at` más reciente que el local, el local adopta el valor del servidor.

**Consecuencias:**
- **Pro:** Implementación simple: no requiere CRDT ni OT.
- **Pro:** El orden FIFO garantiza causalidad dentro de un mismo dispositivo.
- **Pro:** El timestamp de servidor como fuente de verdad evita drift de relojes del cliente.
- **Tradeoff:** LWW puede perder la escritura más antigua en casos de edición concurrente desde dos dispositivos. Para el caso de uso (un garzón por mesa, no edición simultánea del mismo pedido), este riesgo es aceptable.
- **Tradeoff:** `pending_op` existe solo en Drift (local); si el storage local se borra, las ops pendientes se pierden. Mitigación: documentado en onboarding del owner.

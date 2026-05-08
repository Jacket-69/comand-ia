# Contribuir a COMAND-IA

Este documento es el contrato de trabajo del equipo. Cubre cómo ramificar, cómo escribir commits, cuándo una historia está lista para empezar, cuándo está lista para cerrar, y qué se revisa en code review.

---

## Idioma

| Artefacto | Idioma |
|---|---|
| Código (clases, variables, funciones) | Inglés |
| Comentarios en código | Español o inglés (consistencia local) |
| Commits | Español |
| Issues | Español |
| Pull Requests (título + descripción) | Español |
| Docs (`docs/`, README, este archivo) | Español |
| ADRs | Español |

---

## Branching — GitHub Flow

```
main  ←  feat/COMA-123-nombre-corto  →  PR  →  squash merge
                                      │
                                      └→ Vercel preview deploy automático
```

**Reglas:**
- `main` siempre desplegable. Nada se mergea sin CI verde.
- Toda rama nace de `main` actualizada (`git pull --rebase origin main` antes de empezar).
- Una rama = una historia. Si descubres trabajo paralelo, abre otra rama.
- Vida útil de rama: ≤5 días. Más allá → riesgo alto de merge hell.

**Naming:**

```
feat/COMA-123-add-order-form          ← feature
fix/COMA-145-pin-hash-collision        ← bugfix
chore/COMA-201-bump-flutter-3-19      ← mantenimiento
docs/COMA-210-update-srs-rnf-perf     ← solo docs
refactor/COMA-220-extract-order-repo  ← refactor sin cambio funcional
test/COMA-230-add-rls-cross-venue     ← solo tests
```

`COMA-NNN` = número del issue de GitHub Projects. Sin issue, no hay rama.

El roadmap operativo vive en el GitHub Project **COMAND-IA — Sprints** y se
resume en [docs/product/roadmap.md](docs/product/roadmap.md). Si el Project y
la documentación se contradicen, se corrigen ambos en el mismo PR o commit.

---

## Conventional Commits (en español)

Formato:
```
<tipo>(<scope>): <descripción imperativa minúscula>

[cuerpo opcional explicando el por qué]

[footer opcional con BREAKING CHANGE: o refs]
```

**Tipos:**

| Tipo | Cuándo |
|---|---|
| `feat` | Nueva funcionalidad para el usuario final |
| `fix` | Corrección de bug |
| `refactor` | Cambio interno sin alterar comportamiento |
| `perf` | Mejora de performance |
| `test` | Añadir o corregir tests |
| `docs` | Cambios solo de documentación |
| `chore` | Mantenimiento (deps, configs, CI) |
| `style` | Formato, sin cambio lógico |
| `build` | Cambios en build system |
| `ci` | Cambios en GitHub Actions |
| `revert` | Revertir un commit anterior |

**Scopes válidos:** `auth | menu | orders | kitchen | analytics | infra | docs | tests | ci`

**Ejemplos:**

```
feat(orders): agrega tomar pedido offline con cola FIFO
fix(auth): corrige hash de PIN colisionando entre venues
refactor(menu): extrae MenuRepository de la pantalla
docs(adr): registra decisión Drift como persistencia local
test(rls): cubre acceso cross-venue en tabla customer_order
chore(deps): actualiza riverpod a 2.5.1
```

**Commits que NO van a `main`:**
- `wip:` (work in progress)
- `fixup!` (debe haberse rebaseado antes del PR)
- `aaaa` o cualquier mensaje de un solo carácter

---

## Definition of Ready (DoR) — para empezar a trabajar

Una historia es "ready" cuando:

- [ ] Título imperativo y descripción de 3-5 líneas que explican el **por qué** del usuario.
- [ ] **Criterios de aceptación** enumerados (mínimo 1, idealmente 3-5).
- [ ] Estimada en **story points** (1, 2, 3, 5, 8, 13) por consenso de los dos devs.
- [ ] Dependencias resueltas o explícitamente marcadas como bloqueante (`#bloqueado`).
- [ ] Si toca UI: mockup o referencia visual adjunta (Excalidraw, screenshot, link, el FK Figma).
- [ ] Si toca dato nuevo: ADR aprobado o pendiente listado.
- [ ] Sin ADR pendiente bloqueando.

**Si una historia no cumple DoR, no entra al sprint.** Vuelve al backlog.

---

## Definition of Done (DoD) — para cerrar

Una historia es "done" cuando:

1. **Código** mergeado en `main` vía squash.
2. **Tests verdes** en CI:
   - Cobertura **≥70% en `domain/`** y **≥60% global**.
   - 0 tests skipped sin issue tracker.
3. **Lint clean:** `very_good_analysis` sin warnings (warnings = errores).
4. **1 review aprobada** del otro dev. Self-merge prohibido.
5. **Demo verificada** por el reviewer en preview Vercel (o build local si toca nativo).
6. **Documentación actualizada** según el árbol canónico de `docs/`:
   - `docs/requirements/srs.md` si cambió un RF o RNF.
   - `docs/architecture/` y/o `docs/architecture/decisions/<NNNN>-<slug>.md` si cambió el diseño o se tomó una decisión costosa.
   - `docs/database/` si tocaste schema o RLS.
   - `docs/api/contracts.md` si cambió un RPC, una tabla o un canal realtime.
   - `docs/product/glossary.md` si introdujiste un término del dominio.
   - `CHANGELOG.md` si la historia es user-facing.
   - `README.md` si cambió el quickstart o el listado de docs.
7. **Issue cerrado** en GitHub Projects con link al PR.
8. **Sin TODOs huérfanos** en el código (todo TODO debe linkear a un issue).

Si algo de esto falla → la historia sigue `in progress`. No se forza el merge.

---

## Code Review Checklist

Cuando revisas un PR, pasas por esta lista. Comentas inline lo que no aplica.

### Funcional
- [ ] Cumple todos los criterios de aceptación del issue.
- [ ] Demo en preview Vercel funciona en happy path.
- [ ] Demo cubre al menos un caso de error (red caída, dato inválido).

### Tests
- [ ] Tests cubren happy path + 1 caso de error mínimo.
- [ ] Tests son determinísticos (sin `Random.now()` ni `DateTime.now()` sin inyectar).
- [ ] Si hay flaky test → marcado `@Skip` con issue P2 abierto.

### Seguridad
- [ ] No hay secretos hardcoded (claves API, tokens, PINs).
- [ ] Si toca tabla con `venue_id` → RLS verificada con test pgTAP cross-venue.
- [ ] Inputs externos validados (sin SQL injection, sin XSS en widgets que renderizan texto del backend).

### Arquitectura
- [ ] Lógica de negocio en `domain/usecase`, no en widgets.
- [ ] Repositorios extienden interfaz abstracta (no se inyecta implementación).
- [ ] Sin imports cruzados entre features (un feature no importa de otro feature directamente; pasa por `core/`).
- [ ] Migraciones SQL forward-only y revisadas con `supabase db reset`.

### Código limpio
- [ ] Sin `print` (usar `logger` configurado).
- [ ] Sin código comentado (eliminar o crear issue).
- [ ] Paquetes nuevos justificados en la descripción del PR.
- [ ] Naming consistente con el resto del codebase.

### UI (si aplica)
- [ ] Screenshot adjunto en el PR.
- [ ] Estados loading / error / empty cubiertos.
- [ ] Tap targets ≥44px en mobile.

### Docs (si aplica)
- [ ] ADR creado en `docs/architecture/decisions/NNNN-<slug>.md` (formato MADR) si la decisión es arquitectónica.
- [ ] `docs/requirements/srs.md` actualizado si cambió un RF o RNF.
- [ ] `docs/architecture/`, `docs/database/` o `docs/api/contracts.md` actualizados si cambió el diseño, el modelo de datos o un contrato.
- [ ] `docs/product/glossary.md` actualizado si introdujiste un término del dominio.

---

## Plantilla de Pull Request

```markdown
## Qué

<1 párrafo describiendo el cambio>

## Por qué

<1 párrafo explicando la motivación: bug, feature, deuda técnica, ADR>

Closes COMA-XXX

## Cómo probar

1. <paso>
2. <paso>
3. <verificación esperada>

## Screenshots / Demo

<imágenes o link a preview>

## Checklist

- [ ] Tests verdes localmente
- [ ] Cobertura ≥70% dominio
- [ ] Lint clean
- [ ] Docs actualizadas
- [ ] Issue linkeado
```

---

## Escalation

| Bloqueo | Acción | SLA |
|---|---|---|
| Técnico < 4h | Buscar solo, anotar approach | — |
| Técnico > 4h | WhatsApp grupo con tag `#blocker` + descripción | < 1h respuesta esperada |
| Bloqueo > 1 día | Daily async + replan en martes | — |
| Decisión arquitectónica nueva | ADR draft → discusión async → merge en review viernes | 1 semana |
| Disagreement irreconciliable | Decide el rol primario del área (Benjamín = backend / arquitectura, Fernando = frontend / UX) | Inmediato |

---

## Cómo abrir un ADR

1. Copiar [`docs/architecture/decisions/0000-template.md`](docs/architecture/decisions/0000-template.md) (formato MADR liviano).
2. Crear archivo nuevo `docs/architecture/decisions/NNNN-<slug>.md` con el siguiente número de la secuencia (sin reusar números, aunque haya ADR `rejected` o `superseded`).
3. Frontmatter inicial: `status: proposed`, `date: YYYY-MM-DD`, `deciders: <quién(es)>`.
4. PR titulado `docs(adr): ADR-NNNN <título>`.
5. Discusión en el PR. Cuando ambos aprobamos → cambiar a `accepted` y mergear.
6. Si una decisión futura supera a esta → marcar como `superseded by ADR-MMMM`. Nunca borrar el archivo.

---

## Tools del repo

| Comando | Qué hace |
|---|---|
| `flutter pub get` | Instala dependencias |
| `flutter analyze` | Lint (debe pasar) |
| `dart format --set-exit-if-changed .` | Verifica formato (debe pasar) |
| `flutter test --coverage` | Corre tests con cobertura |
| `flutter run -d chrome` | Levanta app en navegador (dev) |
| `supabase start` | Levanta Supabase local en Docker |
| `supabase db reset` | Aplica todas las migraciones desde cero + seed |
| `supabase gen types --lang dart` | Genera tipos Dart desde schema Postgres |

---

## Retomar trabajo en chat nuevo

Antes de implementar, leer:

1. [README.md](README.md) — quickstart, índice de documentación y opt-outs académicos.
2. [docs/product/roadmap.md](docs/product/roadmap.md) — sprint actual y backlog.
3. [docs/architecture/overview.md](docs/architecture/overview.md) — cómo encajan las piezas.
4. Este archivo (DoR/DoD/code review).

Luego elegir el issue `Todo` más prioritario del GitHub Project que cumpla DoR.
Si el issue no está listo, actualizar el issue antes de abrir rama. Si el cambio
resuelve deuda técnica o altera contratos, actualizar docs en el mismo cierre.

---

## Cuándo NO seguir esta guía

Por qué no la seguirias? — Palurdo Inculto, disfruta lo votado.

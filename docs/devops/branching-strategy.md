# Branching strategy — GitHub Flow

> Cómo ramificamos, nombramos y mergeamos. Decisión: [ADR-0007](../architecture/decisions/0007-github-flow-conventional-commits.md). Resumen operativo extraído de `CONTRIBUTING.md`.

## El flujo en una imagen

```
main  ←  feat/COMA-123-nombre-corto  →  PR  →  squash merge
                                      │
                                      └→ Vercel preview deploy automático
```

## Reglas

- **`main` siempre desplegable.** Nada se mergea sin CI verde.
- **Toda rama nace de `main` actualizada.** Antes de empezar: `git pull --rebase origin main`.
- **Una rama = una historia.** Si descubres trabajo paralelo, abre otra rama.
- **Vida útil de rama: ≤5 días.** Más allá → riesgo alto de merge hell. Si pasa el umbral, abrir `#blocker` y replan.
- **Squash merge obligatorio.** Cada squash commit = una historia completa con su mensaje.
- **No `force push` a `main`.** No commits directos a `main` salvo de mantenedores en operaciones administrativas (reorganización inicial, tags). Sin auto-merge.

## Naming

```
feat/COMA-123-add-order-form          ← feature
fix/COMA-145-pin-hash-collision       ← bugfix
chore/COMA-201-bump-flutter-3-19      ← mantenimiento
docs/COMA-210-update-srs-rnf-perf     ← solo docs
refactor/COMA-220-extract-order-repo  ← refactor sin cambio funcional
test/COMA-230-add-rls-cross-venue     ← solo tests
```

`COMA-NNN` = número del issue de GitHub Project **COMAND-IA — Sprints**. **Sin issue, no hay rama.**

## Conventional Commits (en español)

Formato:

```
<tipo>(<scope>): <descripción imperativa minúscula>

[cuerpo opcional explicando el por qué]

[footer opcional con BREAKING CHANGE: o refs]
```

### Tipos válidos

| Tipo | Cuándo |
|---|---|
| `feat` | Nueva funcionalidad para el usuario final. |
| `fix` | Corrección de bug. |
| `refactor` | Cambio interno sin alterar comportamiento. |
| `perf` | Mejora de performance. |
| `test` | Añadir o corregir tests. |
| `docs` | Cambios solo de documentación. |
| `chore` | Mantenimiento (deps, configs, CI). |
| `style` | Formato, sin cambio lógico. |
| `build` | Cambios en build system. |
| `ci` | Cambios en GitHub Actions. |
| `revert` | Revertir un commit anterior. |

### Scopes válidos

`auth | menu | orders | kitchen | analytics | infra | docs | tests | ci`

### Ejemplos

```
feat(orders): agrega tomar pedido offline con cola FIFO
fix(auth): corrige hash de PIN colisionando entre venues
refactor(menu): extrae MenuRepository de la pantalla
docs(adr): registra decisión Drift como persistencia local
test(rls): cubre acceso cross-venue en tabla customer_order
chore(deps): actualiza riverpod a 2.5.1
```

### Commits que NO van a `main`

- `wip:` (work in progress).
- `fixup!` (debe haberse rebaseado antes del PR).
- Mensajes de un solo carácter o sin valor (`aaaa`, `.`, `temp`).

## Pull Request

Ver plantilla en [../../CONTRIBUTING.md § Plantilla de Pull Request](../../CONTRIBUTING.md). Resumen:

```markdown
## Qué
<1 párrafo describiendo el cambio>

## Por qué
<1 párrafo: bug, feature, deuda técnica, ADR>

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

## Branch protection en GitHub

- Requiere CI verde antes de merge.
- Requiere 1 review aprobada.
- No force push a `main`.
- No bypass del CI ni de la review.

## Commits administrativos en `main`

Excepción reservada para:

- Reorganización inicial del repo o de la documentación (esta migración al árbol canónico).
- Tags de release (`v*`).
- Hotfixes urgentes durante demo (con commit de seguimiento que documente la situación).

Estos commits siguen Conventional Commits y se hacen sin push hasta que Benjamín revise.

## Cuándo replanificar el flujo

- Si el equipo crece a 3+ personas sin Scrum Master, evaluar `release/*` para congelar versiones.
- Si aparecen hotfixes recurrentes en prod (post-defensa con clientes), evaluar `hotfix/*`.
- Mientras seamos 2 personas en academia, GitHub Flow + ramas cortas es la única convención correcta.

## Referencias

- [ADR-0007](../architecture/decisions/0007-github-flow-conventional-commits.md) — decisión y alternativas consideradas.
- [../../CONTRIBUTING.md](../../CONTRIBUTING.md) — DoR, DoD, code review checklist completos.
- [release-process.md](release-process.md) — qué pasa al mergear a `main`.
- [ci-cd.md](ci-cd.md) — pipeline que valida cada PR.

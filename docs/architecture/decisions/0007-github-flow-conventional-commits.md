---
adr: 0007
title: GitHub Flow + squash merge + Conventional Commits en español
status: accepted
date: 2026-04-27
deciders: Benjamín López, Fernando Godoy
tags: [adr, devops, git, proceso]
---

# ADR 0007 — GitHub Flow + squash merge + Conventional Commits en español

## Contexto

Con un equipo de 2 personas y ~20 h/sprint efectivas, el proceso de desarrollo debe ser:

1. **Simple y sin fricción** — no hay tiempo para ceremonia tipo Scrum/GitFlow.
2. **Suficientemente estructurado** — `main` siempre desplegable; el historial de git debe ser legible 6 meses después; cada cambio pasa por code review.
3. **Compatible con CI/CD ya existente** — preview Vercel automático por PR, smoke pgTAP en cada PR.

Las convenciones de commits son la base para generar `CHANGELOG.md` automáticamente al cortar tags de release y para que tags humanos (`feat`, `fix`, `docs`) sean inmediatamente reconocibles en `git log`.

Los flujos canónicos evaluados:

- **GitFlow** — `develop` + `main` + `release/*` + `hotfix/*` + `feature/*`. Pensado para releases largos con múltiples mantenedores.
- **Trunk-based** — todos commiten directo a `main`, feature flags. Requiere CI muy maduro y disciplina alta.
- **GitHub Flow** — todo nace de `main`, PR obligatorio, merge cuando el CI está verde y hay review.

## Decisión

Adoptamos **GitHub Flow** con las siguientes reglas:

- Toda rama nace de `main` actualizada.
- Naming: `feat/COMA-NNN-<slug>`, `fix/COMA-NNN-<slug>`, `chore/COMA-NNN-<slug>`, `docs/COMA-NNN-<slug>`, `refactor/COMA-NNN-<slug>`, `test/COMA-NNN-<slug>`.
- Vida útil ≤ 5 días (más allá es señal de que la historia es muy grande y debe partirse).
- Toda rama mergea a `main` vía **squash merge** con PR obligatorio y CI verde.
- **Conventional Commits en español** (formato `<tipo>(<scope>): <descripción imperativa>`).
- Scopes válidos: `auth | menu | orders | kitchen | analytics | infra | docs | tests | ci`.
- No `force push` a `main`; no `auto-merge`; no commits directos en `main` salvo de mantenedores en operaciones administrativas (reorganización inicial, tags).

`COMA-NNN` corresponde al número del issue en GitHub Projects "COMAND-IA — Sprints". Sin issue, no hay rama.

## Alternativas consideradas

### Opción A — GitFlow (`develop` + `release/*` + `hotfix/*`)
- **Pros:** Patrón conocido y documentado; permite congelar `release/*` mientras se sigue trabajando en `develop`.
- **Contras:** Dos ramas largas (`main` + `develop`); complejidad alta para 2 personas; no hay distinción real entre "release" y "main" en un proyecto académico de 10 sprints.
- **Por qué se descartó:** Sobre-ingeniería para el tamaño del equipo y horizonte temporal.

### Opción B — Trunk-based development sin PRs
- **Pros:** Mínima fricción; deploys frecuentes.
- **Contras:** Sin code review formal → en un equipo de 2 sin Scrum Master se pierde el control de calidad; depende de feature flags maduros que no tenemos.
- **Por qué se descartó:** Demasiado riesgoso sin code review para un proyecto evaluado académicamente.

### Opción C — GitHub Flow (elegida)
- **Pros:** PR obligatorio (code review forzado); `main` siempre desplegable; preview automático por PR vía Vercel; squash merge produce historial legible.
- **Contras explícitos:** El squash elimina el historial granular de la rama; depende de la disciplina del equipo (sin Scrum Master, no hay nadie que aplique las reglas externamente).

## Consecuencias

### Positivas
- `main` siempre desplegable. El deploy a preview Vercel es automático en cada PR.
- Squash merge produce historial limpio y legible: cada squash commit = una historia completa con su mensaje describiendo el "por qué".
- Conventional Commits permite generar changelogs automáticos para el tag de release.
- Naming `COMA-NNN-<slug>` enlaza commit ↔ issue ↔ PR ↔ milestone sin fricción.

### Negativas / costo
- El squash elimina el historial granular de la rama. Para bugs complejos, el historial granular vive en el PR de GitHub, no en `git log`.
- Sin Scrum Master formal, la disciplina de no saltarse el PR depende del equipo. Mitigación: regla de "no auto-merge" documentada en DoD; branch protection en GitHub.
- Si una historia no cumple DoD, no se mergea — esto puede generar fricción cuando un sprint está apretado, pero la regla de scope es "se recorta features antes que tests/RLS/docs/CI".

### Neutras
- El equipo aprende a escribir commits descriptivos del "por qué" (Conventional Commits + cuerpo opcional con justificación).
- Los hooks `lefthook` (format + analyze pre-commit) cortan errores antes del PR → menos round-trips de CI.

## Cumplimiento / verificación

- Branch protection en GitHub: `main` exige CI verde + 1 review + no force push.
- Lefthook (`lefthook.yml`) ejecuta `dart format --set-exit-if-changed` y `flutter analyze --fatal-warnings` en pre-commit.
- CI rechaza PRs con commits que no cumplan Conventional Commits si se decide automatizar (a hoy, validación manual en code review).
- Code review checklist en `docs/contributing.md` y `docs/quality/definition-of-done.md` exige scope adecuado y mensaje correcto.
- Vida útil de rama: si pasa 5 días sin merge, `#blocker` en el grupo y replan en daily async.

## Referencias

- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow).
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/es/v1.0.0/).
- [Keep a Changelog 1.1.0](https://keepachangelog.com/es-ES/1.1.0/).
- [docs/contributing.md](../../contributing.md), [docs/devops/branching-strategy.md](../../devops/branching-strategy.md).
- ADRs relacionados: ninguno (decisión de proceso transversal).

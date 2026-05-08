# Storyboards y referencias visuales

> Mockups, wireframes y referencias visuales del producto. **Las vistas no se versionan en este repo** para no inflar el clone con binarios; viven en la carpeta hermana `comand-ia_vistas/`.

## Ubicación

```
~/Documentos/Repositorios/UNIVERSIDAD/
├── comand-ia/             ← este repo (código + docs)
└── comand-ia_vistas/      ← carpeta hermana, no versionada acá
```

`comand-ia_vistas/` contiene:

- Layouts responsivos para móvil, tablet y desktop.
- Mockups de pantalla por rol (garzón / owner / cocina).
- Estados clave: loading / error / empty / éxito.
- Referencias visuales sueltas (paleta, iconografía).

## Convenciones de uso

- **Una historia con UI necesita referencia visual antes de entrar al sprint** (DoR, ver [contributing.md](../contributing.md)). La referencia puede ser un screenshot del mockup, un Excalidraw, un link o un PNG en `comand-ia_vistas/`.
- **Las vistas no son contrato firme.** Si Figma/PNG contradice un flujo del SRS, gana el SRS y se actualizan las vistas (ver [roadmap.md § Criterio para replanificar](roadmap.md)).
- **Una pantalla pasa de "diseño" a "implementación" cuando** existe el issue COMA-NNN, el mockup está adjunto y el equipo aceptó los criterios de aceptación.

## Pantallas planificadas (Capa 1 + Capa 2)

| Pantalla | Rol | Estado de diseño | Estado de implementación |
|---|---|---|---|
| `LoginScreen` (magic link / PIN) | owner / staff | Mockup en `comand-ia_vistas/` | Implementado (mock) |
| `TableGridScreen` | staff | Mockup en `comand-ia_vistas/` | Implementado parcial |
| `OrderFormScreen` (mesa → ítems → confirmar) | staff | Mockup en `comand-ia_vistas/` | Sprint 2 |
| `KdsScreen` (tarjetas con cambio de estado) | cocina | Mockup en `comand-ia_vistas/` | Sprint 3 |
| `MenuAdminScreen` (categorías + ítems) | owner | Mockup en `comand-ia_vistas/` | Sprint 5–6 |
| `DashboardScreen` (KPIs + gráfico) | owner | Mockup en `comand-ia_vistas/` | Sprint 5 |
| Estados loading / error / empty | todos | Reglas en mockup | Pendiente, RNF-USAB-003 |

> El detalle por pantalla (componentes, breakpoints, paleta) vive en la carpeta hermana, no en este repo.

## Estilo y tono

- **Mobile-first** con breakpoints para tablet y desktop. La misma pantalla escala vía `LayoutBuilder` y breakpoints, no se duplica el código por plataforma.
- **Tap targets ≥44×44 px** en mobile (RNF-USAB-001).
- **Contrastes WCAG AA** (ratio ≥4.5:1) en texto normal (RNF-USAB-004).
- **Estados loading / error / empty explícitos en cada pantalla**: nada de spinners infinitos ni pantallas en blanco (RNF-USAB-003).
- Iconografía y paleta consistentes con la imagen de marca del proyecto académico.

## Cómo agregar una pantalla

1. Crear mockup en `comand-ia_vistas/` (PNG, Figma, Excalidraw).
2. Abrir issue `COMA-NNN` con el mockup adjunto y los criterios de aceptación.
3. Esperar DoR (ambos devs aceptan story points).
4. Implementar en una rama corta `feat/COMA-NNN-<slug>`.
5. PR con screenshot del resultado vs mockup.
6. Actualizar la tabla de "Pantallas planificadas" en este archivo si cambia el estado.

## Referencias

- [SRS § 4.3 Usability](../requirements/srs.md) — RNF-USAB-001..004.
- [contributing.md](../contributing.md) — DoR, DoD.
- [architecture/c4-components.md](../architecture/c4-components.md) — pantallas por feature.

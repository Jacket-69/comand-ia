# Storyboards y referencias visuales

> Mockups y referencias visuales del producto. **No se versionan en este repo** (para no inflar el clone con binarios); viven en la carpeta hermana `comand-ia_vistas/`.

## Ubicación

```text
~/Proyectos/Repositorios/UNIVERSIDAD/
├── comand-ia/             ← este repo (código + docs)
└── comand-ia_vistas/      ← mockups por rol (admin / caja / cocina), no versionados
```

## Convenciones

- **Una historia con UI necesita su referencia visual antes de entrar al sprint** (DoR; ver [CONTRIBUTING.md](../../CONTRIBUTING.md)).
- **Las vistas no son contrato firme:** si un mockup contradice un flujo del SRS, gana el SRS y se actualiza la vista.
- El estado de cada pantalla (diseño / en desarrollo / hecho) vive en los issues `COMA-NNN` del board, no en este archivo.

## Estilo

- **Mobile-first** con breakpoints para tablet y desktop: la misma pantalla escala vía `LayoutBuilder`, no se duplica el código por plataforma.
- Tap targets ≥44×44 px, contrastes WCAG AA, y estados loading/error/empty explícitos en cada pantalla (RNF-USAB-001..004; ver [SRS](../requirements/srs.md)).

## Referencias

- [SRS § Usability](../requirements/srs.md) — RNF-USAB-001..004.
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — DoR, DoD.

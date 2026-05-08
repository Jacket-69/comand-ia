---
adr: 0006
title: Licencia AGPL-3.0
status: accepted
date: 2026-04-27
deciders: Benjamín López
tags: [adr, legal, licencia]
---

# ADR 0006 — Licencia AGPL-3.0

## Contexto

El proyecto es académico y open-source. El equipo quiere garantizar que **cualquier derivado, incluyendo despliegues SaaS**, también sea open-source — es decir, que un tercero no pueda tomar el código, ofrecerlo como servicio cerrado y privatizar las mejoras.

Las licencias permisivas (MIT, Apache-2.0, BSD) **no cubren el caso SaaS** (loophole conocido como "ASP loophole" o "service loophole"): permiten que un servicio web ofrezca el software sin tener que publicar el código fuente derivado. Las copyleft tradicionales (GPL-3.0) cubren la distribución de binarios pero **no la oferta como servicio remoto**.

AGPL-3.0 (Affero GPL) cierra ese loophole: incluye la cláusula §13 que obliga a publicar el código fuente derivado **cuando el software se ofrece a usuarios remotos por una red**, no solo cuando se distribuye un binario.

## Decisión

Adoptamos **AGPL-3.0** como licencia del proyecto. El archivo `LICENSE` en la raíz del repo contiene el texto completo de la licencia. El `README.md` incluye el badge correspondiente y una nota explicativa.

Implicaciones operativas:

- Cualquier despliegue público (incluso SaaS) debe publicar el código fuente derivado.
- Las contribuciones al repo se aceptan bajo los términos de AGPL-3.0 (DCO implícito al firmar el commit).
- El cambio de licencia post-defensa requiere consenso de **todos los contribuidores** que tengan commits en `main`.

## Alternativas consideradas

### Opción A — MIT
- **Pros:** La más permisiva y conocida; máxima adopción.
- **Contras:** Permite que un tercero ofrezca el software como SaaS cerrado sin publicar mejoras.
- **Por qué se descartó:** No alinea con el valor "el software es libre y se mantiene libre".

### Opción B — Apache-2.0
- **Pros:** Permisiva como MIT pero con cláusula explícita de patentes.
- **Contras:** Mismo loophole SaaS que MIT.
- **Por qué se descartó:** Misma razón que MIT respecto al loophole.

### Opción C — GPL-3.0
- **Pros:** Copyleft fuerte para distribución de binarios.
- **Contras:** No cubre el caso SaaS; un tercero puede ofrecer COMAND-IA como servicio cerrado modificando el código sin publicar las mejoras.
- **Por qué se descartó:** Loophole SaaS abierto.

### Opción D — AGPL-3.0 (elegida)
- **Pros:** Copyleft fuerte; cierra el loophole SaaS; señal clara de "libre y no privatizable"; DSL del software libre que más alinea con los valores del proyecto.
- **Contras explícitos:** Algunas empresas tienen políticas internas que prohíben usar código AGPL en sus productos cerrados; cambiar de licencia post-proyecto requiere consenso de todos los contribuidores.

### Opción E — BUSL (Business Source License)
- **Pros:** Permite uso libre con restricciones, transición a OSS tras N años.
- **Contras:** No es OSI-approved; complejidad legal alta para un proyecto académico.
- **Por qué se descartó:** Sobre-ingeniería para el contexto.

## Consecuencias

### Positivas
- Cualquier derivado comercial SaaS debe open-source el código → alineado con valores del proyecto.
- Señal clara en el mercado: el software es libre pero no se puede privatizar.
- No se cierra la puerta a colaboraciones académicas o municipales (Capa 3 B2G futura): el código derivado seguirá siendo público.

### Negativas / costo
- Algunas empresas tienen políticas internas que prohíben usar código AGPL. Para el contexto académico esto es irrelevante.
- Cambio de licencia futuro requiere consenso unánime de contribuidores → debe documentarse cada contribuidor en el repo desde el inicio.
- Algunos proveedores de hosting o tiendas de apps tienen restricciones específicas a AGPL — verificar al momento del despliegue público.

### Neutras
- Las dependencias del proyecto siguen sus propias licencias (Flutter es BSD-3, Supabase SDK es Apache-2.0, etc.); no hay conflicto porque AGPL es compatible con esas licencias en proyectos derivados.

## Cumplimiento / verificación

- El archivo `LICENSE` en la raíz contiene el texto literal de AGPL-3.0.
- El badge en `README.md` apunta al archivo de licencia local.
- Cada PR aceptado implica el acuerdo del contribuidor con los términos de la licencia (DCO implícito en el commit).
- Si llega un fork o pull externo bajo licencia incompatible → se rechaza con mensaje explicativo.

## Referencias

- Texto oficial: [GNU AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html).
- Contexto del loophole SaaS: [GNU FAQ on AGPL](https://www.gnu.org/licenses/why-affero-gpl.html).
- ADRs relacionados: ninguno directo (decisión legal independiente del stack técnico).

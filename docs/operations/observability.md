# Observabilidad

> Qué se observa, dónde y con qué herramienta. Como COMAND-IA es **BaaS-only**, la observabilidad es parcial: lo del cliente se controla (Sentry); lo del servidor se consulta (Supabase Dashboard, Vercel analytics).

## Qué se observa

| Capa | Señal | Herramienta |
|---|---|---|
| Frontend Flutter | Excepciones no capturadas | Sentry |
| Frontend Flutter | Breadcrumbs de navegación (go_router) | Sentry |
| Frontend Flutter | Performance traces (sampling 10%) | Sentry |
| Frontend Flutter web | Web vitals, pageviews | Vercel analytics |
| Backend Supabase | Queries lentas (>1 s) | Supabase Dashboard › Logs |
| Backend Supabase | Errores SQL, conexiones, cuotas | Supabase Dashboard |
| Edge function `/health` | Disponibilidad | uptimerobot (HTTP cada 5 min) |

No hay endpoint `/healthz` o `/readyz` propio porque no controlamos servidor — la matriz de la metodología marca **no aplica** para tipo BaaS-only. Como sustituto, una **edge function Supabase `/health`** retorna `{"status":"ok","ts":"..."}` y se monitorea desde uptimerobot.

## Sentry (frontend)

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = Env.sentryDsn;
    options.tracesSampleRate = 0.1;
  },
  appRunner: () => runApp(const ProviderScope(child: App())),
);
```

- DSN viene de `--dart-define-from-file=.env`.
- `tracesSampleRate = 0.1` — 10% de traces en producción.
- Excepciones no capturadas → Sentry automático.
- Breadcrumbs de navegación incluidos vía integración con `go_router`.

### Reglas para no filtrar datos sensibles

- **Nunca loguear** PIN, JWT, payload completo de pedido con `customer_email`, ni nada de `staff_pin`.
- **Sí loguear** identificadores opacos: `venue_id`, `order_id`, `user_id` (uuids).
- Configurar `beforeSend` en Sentry para sanitizar `Request` y filtrar headers de Auth.

### Alertas

- **Error rate** > 5 errores/min durante 5 min → email al owner del proyecto.
- **Crash-free sessions** < 99% en 24 h → revisión obligatoria del equipo.

Las reglas de alerta se configuran en el dashboard de Sentry; no viven en el repo (son configuración del SaaS).

## Supabase Dashboard

- **Logs** → queries lentas (>1 s), errores SQL, conexiones rechazadas, cuotas.
- **Database** → tamaño actual vs free tier (500 MB), número de tablas y filas.
- **Realtime** → conexiones simultáneas vs free tier (200).
- **Auth** → eventos de login, magic links pendientes, intentos fallidos.

Acceso desde el dashboard de Supabase con el rol del proyecto. El equipo lo revisa **antes y después de demos** y al detectar caída en uptimerobot.

## uptimerobot

- Endpoint monitoreado: edge function `/health` (Supabase).
- Frecuencia: cada 5 min.
- Alerta: email + SMS si cae 2 chequeos consecutivos.
- Free tier es suficiente para un endpoint.

## Vercel analytics

- Tier gratuito: pageviews, web vitals (LCP, FID, CLS).
- No se almacena PII.
- Referencia para cumplimiento de RNF-COMPAT-001 (la app web responde en navegadores objetivo).

## Métricas que NO se monitorean en MVP

Por opt-out académico (ver [opt-outs académicos](../../README.md#metodología-y-opt-outs)):

- **DORA accionables** (lead time, deploy frequency, MTTR, change failure rate) — n=2 personas, ruido estadístico. Se observan como hábito mental, no como métrica.
- **APM granular del backend** — Supabase Dashboard alcanza para academia.
- **Logs centralizados con búsqueda** (Datadog, Loki, etc.) — fuera de presupuesto.

## Rotación de credenciales y revisiones

- DSN de Sentry rota si hay key leak detectado por Sentry o GitGuardian. Documentar en `docs/security/secrets-management.md`.
- Las service role keys de Supabase rotan al cierre del semestre o si hay leak.

## Referencias

- [SRS § 4.5 Security](../requirements/srs.md) — RNF-SEC-004.
- [security/security.md](../security/security.md) — manejo de secretos.
- [operations/runbook.md](runbook.md) — qué hacer cuando algo se rompe.
- [devops/release-process.md](../devops/release-process.md) — observabilidad post-deploy.

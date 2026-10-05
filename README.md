# ParkESCOM

Sistema de control de acceso vehicular para ESCOM-IPN: app Flutter (Android y panel web), API REST en Dart Frog y
PostgreSQL. La planeación completa está en [`docs/planeacion.md`](docs/planeacion.md).

```
app/            Flutter: app Android y panel web
backend/        API en Dart Frog y migrador (bin/migrate.dart)
shared/         paquete Dart puro compartido por app y backend
db/migrations/  migraciones SQL, aplicadas en orden
db/seeds/       catálogos (puertas y zonas)
```

## Requisitos

- Docker con Docker Compose
- Flutter 3.44 o posterior (incluye Dart 3.12)
- `dart_frog_cli`: `dart pub global activate dart_frog_cli`

## Configuración

1. Copia `.env.example` como `.env` en la raíz y llena los valores. El `.env` no se sube a Git.

   ```bash
   cp .env.example .env
   ```

2. Para desarrollo local bastan las variables de la base:

   ```
   POSTGRES_USER=parkescom
   POSTGRES_PASSWORD=<una contraseña>
   POSTGRES_DB=parkescom
   DATABASE_URL=postgres://parkescom:<la contraseña>@localhost:5432/parkescom
   DATABASE_URL_TEST=postgres://parkescom:<la contraseña>@localhost:5432/parkescom_test
   ```

   `DATABASE_URL_TEST` debe apuntar a una base distinta: las pruebas la borran y la recrean en cada corrida.

3. Si el puerto 5432 ya está ocupado en tu equipo (por ejemplo, por un PostgreSQL instalado en Windows), agrega
   `POSTGRES_PORT=5433` al `.env` y usa ese mismo puerto en las dos URLs.

El backend toma las variables del entorno del proceso y, si no están, del `.env` de la raíz.

## Base de datos

```bash
docker compose up -d db            # levanta PostgreSQL 16, solo en 127.0.0.1
docker compose ps                  # debe decir "healthy"

cd backend
dart pub get
dart run bin/migrate.dart --seed   # aplica db/migrations y los catálogos de db/seeds
```

El migrador registra cada versión en `schema_migrations`; correrlo otra vez no aplica nada nuevo. Sin `--seed` solo
aplica migraciones. Una migración ya aplicada no se edita: los cambios van en un archivo nuevo (`002_...sql`).

## Pruebas y análisis

```bash
cd backend && dart test            # incluye las pruebas del esquema contra DATABASE_URL_TEST
cd backend && dart analyze
cd shared && dart analyze
cd app && flutter pub get && flutter analyze
```

Antes de cada commit: `dart format .`

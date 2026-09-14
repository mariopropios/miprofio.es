# miProfio.es (app)

Código de la aplicación Flutter. El contexto del producto está en el [README de la raíz](../README.md).

**Web:** [https://miprofio.es](https://miprofio.es)

## Stack

- Flutter / Dart
- Riverpod y Go Router
- Supabase (Auth, PostgreSQL, Storage, Realtime)
- Cloudflare Workers
- Firebase Cloud Messaging

## Local

```powershell
copy .env.example .env
flutter pub get
flutter run -d chrome
```

Usa un proyecto de Supabase propio en `.env`. El `.env` de producción no está en el repositorio.

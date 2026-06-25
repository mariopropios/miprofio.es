# BuildJobs

Plataforma web y móvil responsive estilo TripAdvisor para el sector de la construcción. Permite descubrir empresas, leer reseñas y valorar profesionales del sector.

## Stack

- **Flutter** — UI multiplataforma (web, Android, iOS)
- **Supabase** — Backend (auth, base de datos PostgreSQL, storage)
- **Riverpod** — Gestión de estado
- **Go Router** — Navegación declarativa

## Estructura del proyecto

```
buildjobs/
├── lib/
│   ├── main.dart                 # Punto de entrada + init Supabase
│   ├── app.dart                  # MaterialApp
│   ├── core/
│   │   ├── config/               # Configuración Supabase
│   │   ├── constants/            # Constantes globales
│   │   ├── router/               # Rutas (Go Router)
│   │   └── theme/                # Tema visual (estilo TripAdvisor)
│   ├── features/
│   │   ├── auth/                 # Login / registro
│   │   ├── home/                 # Pantalla principal
│   │   ├── search/               # Búsqueda y filtros
│   │   ├── companies/            # Listado y detalle de empresas
│   │   ├── reviews/              # Escribir reseñas
│   │   ├── profile/              # Perfil de usuario
│   │   └── shell/                # Navegación responsive (bottom bar / rail)
│   └── shared/
│       ├── models/               # Company, Review, UserProfile
│       └── widgets/              # Componentes reutilizables
├── supabase/
│   └── migrations/               # Esquema SQL inicial
├── web/                          # Configuración web
└── assets/images/                # Imágenes estáticas
```

## Requisitos previos

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+)
2. [Cuenta en Supabase](https://supabase.com)

## Configuración

### 1. Instalar Flutter (si no lo tienes)

Descarga Flutter desde https://docs.flutter.dev/get-started/install/windows

### 2. Generar carpetas de plataforma

Desde la carpeta del proyecto, ejecuta:

```powershell
cd D:\BuildJobs\buildjobs
flutter create . --project-name buildjobs --org com.buildjobs
```

Esto generará las carpetas `android/`, `ios/`, `windows/`, etc.

### 3. Instalar dependencias

```powershell
flutter pub get
```

### 4. Configurar Supabase

1. Crea un proyecto en [Supabase](https://supabase.com)
2. Copia `.env.example` a `.env`:
   ```powershell
   copy .env.example .env
   ```
3. Rellena `SUPABASE_URL` y `SUPABASE_ANON_KEY` con los valores de tu proyecto
4. Ejecuta el SQL de `supabase/migrations/001_initial_schema.sql` en el SQL Editor

### 5. Ejecutar la app

```powershell
# Web (responsive)
flutter run -d chrome

# Windows desktop
flutter run -d windows

# Android (con emulador o dispositivo conectado)
flutter run -d android
```

## Funcionalidades planificadas

- [x] Estructura inicial y navegación responsive
- [x] Pantallas: inicio, búsqueda, empresas, detalle, reseñas, perfil, auth
- [x] Esquema de base de datos Supabase
- [ ] Conectar repositorios con datos reales
- [ ] Autenticación completa con Supabase Auth
- [ ] Subida de fotos (Storage)
- [ ] Geolocalización y mapas
- [ ] Favoritos y listas personalizadas

## Licencia

Proyecto privado.

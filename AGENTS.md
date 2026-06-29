# Time's Up Flutter — Project Documentation

## Propósito

**Time's Up Flutter** es una aplicación de control parental que permite a los padres monitorear el tiempo de pantalla de sus hijos. La app tiene dos roles:

- **Parent Side (Lado del padre):** Dashboard con estadísticas de uso de apps, ubicación GPS del hijo en tiempo real (Google Maps), notificaciones push, gestión de perfil del hijo, configuración de idioma y tema.
- **Child Side (Lado del hijo):** Pantalla vinculada al dispositivo del niño que reporta datos de uso de aplicaciones, ubicación y estado de batería al padre a través de Firebase.

---

## Stack Tecnológico

| Capa              | Tecnología                                                  |
| ----------------- | ----------------------------------------------------------- |
| Framework         | Flutter 3.41.9 (Dart SDK ≥2.16.0 <4.0.0)                   |
| Estado            | Provider + flutter_bloc (BLoC para child_side)              |
| Backend           | Firebase (Auth, Firestore, Storage, Messaging)              |
| Autenticación     | Firebase Auth, Google Sign-In, Facebook Login               |
| Base de datos     | Cloud Firestore                                             |
| Almacenamiento    | Firebase Storage (fotos de perfil)                          |
| Notificaciones    | Firebase Messaging + flutter_local_notifications            |
| Mapas             | Google Maps Flutter + Geolocator + Geocoding                |
| Servicio de fondo | flutter_background_service                                  |
| Análisis          | fl_chart (gráficos), app_usage (uso de apps)                |
| Tema              | Google Fonts, temas claro/oscuro con ThemeNotifier           |
| i18n              | flutter_localizations + intl + archivos ARB en `lib/l10n/`  |
| Análisis estático | very_good_analysis                                          |
| Código generado   | freezed_annotation + json_annotation (archivos pre-generados)|

---

## Estructura del Proyecto

```
Times-up-flutter/
├── android/                        # Configuración nativa Android
│   ├── app/
│   │   ├── build.gradle            # Plugins declarativos, flavors, signing
│   │   ├── google-services.json    # Configuración Firebase por flavor
│   │   └── src/
│   │       ├── main/               # AndroidManifest principal
│   │       ├── debug/              # Manifest de debug
│   │       ├── profile/            # Manifest de profile
│   │       ├── development/        # Manifest del flavor development
│   │       └── staging/            # Manifest del flavor staging
│   ├── build.gradle                # Root build con namespace injection
│   ├── settings.gradle             # Plugin management (AGP, Kotlin, GMS)
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties
├── lib/
│   ├── main_development.dart       # Entry point: flavor development
│   ├── main_staging.dart           # Entry point: flavor staging
│   ├── main_production.dart        # Entry point: flavor production
│   ├── bootstrap.dart              # Inicialización común de la app
│   ├── firebase_options_dev.dart   # Opciones Firebase para development
│   ├── app/
│   │   ├── app.dart                # TimesUpApp widget raíz
│   │   ├── screen_controller.dart  # Router principal (parent/child)
│   │   ├── config/                 # Configuración de rutas y temas
│   │   ├── helpers/                # Utilidades de UI
│   │   ├── lifecycle/              # AppLifecycleState observers
│   │   └── features/
│   │       ├── landing_page.dart   # Página de bienvenida
│   │       ├── sign_in/            # Flujo de autenticación
│   │       ├── splash/             # Splash screen
│   │       ├── parent_side/        # Funcionalidades del padre
│   │       │   ├── parent_page.dart
│   │       │   ├── child_details_page.dart
│   │       │   ├── map_page.dart
│   │       │   ├── notification_page.dart
│   │       │   ├── app_list_page.dart
│   │       │   ├── edit_child_page.dart
│   │       │   ├── setting_page.dart
│   │       │   └── language/       # Localización (LanguageNotifier)
│   │       └── child_side/         # Funcionalidades del hijo
│   │           ├── child_page.dart
│   │           ├── set_child_page.dart
│   │           └── bloc/           # BLoC para estado del child
│   ├── models/
│   │   ├── child_model/            # Modelo de datos del hijo
│   │   ├── email_model.dart        # Modelo de email
│   │   └── notification_model/     # Modelo de notificaciones
│   ├── services/
│   │   ├── auth.dart               # AuthBase + Auth (Firebase Auth)
│   │   ├── database.dart           # Operaciones Firestore
│   │   ├── firestore_service.dart   # Capa de acceso a Firestore
│   │   ├── notification_service.dart
│   │   ├── geo_locator_service.dart
│   │   ├── app_usage_service.dart
│   │   ├── app_usage_local_service.dart
│   │   ├── app_info_service.dart
│   │   ├── internet_connectivity_service.dart
│   │   ├── shared_preferences.dart
│   │   └── api_path.dart           # Rutas de API Firestore
│   ├── theme/                      # ThemeNotifier (dark/light mode)
│   ├── utils/                      # Utilidades generales
│   └── widgets/                    # Widgets reutilizables
├── l10n.yaml                       # Configuración de localización
├── assets/
│   └── map_theme/                  # Temas personalizados para Google Maps
├── images/                         # Assets de imágenes (logos, splash SVGs, PNGs)
├── pubspec.yaml                    # Dependencias y configuración del proyecto
├── analysis_options.yaml           # Reglas de análisis estático
└── test/                           # Tests unitarios y de widgets
```

---

## Configuración de Firebase

- **google-services.json**: Ubicado en `android/app/`. Contiene la configuración del proyecto Firebase (project_id, API keys, etc.).
- **firebase_options_dev.dart**: Ubicado en `lib/`. Generado por FlutterFire CLI, contiene `DefaultFirebaseOptions` para inicialización multiplataforma.
- **Servicios Firebase utilizados:**
  - `firebase_auth` — Autenticación (email, Google, Facebook)
  - `cloud_firestore` — Base de datos en tiempo real
  - `firebase_storage` — Almacenamiento de archivos (fotos)
  - `firebase_messaging` — Notificaciones push

---

## Flavors (Sabores)

El proyecto usa **3 product flavors** definidos en `android/app/build.gradle`:

| Flavor        | Entry Point                  | App Name                   | Uso               |
| ------------- | ---------------------------- | -------------------------- | ------------------ |
| `development` | `lib/main_development.dart`  | `[DEV] Times Up Flutter`   | Desarrollo local   |
| `staging`     | `lib/main_staging.dart`      | `[STG] Times Up Flutter`   | Pruebas pre-prod   |
| `production`  | `lib/main_production.dart`   | `Times Up Flutter`         | Producción         |

### Comandos de compilación

```bash
# Development
flutter build apk --flavor development -t lib/main_development.dart

# Staging
flutter build apk --flavor staging -t lib/main_staging.dart

# Production
flutter build apk --flavor production -t lib/main_production.dart
```

---

## Dependencias Principales

### UI y Diseño
- `auto_size_text` — Texto auto-ajustable
- `fl_chart` — Gráficos y estadísticas
- `flutter_svg` — Renderizado de SVG
- `google_fonts` — Tipografías de Google
- `line_awesome_flutter` — Iconos Line Awesome
- `showcaseview` — Guías de onboarding
- `shimmer` — Efectos de carga shimmer

### Autenticación
- `firebase_auth` — Auth Firebase
- `google_sign_in` — Login con Google
- `flutter_login_facebook` — Login con Facebook

### Datos y Estado
- `provider` — Gestión de estado principal
- `bloc` / `flutter_bloc` — BLoC para child_side
- `cloud_firestore` — Base de datos
- `shared_preferences` — Almacenamiento local
- `freezed_annotation` / `json_annotation` — Serialización (archivos generados)

### Localización y Mapas
- `geolocator` — Coordenadas GPS
- `geocoding` — Geocodificación inversa
- `google_maps_flutter` — Mapas interactivos

### Notificaciones
- `firebase_messaging` — Push notifications
- `flutter_local_notifications` — Notificaciones locales
- `flutter_background_service` — Servicio en segundo plano

### Utilidades
- `app_usage` — Estadísticas de uso de apps
- `battery_plus` — Estado de batería
- `device_info_plus` — Info del dispositivo
- `image_picker` — Selector de imágenes
- `internet_connection_checker` — Conectividad
- `share_plus` — Compartir contenido
- `intl` — Internacionalización

---

## Migración a Flutter 3.41.9 — Cambios Realizados

### 1. `pubspec.yaml`
- SDK constraint: `">=2.16.0 <4.0.0"` (antes: `">=2.16.0 <3.0.0"`)
- Se comentaron `dev_dependencies` conflictivas: `mocktail`, `freezed`, `json_serializable`, `build_runner`, `bloc_test` — los archivos generados (`.freezed.dart`, `.g.dart`) ya existen en el repo.

### 2. `android/settings.gradle`
- Migrado de `buildscript`/`allprojects` a **plugins declarativos** con `pluginManagement`.
- Versiones actuales:
  - AGP: **8.7.3** (mínimo requerido por Flutter: 8.6.0)
  - Kotlin: **2.1.0** (mínimo requerido por Flutter: 2.1.0)
  - Google Services: **4.4.0**
  - Flutter Plugin Loader: **1.0.0**

### 3. `android/build.gradle` (raíz)
- Eliminado `buildscript` y `allprojects` antiguos.
- Solo contiene: `rootProject.buildDir`, `subprojects`, y `task clean`.
- **Agregado: namespace injection automática** para plugins legacy que no declaran `namespace` en su `build.gradle`:
  ```groovy
  subprojects {
      afterEvaluate { project ->
          if (project.plugins.hasPlugin("com.android.library")) {
              project.android {
                  if (namespace == null || namespace.toString().isEmpty()) {
                      def manifest = new XmlSlurper().parse(
                          file("${project.projectDir}/src/main/AndroidManifest.xml")
                      )
                      namespace = manifest.@package.toString()
                  }
              }
          }
      }
  }
  ```

### 4. `android/app/build.gradle`
- Migrado a plugins declarativos: `com.android.application`, `kotlin-android`, `dev.flutter.flutter-gradle-plugin`, `com.google.gms.google-services`.
- **Agregado:** `namespace "com.jordyhers.times_up_flutter"` (requerido por AGP 8+).
- `compileSdkVersion 34`, `targetSdkVersion 34`.
- Kotlin stdlib actualizado a `kotlin-stdlib-jdk7:2.1.0`.

### 5. `android/gradle/wrapper/gradle-wrapper.properties`
- Gradle actualizado a **8.11.1** (requerido por AGP 8.7.x).

### 6. Archivos Firebase
- `google-services.json` → copiado a `android/app/`
- `firebase_options_dev.dart` → copiado a `lib/`

---

## Advertencias Conocidas

- **`flutter_local_notifications_linux`**: El paquete `flutter_local_notifications` referencia `flutter_local_notifications_linux` como plugin por defecto para Linux, pero el paquete no existe. Esto **no afecta** la compilación Android y es un problema del mantenedor del paquete.
- **Paquetes desactualizados**: 166 paquetes tienen versiones más nuevas incompatibles con las restricciones actuales. Usar `flutter pub outdated` para detalles.

---

## Requisitos del Entorno

- **Flutter**: 3.41.9+
- **Dart SDK**: ≥2.16.0 <4.0.0
- **Android SDK**: compileSdk 34, minSdk 28, targetSdk 34
- **Gradle**: 8.11.1
- **AGP**: 8.7.3
- **Kotlin**: 2.1.0
- **Java**: 1.8 (sourceCompatibility/targetCompatibility)
- **Dispositivo probado**: Samsung SM-A065M, Android 16

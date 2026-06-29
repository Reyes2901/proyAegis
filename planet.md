# 🧠 Instrucciones para el Agente IDE – Resolver conflictos de dependencias en `times_up_flutter`

## 📌 Contexto actual
- **Proyecto**: `times_up_flutter`
- **Flutter SDK**: 3.41.9, Dart 3.11.5
- **Error actual** en `flutter pub get`:


mocktail ^0.3.0 is incompatible with freezed >=2.2.0 <3.0.0-0.0.dev

text
- **Causa raíz**: `mocktail 0.3.0` usa versiones antiguas de `test_api` (0.2.x, 0.3.x, 0.4.x) que son incompatibles con la versión de `test_api` que impone `flutter_test` (0.7.10). `freezed 2.3.5` también tiene restricciones que entran en conflicto con `mocktail`.

## 🎯 Objetivo
Dejar el `pubspec.yaml` con dependencias que **resuelvan todas juntas** sin conflictos, usando **solo actualizaciones necesarias** (no actualizar todo a lo loco) y forzando versiones con `dependency_overrides` cuando sea estrictamente necesario.

---

## 🛠️ Pasos que debe ejecutar el agente IDE

### 1. Modificar la sección `dev_dependencies`
Reemplazar el bloque actual por:
```yaml
dev_dependencies:
bloc_test: ^9.1.1
build_runner: ^2.3.3
flutter_test:
  sdk: flutter
freezed: ^2.4.2          # actualizada
json_serializable: ^6.6.2
mocktail: ^1.0.0         # actualizada (compatible con test_api >=0.7.0)
very_good_analysis: ^5.0.0  # actualizada (opcional pero recomendable)
2. Eliminar la dependencia test de dependencies
En dependencies, buscar la línea test: any y eliminarla porque flutter_test ya la incluye y puede causar conflictos.

3. Conservar los dependency_overrides actuales
Asegurarse de que el archivo tenga al final:

yaml
dependency_overrides:
  web: ^1.0.0
  mime: ^2.0.0
  http: ^1.0.0
Si surge algún otro conflicto después de los cambios, se puede agregar un override adicional, pero solo si es necesario.

4. Ejecutar los comandos de limpieza y resolución
bash
flutter clean
flutter pub get
5. Verificar que la aplicación compile
bash
flutter run --flavor development -t lib/main_development.dart
⚠️ Restricciones importantes
NO usar flutter pub upgrade --major-versions porque actualiza todo y rompe el código.

NO cambiar versiones de otros paquetes a menos que sea estrictamente necesario para resolver un conflicto.

Si pub get falla después de los cambios, usar dependency_overrides para forzar versiones específicas (por ejemplo, test_api: 0.7.10) en lugar de actualizar más paquetes.

✅ Criterios de éxito
flutter pub get finaliza sin errores.

flutter run compila y la aplicación arranca.

No aparecen más conflictos de dependencias en la consola.

📄 Resultado esperado del pubspec.yaml final
Solo se muestran las secciones modificadas; el resto del archivo se mantiene igual.

yaml
dependencies:
  # ... (todo igual, pero eliminando "test: any") ...

dev_dependencies:
  bloc_test: ^9.1.1
  build_runner: ^2.3.3
  flutter_test:
    sdk: flutter
  freezed: ^2.4.2
  json_serializable: ^6.6.2
  mocktail: ^1.0.0
  very_good_analysis: ^5.0.0

dependency_overrides:
  web: ^1.0.0
  mime: ^2.0.0
  http: ^1.0.0
📤 Entregable esperado
El agente debe devolver:

El archivo pubspec.yaml completo con los cambios aplicados.

La salida completa de flutter pub get después de los cambios.

La salida de flutter run (o indicar si compiló correctamente).

¡Manos a la obra! 🚀

text

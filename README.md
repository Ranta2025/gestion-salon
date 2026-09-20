# Gestión Salón

App móvil para la administración financiera de un salón de belleza: registro de
ingresos y gastos diarios, clientes, catálogos, citas, reportes, cierre de caja
y metas mensuales. Funciona **100 % offline** en Android y iOS.

> Idioma de la app: español. Código, identificadores y comentarios: inglés.

## Funcionalidades

- **Ingresos**: fecha/hora (automática y editable), monto, servicio (catálogo con
  precio sugerido que autocompleta el monto), cliente (selección o creación
  inline), empleada (texto libre con sugerencias), método de pago
  (efectivo, transferencia, tarjeta, otro) y nota opcional.
- **Gastos**: fecha, monto, categoría (catálogo configurable), proveedor,
  método de pago y nota opcional.
- **Dashboard**: balance día/semana/mes/año, gráfico circular pastel
  (menta = ingresos, coral = gastos) con balance neto, circular de gastos por
  categoría, tendencia mensual ingresos vs. gastos, últimos 5 movimientos,
  progreso de meta mensual y acción de cierre de caja.
- **Clientes**: alta con nombre, teléfono y notas, búsqueda por nombre, ficha
  con historial de visitas (movimientos de ingreso asociados) y total gastado.
- **Citas**: agenda con estados (pendiente, completada, cancelada), historial y
  recordatorios por notificación local.
- **Reportes**: filtros por rango de fechas, categoría, empleada y tipo
  (ingreso/gasto), con totales y exportación a **PDF** (título, período,
  gráfico y tabla) y **CSV** compatible con Excel. Todo generado localmente.
- **Cierre de caja diario**: resumen del día (ingresos, gastos, neto) con
  snapshot guardado e historial. Cerrar el mismo día actualiza el snapshot.
- **Metas mensuales**: objetivo de ingreso mensual con barra de progreso en el
  dashboard.
- **Backup y restore**: exportación de todo a un JSON y restauración offline
  (clientes, servicios, categorías, movimientos, cierres y metas, con ids
  preservados). La restauración valida formato/versión y no toca los datos si
  el archivo es inválido.

## Stack técnico

| Capa      | Elección |
|-----------|----------|
| Framework | Flutter 3.47 (Dart 3.13), Android + iOS |
| Base local| sqflite (SQLite), única fuente de verdad |
| Estado    | Provider + ChangeNotifier, sin codegen |
| Gráficos  | fl_chart (circular + líneas) |
| Exportar  | pdf + printing (PDF), CSV vía share_plus |
| Backup    | JSON (file_picker + share_plus + path_provider) |
| Formato   | intl (locale `es`) |
| Notifs.   | flutter_local_notifications + timezone |

Sin dependencias de red: sin google_fonts, sin HTTP, sin servicios cloud. El
manifest de release **no** pide permiso de INTERNET.

## Arquitectura

```text
ui/screens + ui/widgets → state (controllers) → data/repositories → data/db (sqflite)
```

- Las pantallas nunca tocan la base de datos directamente.
- Un `XController extends ChangeNotifier` por funcionalidad, con su repositorio,
  campos planos y `refresh()`. Se registran como `ChangeNotifierProvider.value`
  en `lib/app.dart` y se instancian por adelantado (no lazy) en `lib/main.dart`.
- El esquema vive en `lib/data/db/app_database.dart` (`_onCreate`). Los
  repositorios son clases planas con métodos `insert/update/delete/byId/query`.
- Modelos inmutables en `lib/data/models/models.dart`, con `id` anulable y par
  `toMap()`/`fromMap()`. Fechas como strings ISO-8601
  (`yyyy-MM-dd HH:mm:ss` en movimientos, `yyyy-MM-dd` en claves de día,
  `yyyy-MM` en claves de mes).
- Navegación con `Navigator.push(MaterialPageRoute(...))`, sin rutas
  nombradas. Los formularios de alta/edición usan `fullscreenDialog: true`.

## Estructura del proyecto

```text
lib/
  app.dart                  # Composition root (providers + MaterialApp)
  main.dart                 # Bootstrap: intl es, settings, notificaciones, controllers
  core/theme/app_theme.dart # AppColors / AppTheme (paleta pastel, sin hardcodear)
  core/utils/               # date_helpers, formatters, labels
  data/db/app_database.dart # Esquema SQLite + migraciones
  data/models/models.dart   # Modelos inmutables
  data/repositories/        # appointment, catalog, client, finance, movement
  services/                 # backup, export (PDF/CSV), notifications
  state/                    # appointments, catalog, clients, dashboard, movements, settings
  ui/screens/               # dashboard, movements, clients, reports, appointments,
                            # cash_close, catalogs, settings, splash + home_shell
  ui/widgets/               # ios_card, empty_state, section_title, charts, tiles
test/
  repository_test.dart           # Repositorios contra SQLite en memoria (sqflite_common_ffi)
  appointments_controller_test.dart
  notification_service_test.dart
```

## Requisitos

- Flutter 3.47+ (probado con 3.47.4) y Dart 3.13+
- Android SDK / Xcode para compilar en cada plataforma
- Sin backend ni claves: todo es local

## Instalación y ejecución

```bash
flutter pub get
flutter run
```

Dispositivos / emuladores habituales:

```bash
flutter run -d android
flutter run -d ios
```

## Calidad: análisis y tests

```bash
flutter analyze
flutter test
```

- Los tests de repositorios corren contra SQLite real en memoria vía
  `sqflite_common_ffi` (ver `test/repository_test.dart`), sin mocks de BD.
- La lógica pura (cálculos, helpers de fecha/hora) se testea aislada de
  platform channels.

## Compilación release

```bash
flutter build apk --release        # Android
flutter build appbundle --release  # Android (Play Store)
flutter build ipa --release        # iOS
```

## Convenciones

- UI solo Material (nada de Cupertino), textos en español.
- Reutilizar `AppColors`/`AppTheme` y widgets compartidos (`IosCard`,
  `EmptyState`, `SectionTitle`, patrón picker-tile) en vez de duplicar layout.
- Formularios: `Form` + `GlobalKey<FormState>` + `ListView` de
  `TextFormField`/`DropdownButtonFormField`. Diálogos con `showDialog<T>` +
  `AlertDialog` y botones `TextButton` (Cancelar) / `FilledButton` (Guardar).
- Ritmo de espaciado: padding de 16, `SizedBox(height: 8/12/16/24)`,
  `BorderRadius.circular(12–20)`.
- No sumar dependencias nuevas para algo que el stack actual ya cubre
  (Provider, sqflite, fl_chart, intl).

## Documentación de diseño

- `openspec/project.md`: por qué / qué / stack del proyecto.
- `openspec/specs/salon-finance/spec.md`: requisitos y escenarios
  (registro, dashboard, clientes, reportes, cierre, metas, backup, offline).
- `AGENTS.md`: reglas de code review (arquitectura, UI, testing).

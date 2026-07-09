# Quebrado App

Quebrado App es una aplicación móvil de finanzas personales diseñada especialmente para economías de alta inflación y multi-moneda (como Venezuela). Permite a los usuarios llevar un registro preciso de sus cuentas, transacciones y presupuestos en Bolívares (VES), Dólares (USD) y Euros (EUR), sincronizando automáticamente tasas oficiales (BCV) y paralelas.

## Características Principales

- 🇻🇪 **Soporte Multi-moneda Avanzado**: Manejo nativo de USD, EUR y VES con conversión automática y registro histórico de tasas oficiales y paralelas.
- 💰 **Bolsillos de Ahorro**: Permite apartar y proteger fondos en USD directamente de tus balances líquidos para cubrir metas de ahorro o cuotas futuras.
- 🔄 **Obligaciones y Pagos Recurrentes**: Proyección de gastos e ingresos futuros periódicos para estimar la salud financiera.
- 🛡️ **Seguridad**: Protección de datos mediante autenticación biométrica y código PIN de 4 dígitos.
- 💾 **Respaldos y Portabilidad**:
  - Copias de seguridad automáticas diarias.
  - Copias manuales instantáneas.
  - **Exportar/Compartir copias**: Permite generar archivos JSON portátiles de respaldo y compartirlos a otros dispositivos.
  - **Importar copias**: Permite restaurar datos desde archivos JSON de copia de seguridad generados en otros dispositivos.

## Estructura del Proyecto

- `quebrado-app-flutter/`: Código fuente de la aplicación desarrollada en Flutter.
  - `lib/viewmodels/`: Gestión de estado centralizado (AppState con Provider).
  - `lib/services/`: Base de datos SQLite local, servicios de tasas y copias de seguridad.
  - `lib/screens/`: Pantallas de Dashboard, Bolsillos, Historial de Tasas, Timeline y Configuración.
  - `lib/widgets/`: Componentes gráficos claymórficos y filas de eventos del Timeline.

## Requisitos de Construcción

- **Flutter**: `>= 3.19.0`
- **Dart**: `>= 3.3.0`
- **Java**: JDK 17 (para compilaciones Android)

### Compilación y Ejecución

Para iniciar la aplicación en modo desarrollo:
```bash
cd quebrado-app-flutter
flutter pub get
flutter run
```

Para generar la APK de lanzamiento (Release):
```bash
flutter build apk --release
```

# Prueba de viabilidad de hardware (MC33xR)

App desechable para saber qué entrega el MC33xR antes de la Fase 4. No forma parte de ParkESCOM: no usa `app/`,
`backend/` ni `shared/`, no tiene red ni base de datos.

**TODO está sin verificar en hardware real; solo se pudo compilar.** Lo que este documento dice sobre el
comportamiento de DataWedge, del RFID y del NFC sale de leer el código fuente de los paquetes, no de una lectura real.

Lo único comprobado en el equipo (MC3300x, Android 14, serie `26201523020667`) es el arranque: el APK se instala, la
app abre sin cerrarse y el sistema lista el receptor de `mx.ipn.escom.hardwaretest.SCAN_EVENT` como registrado
(`adb shell dumpsys activity broadcasts`). No se hizo ninguna lectura de RFID, código de barras ni NFC.

Preguntas que debe responder, en orden de importancia:

1. ¿DataWedge entrega el TID de un tag RFID?
2. ¿`flutter_datawedge` muestra los datos RFID y su origen?
3. ¿Funciona el plan B sin plugin (salida Keystroke a un campo de texto)?
4. ¿`nfc_manager` lee calcomanías NFC en este equipo?

## Datos de la compilación

| Dato | Valor |
| --- | --- |
| applicationId | `mx.ipn.escom.hardwaretest` |
| minSdk | 24 (lo sube `nfc_manager`; `flutter_datawedge` pide 19) |
| targetSdk | 36 |
| Flutter / Dart | 3.44.0 / 3.12.0 |
| Gradle / AGP / Kotlin | 9.1.0 / 9.0.1 / 2.3.20 |
| Paquetes | `flutter_datawedge` 3.2.0, `nfc_manager` 4.2.1 |

Los dos paquetes compilan sin parches. Flutter avisa que ambos aplican el plugin de Kotlin de Gradle por su cuenta y
que una versión futura de Flutter dejará de compilarlos así; hoy es solo una advertencia.

## Análisis de paquetes

Leído en el pub cache (`README.md`, `lib/` y `android/src/main/kotlin/`).

### flutter_datawedge 3.2.0

1. **Qué expone:** `onScanResult` (`ScanResult` con `data`, `labelType` y `source`, los tres `String`),
   `onScannerStatus`, `onScannerEvent` (resultado de cada comando), `scannerControl`, `enableScanner`,
   `activateScanner`, `requestProfiles` y `requestActiveProfile`. `createDefaultProfile` y `updateProfile` existen y
   **esta app no los llama**. El README del paquete menciona `dispose()`, pero la clase no lo tiene.
2. **RFID contra código de barras y origen del dato:** el paquete no los distingue por sí mismo; solo copia tres
   extras del intent: `com.symbol.datawedge.source` → `source`, `data_string` → `data` y `label_type` → `labelType`.
   Si DataWedge pone `rfid` en `source`, se verá ahí (es lo que hay que comprobar). No expone los bytes crudos
   (`decode_data`) ni ningún otro extra: si el TID o el RSSI viajan en otro campo, el paquete no los muestra.
3. **Comandos genéricos:** **no** en su API pública. El enum `DatawedgeApiTargets` solo trae `SOFT_SCAN_TRIGGER`,
   `SCANNER_INPUT_PLUGIN`, `GET_PROFILES_LIST`, `SET_CONFIG` y `GET_ACTIVE_PROFILE`, y el método que envía comandos
   es privado. No existe `SOFT_RFID_TRIGGER`. El lado nativo sí reenvía cualquier par comando-texto por el canal
   `channels/command`, método `sendDataWedgeCommandStringParameter`; los botones "RFID START" y "RFID STOP" usan ese
   canal interno directamente desde Dart. No es API documentada y puede cambiar entre versiones del paquete.
4. **Intent que escucha:** acción `<applicationId>.SCAN_EVENT` (aquí `mx.ipn.escom.hardwaretest.SCAN_EVENT`),
   categoría `android.intent.category.DEFAULT`, entrega por **Broadcast**. El mismo receptor escucha además
   `com.symbol.datawedge.api.RESULT_ACTION` y `NOTIFICATION_ACTION`.
5. **Manifiesto y Android 14:** no pide nada en el manifiesto (ni permisos ni `<queries>`). El receptor se registra
   en código con `RECEIVER_EXPORTED` cuando el equipo es Android 13 o superior
   (`FlutterDatawedgePlugin.onListen`), así que cumple la regla de Android 14 con targetSdk 36. El receptor no se
   da de baja al cancelar la suscripción, solo al cerrar la app; por eso se crea una sola instancia.

### nfc_manager 4.2.1

1. **Qué expone:** `NfcManager.instance.checkAvailability()` (`enabled`, `disabled`, `unsupported`),
   `startSession(pollingOptions, onDiscovered)` y `stopSession()`. En Android la sesión es el modo lector del
   sistema (`enableReaderMode`), que necesita la app en primer plano.
2. **Datos de la etiqueta:** `NfcTagAndroid.from(tag)` da `id` (el UID en bytes) y `techList`. Hay una clase por
   tecnología (`NfcAAndroid` con ATQA y SAK, `MifareUltralightAndroid`, `IsoDepAndroid`, `NfcVAndroid`…).
3. **NDEF:** `NdefAndroid.from(tag)` da tipo, capacidad, si es escribible y `cachedNdefMessage` (el mensaje que
   Android leyó al detectar la etiqueta). Los registros llegan como bytes; el paquete no interpreta texto ni URI
   (eso está en otro paquete, `nfc_manager_ndef`, que aquí no se usa).
4. **Qué NO hace:** no lee etiquetas con la app en segundo plano ni por intent del sistema, y no tiene nada que ver
   con RFID UHF ni con DataWedge. `checkAvailability()` responde `unsupported` cuando el equipo no tiene adaptador.
5. **Manifiesto y Android 14:** pide `android.permission.NFC` (ya está agregado, con `uses-feature` no obligatorio).
   Registra su receptor del estado del adaptador con `RECEIVER_NOT_EXPORTED` en Android 13 o superior.

## Instalación

Con el MC33xR conectado por USB y la depuración USB activada (`adb devices` debe mostrar `26201523020667  device`):

```bash
cd experimentos/hardware_test
flutter pub get
flutter build apk --debug
adb -s 26201523020667 install -r build/app/outputs/flutter-apk/app-debug.apk
```

O en un paso, compilando e instalando: `flutter install --debug -d 26201523020667`.
Para ver la consola mientras se prueba: `flutter run -d 26201523020667`.

## Configuración manual de DataWedge

La app **no crea ni modifica perfiles**. En el equipo: DataWedge → menú → *New profile*, y dentro del perfil:

1. **Associated apps:** `mx.ipn.escom.hardwaretest`, actividad `*`. Perfil habilitado.
2. **Barcode Input:** habilitado.
3. **RFID Input:** habilitado, con **Hardware trigger** habilitado y **Hardware key = Gun trigger**.
   El banco de memoria (Ninguno, EPC o TID) se cambia en cada prueba de la matriz.
4. **Keystroke Output:** habilitado, con **Send ENTER** activado y **retardo entre caracteres de 50 ms**.
5. **Intent Output:** habilitado, con
   - **Intent action:** `mx.ipn.escom.hardwaretest.SCAN_EVENT`
   - **Intent category:** `android.intent.category.DEFAULT` (o vacía; el filtro del paquete acepta ambas)
   - **Intent delivery:** `Broadcast intent`

Con las dos salidas habilitadas, cada lectura llega a la vez como teclado y como intent. La salida de teclado solo
llega a la pestaña Teclado mientras está a la vista; la de intent se registra en cualquier pestaña.

## Pestañas

- **Teclado:** campo de texto oculto con foco permanente. Cada Enter cierra una lectura y muestra el valor crudo
  entre corchetes (sin recortar), su longitud, la hora, los milisegundos desde la lectura anterior del mismo valor y
  el número de repetición. "Búfer sin Enter" enseña lo que va llegando; si DataWedge no manda Enter, se puede cerrar
  la lectura con "Registrar búfer".
- **DataWedge:** escucha `onScanResult` y por cada resultado muestra `toString`, `toJson` y los tres campos, con las
  mismas estadísticas. Botones: "RFID START/STOP" (`SOFT_RFID_TRIGGER`, por el canal interno), "Código START/STOP"
  (`SOFT_SCAN_TRIGGER`, API pública) y "Perfil activo" (solo consulta; la respuesta sale en "Último evento").
- **NFC:** disponibilidad, y una sesión de lectura que muestra UID en hexadecimal, tecnologías, ATQA y SAK, y el
  contenido NDEF si existe. La sesión se cierra al cambiar de pestaña.
- **Registro:** bitácora cronológica de todo lo anterior, con "Copiar todo".

## Matriz de pruebas

Para cada prueba, pegar en "Resultado" lo que salga en la pestaña Registro ("Copiar todo").

| # | Prueba | Configuración | Qué anotar | Resultado |
| --- | --- | --- | --- | --- |
| 1 | Tag propio, pestañas Teclado y DataWedge | RFID Input, banco de memoria **Ninguno** | Valor crudo entre corchetes y longitud en cada pestaña; `source` y `labelType`; si llega algo pegado (espacios, RSSI) | |
| 2 | El mismo tag | Banco de memoria **EPC** | Lo mismo; si el valor cambia respecto a la prueba 1 y en qué | |
| 3 | El mismo tag | Banco de memoria **TID** | Lo mismo; si aparece el TID, su longitud, y si es igual en lecturas repetidas | |
| 4 | Tag de casetas pegado en parabrisas | La configuración que haya entregado el TID | Si responde; valor, longitud y distancia aproximada de lectura | |
| 5 | QR 2D | Barcode Input | Valor, `source` y `labelType`; si `source` distingue esta lectura de las de RFID | |
| 6 | Tag 5 s frente al lector | "Filter duplicate tags" **apagado** y luego **encendido** | Repeticiones en 5 s y milisegundos entre lecturas, en cada caso | |
| 7 | Calcomanía NFC, pestaña NFC | NFC encendido en Ajustes, sesión abierta | Disponibilidad; UID, tecnologías y contenido NDEF; si el UID es igual en lecturas repetidas | |

Además conviene anotar si los botones "RFID START/STOP" disparan la lectura sin apretar el gatillo.

# 🦉 Miriverbs - Gamified English Learning App

**Miriverbs** es una aplicación móvil educativa premium de alto rendimiento diseñada en Flutter para dominar verbos regulares e irregulares en inglés. Utilizando una arquitectura moderna basada en características (**Feature-First Clean Architecture**), la app ofrece una experiencia de gamificación avanzada inspirada en plataformas como Duolingo, integrando un backend en tiempo real con **Supabase**, autenticación por SSO nativo (Google y Apple), notificaciones push híbridas con **Firebase Cloud Messaging (FCM v1)** y un vibrante módulo social competitivo multijugador en tiempo real (PvP).

---

## ✨ Características Principales

### 📈 1. Ruta de Aprendizaje Progresiva (360 Verbos CEFR)
*   **360 Verbos en Inglés**: Cuidadosamente seleccionados y divididos en 6 niveles de dificultad oficiales del Marco Común Europeo: **A1, A2, B1, B2, C1 y C2** (60 verbos por nivel).
*   **Subniveles Incrementales**: Cada nivel contiene exactamente **6 subniveles progresivos de exactamente 10 verbos cada uno**, ordenados alfabéticamente para garantizar consistencia.
*   **Bloqueo y Desbloqueo Estricto**:
    *   Los niveles de dificultad se desbloquean en orden estricto (A2 requiere completar A1 al 100%, B1 requiere A2, etc.).
    *   Los subniveles individuales se desbloquean secuencialmente una vez que el subnivel anterior ha sido aprobado.
*   **Umbral de Aprobación Exigente**: Para aprobar un subnivel y desbloquear el siguiente, el estudiante debe lograr una calificación mínima de **8 aciertos sobre 10** en la sesión de práctica.
*   **Enfoque de Estudio Dinámico**: Al ingresar a la pantalla de verbos, la aplicación enfoca automáticamente la vista en el subnivel activo en desarrollo (el más alto unlocked pero incompleto), eliminando fricción de navegación.

### 🔄 2. Sistema de Repaso Inteligente y Auto-Filtro de Errores
*   **Re-encolado Inmediato de Errores**: Durante las prácticas de verbos, las preguntas falladas no son descartadas de inmediato. En cambio, son re-barajadas y añadidas al final de la sesión de juego.
*   **Círculo de Repaso**: El cuestionario no finaliza hasta que el estudiante responda correctamente todos los verbos.
*   **Integridad de Calificación**: Los aciertos fallados inicialmente se marcan como preguntas de repaso mediante un banner visual ambar (*"Repaso: ¡Habías fallado este verbo anteriormente!"*), asegurando que la puntuación final de aprobación represente la precisión del primer intento del estudiante.

### ⚔️ 3. Duelos Competitivos en Tiempo Real (PvP Arena)
*   **Invitación Push FCM v1**: Reta a oponentes conectados instantáneamente enviando notificaciones push silenciosas/activas mediante una Edge Function Deno en Supabase.
*   **Protección Anti-Toque (Debouncing)**: La barra y botones sociales bloquean interacciones concurrentes durante las llamadas a base de datos, evitando aperturas de pestañas duplicadas o envíos repetidos de retos.
*   **Semilla Compartida y Juego Justo**: Ambos jugadores reciben exactamente las mismas preguntas de verbos gracias a una semilla compartida generada por la base de datos (`word_seed`), garantizando un terreno de juego 100% simétrico.
*   **Detección de Abandono y Desconexiones**:
    *   **Auto-Resuelve por Abandono**: Si un jugador presiona el botón "Abandonar" durante un duelo activo o de espera, el sistema actualiza de inmediato el estado de la sesión en Supabase a `'abandoned'`, permitiendo que el jugador restante reciba una victoria inmediata por defecto y salga de la pantalla de carga.
    *   **Resguardo por Pérdida de Conexión (Timeout 55s)**: Se implementó un temporizador de gracia a nivel de base de datos. Si un contrincante se desconecta de internet, cierra la aplicación o experimenta un fallo, el sistema declara al jugador activo como ganador por defecto al pasar 55 segundos desde el inicio de la partida.
*   **Efectos Inmersivos y Sonido de Combate**: El inicio y envío de retos incluye la reproducción de un efecto de sonido metálico de choque de espadas (`sword_clash.wav`) altamente interactivo.

### 👤 4. Avatares Personalizados y Presencia Social Activa
*   **Owl Mascots Premium**: Tres caricaturas icónicas diseñadas a mano con fondos completamente transparentes (**Miri Feliz, Miri Celebrando y Miri Triste**) que guían al usuario en sus triunfos y fracasos.
*   **Selector de Avatar Integrado**: Los usuarios pueden abrir una hoja modal táctil en la pantalla de inicio para cambiar instantáneamente su foto de perfil en la base de datos por una de nuestras caricaturas, con reflejo visual en tiempo real en todos los componentes sociales.
*   **Motor de Presencia de Tres Estados**: Los estados de conexión de los amigos en el Arena Social Hub se monitorizan en tiempo real:
    *   🟢 **Online**: El usuario está en la app activo.
    *   🟡 **Ausente (Away)**: La aplicación ha pasado a segundo plano o la pantalla del dispositivo se ha bloqueado.
    *   ⚪ **Offline**: El usuario no está conectado.

### 🎥 5. Recursos Audiovisuales y Sourcing Dinámico en Supabase
*   **Video de Presentación Fullscreen**: Un reproductor de video de YouTube que se ejecuta de forma nativa e inline, sin spinners de carga bloqueantes y pausándose automáticamente al salir de la pantalla para evitar fugas de audio en segundo plano.
*   **TikTok Social Link Card**: Un componente visual premium, con un diseño HSL-harmonizado, que enlaza a la cuenta educativa oficial:
    *   📌 **Nombre en Supabase**: `Teacher Miryan❤️👩‍🏫💻`
    *   🔗 **URL de Redirección**: `https://www.tiktok.com/@miryanyanez16`
*   **Sourcing Dinámico**: Tanto el link y nombre de TikTok como el video de presentación del método se consultan dinámicamente desde la tabla `app_configs` en Supabase, permitiendo a los administradores actualizar los enlaces en caliente en cualquier momento.

---

## 🏗️ Estructura del Proyecto (Clean Architecture)

El proyecto sigue una estructura limpia dividida por características de negocio, desacoplando la capa de presentación de la capa de datos:

```
lib/
├── core/
│   ├── data/                  # Syllabus de verbos y assets
│   ├── services/              # AuthService, ProgressService, NotificationService, FriendService, PresenceService
│   ├── theme/                 # Paleta de diseño premium táctil HSL
│   └── widgets/               # GoogleLogo widget vector, TactileButton 3D, SquishyProgressBar, FeedbackToast
└── features/
    ├── auth/                  # Inicio de sesión por Google & Apple SSO
    ├── home/                  # Cuadro de mando, racha de estudio y enlace TikTok
    ├── multiplayer/           # Arena y Amigos social panel, Duelo PvP
    ├── onboarding/            # Slides interactivos y reproductor de video sincronizado
    └── verbs/                 # Subniveles CEFR y Cuestionario Inteligente de Repaso
```

---

## ⚙️ Configuración del Entorno de Base de Datos (Supabase)

Para desplegar la infraestructura de base de datos correspondiente en Supabase, ejecuta las siguientes sentencias SQL dentro del Editor SQL:

```sql
-- 1. Tabla de Configuración de la App
CREATE TABLE public.app_configs (
    key text PRIMARY KEY,
    value text NOT NULL
);

-- Habilitar RLS en app_configs
ALTER TABLE public.app_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public Read App Configs" ON public.app_configs FOR SELECT USING (true);

-- Sembrar valores iniciales
INSERT INTO public.app_configs (key, value) VALUES
('presentation_video_url', 'https://www.youtube.com/watch?v=7dxH6HGHa8I'),
('tiktok_name', 'Teacher Miryan❤️👩‍🏫💻'),
('tiktok_url', 'https://www.tiktok.com/@miryanyanez16')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. Tabla de Progresión de Subniveles
CREATE TABLE public.user_sublevel_progress (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    level_code text NOT NULL,
    sub_level integer NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_sublevel UNIQUE (user_id, level_code, sub_level)
);

-- Habilitar RLS y políticas
ALTER TABLE public.user_sublevel_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own progress" 
ON public.user_sublevel_progress 
FOR ALL TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);
```

---

## 📲 Notificaciones Push y Google SSO (Integración Nativa)

### iOS
1.  **GoogleService-Info.plist**: Registrado bajo el grupo principal **`Runner`** en Xcode. Asegura que el archivo se compile dentro del paquete ejecutable final en `Runner.app/GoogleService-Info.plist`.
2.  **SceneDelegate Deshabilitado**: Retirada la clave `UIApplicationSceneManifest` del archivo `Info.plist`.
3.  **AppDelegate de Flutter**:
    *   Hereda de `FlutterAppDelegate`.
    *   Ejecuta `GeneratedPluginRegistrant.register(with: self)` en el arranque nativo.
    *   Ejecuta `application.registerForRemoteNotifications()` en `didFinishLaunchingWithOptions` para solicitar e inicializar los intercambios de tokens de APNs de forma inmediata.

### Android
*   **Permiso de Notificación**: Registrado el permiso `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` para Android 13+.
*   **Firma SHA-1**: Mapeada la firma SHA-1 local del keystore de depuración en Firebase console para autorizar Google SSO nativo.

---

## 🚀 Inicio Rápido y Desarrollo Local

Para correr el proyecto en tu máquina de desarrollo, sigue estos pasos:

1.  **Instalar dependencias**:
    ```bash
    flutter pub get
    ```
2.  **Limpiar compilaciones previas**:
    ```bash
    flutter clean
    ```
3.  **Ejecutar en tu dispositivo o emulador**:
    ```bash
    flutter run
    ```

### 🛠️ Comandos de Verificación de Calidad

Para garantizar que el código se mantiene 100% libre de errores linter o advertencias de compilación antes de subir una rama, corre el analizador estático:

```bash
flutter analyze
```

El analizador estático debe retornar:
```bash
Analyzing miriverbs...                                          
No issues found! (ran in 3.4s)
```
Esto certifica una salud y robustez excepcionales en la arquitectura y código de la aplicación.

# ☁️ Supabase Edge Functions & Folder Documentation

Esta carpeta contiene la infraestructura serverless de Supabase utilizada para extender las capacidades en la nube de la aplicación **Miriverbs** en tiempo real.

---

## 📂 Estructura de Directorios

```
supabase/
├── README.md                  # Este archivo de documentación técnica
└── functions/                 # Directorio contenedor de Deno Edge Functions
    └── send-push/             # Función serverless para envío de notificaciones push FCM v1
        └── index.ts           # Código fuente TypeScript (Deno) de la función
```

---

## 🚀 1. Supabase Edge Function: `send-push`

La función `send-push` actúa como puente server-to-server seguro para interactuar con la API oficial de **Firebase Cloud Messaging (FCM v1)** utilizando autenticación OAuth2 de Google.

### 📄 Archivo: `supabase/functions/send-push/index.ts`
*   **Lenguaje**: TypeScript.
*   **Entorno de Ejecución**: Deno (V8).
*   **Rol Principal**: Interceptar solicitudes HTTP POST del cliente, autenticar la llamada ante Google, recuperar las credenciales secretas de base de datos e invocar FCM v1.

---

## 🔧 2. Parámetros, Variables y Métodos de la Función

### 2.1 Constantes Globales
*   `corsHeaders` (`object`):
    *   **Tipo**: Objeto con pares clave-valor de cabeceras HTTP.
    *   **Descripción**: Define los permisos de control de acceso a recursos de origen cruzado (CORS). Permite que la función reciba peticiones directas desde clientes web o dispositivos móviles sin bloqueos de seguridad del navegador.
    *   **Cabeceras incluidas**:
        *   `Access-Control-Allow-Origin: '*'` (Permite solicitudes desde cualquier dominio).
        *   `Access-Control-Allow-Headers: 'authorization, x-client-info, apikey, content-type'` (Autoriza las cabeceras estándar de autenticación y metadatos de Supabase).

### 2.2 Método Principal: `Deno.serve`
*   **Tipo**: Método de servidor de Deno.
*   **Rol**: Levanta el servidor HTTP para escuchar peticiones.
*   **Firma**: `(req: Request) => Promise<Response>`
*   **Parámetro de Entrada (`req`)**:
    *   Objeto `Request` nativo de Deno que encapsula la petición HTTP entrante.
*   **Salida (`Response`)**:
    *   Objeto `Response` que devuelve al cliente una respuesta en formato JSON con el estado del envío o un código HTTP de error (`400` / `500`).

---

### 📥 3. Estructura de Entrada HTTP POST (JSON Request Body)
La función procesa un objeto JSON estructurado con las siguientes propiedades:

| Nombre | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `push_token` | `String` | **Sí** | El token FCM único del dispositivo móvil al cual se le enviará la notificación. |
| `title` | `String` | No | El título visible de la notificación push en el dispositivo de destino. |
| `body` | `String` | No | El cuerpo de texto detallado de la notificación push. |
| `data` | `Map<String, String>` | No | Un mapa de datos personalizados opcional útil para navegaciones dinámicas (ej. `session_id`, `type: 'battle_challenge'`). |

---

### 🛠️ 4. Flujo Interno de Ejecución

1.  **Validación de CORS (Preflight)**:
    *   Si el método HTTP es `OPTIONS`, responde de inmediato con HTTP Status `200` y cabeceras CORS.
2.  **Lectura del JSON**:
    *   Deserializa el cuerpo del POST. Si falta `push_token`, responde con error `400` (Bad Request).
3.  **Conexión Segura de Base de Datos**:
    *   Lee las variables del entorno del contenedor de Deno: `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`.
    *   Instancia el cliente administrativo de Supabase de Deno (`createClient`).
4.  **Recuperación del Certificado de Firebase**:
    *   Llama al RPC seguro `get_firebase_service_account`. Este procedimiento en base de datos desencripta y extrae las credenciales confidenciales de la cuenta de servicio de Firebase (guardada en el almacén seguro de Supabase Vault).
5.  **Autenticación de Google OAuth2**:
    *   Crea una instancia de `GoogleAuth` de la librería `@google-auth-library`.
    *   Formatea la llave privada y define el alcance (`scope`) requerido: `https://www.googleapis.com/auth/firebase.messaging`.
    *   Solicita a los servidores de Google un **Access Token** temporal y válido de portador (`Bearer`).
6.  **Estructura y Envío de FCM v1**:
    *   Construye la URL FCM REST del proyecto: `https://fcm.googleapis.com/v1/projects/[PROJECT_ID]/messages:send`.
    *   Ensambla el payload de mensajería respetando el estándar JSON de FCM v1 con configuraciones nativas de sonido y prioridades enbackground para APNs (iOS) y click_action (Android).
    *   Efectúa un `fetch` seguro de red y reenvía el JSON de respuesta exitosa de Firebase al dispositivo que originó la llamada.

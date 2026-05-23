import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { GoogleAuth } from "npm:google-auth-library@^9.0.0";
import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * CORS headers configuration to enable cross-origin web client requests.
 * This is critical since Edge Functions are called directly from client devices.
 */
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/**
 * Main Deno HTTP Server entry point.
 * Serves incoming POST request containing target token, titles, and payload data,
 * and executes a secure Firebase Cloud Messaging (FCM v1) REST request.
 * 
 * @param req - Stdio-provided Request payload.
 * @returns Response - JSON string detailing delivery status or throwing an error message.
 */
Deno.serve(async (req: Request) => {
  // Handle preflight OPTIONS requests required for modern web clients
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Destructure properties from incoming JSON body
    // - push_token: Target device push token (FCM active identifier).
    // - title: Notification display header.
    // - body: Text body content of the alert.
    // - data: Custom key-value map parsed by client on tap (e.g. session_id, battle_challenge type).
    const { push_token, title, body, data } = await req.json();

    if (!push_token) {
      return new Response(JSON.stringify({ error: 'Missing push_token' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Retrieve Firebase service account from database vault using a secure security-definer function
    // - SUPABASE_URL: System environmental variable.
    // - SUPABASE_SERVICE_ROLE_KEY: System environmental variable bypasses RLS rules to fetch secure secrets.
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Call RPC get_firebase_service_account to securely retrieve the encrypted JSON key from Vault
    const { data: serviceAccountJson, error: dbError } = await supabase.rpc('get_firebase_service_account');
    if (dbError || !serviceAccountJson) {
      return new Response(JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT is not configured: ' + (dbError?.message || 'Empty secret') }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse credentials and replace carriage returns in private key to satisfy JWT signer
    const serviceAccount = JSON.parse(serviceAccountJson);
    let privateKey = serviceAccount.private_key;
    if (privateKey) {
      privateKey = privateKey.replace(/\\+n/g, '\n');
    }

    // Initialize GoogleAuth library utilizing credentials parsed from secret Vault
    const auth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: privateKey,
      },
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    // Request a Google OAuth2 Bearer Access Token for the specified Firebase Messaging scope
    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    if (!accessToken) {
      throw new Error("Failed to get Google Access Token");
    }

    // Determine target Firebase project using service account configuration or fallback
    const projectId = serviceAccount.project_id || "miri-verbs";
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // Construct the standard FCM v1 message structure
    // Supports foreground and background behaviors on iOS/APNs and Android.
    const fcmMessage = {
      message: {
        token: push_token,
        notification: {
          title: title || "Miriverbs",
          body: body || "¡Tienes un nuevo mensaje!",
        },
        data: data || {},
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              "content-available": 1,
            },
          },
        },
        android: {
          notification: {
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      },
    };

    // Forward JWT-authorized request to the FCM v1 endpoint
    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmMessage),
    });

    const fcmResult = await fcmResponse.json();

    // Return the delivery payload details to client caller
    return new Response(JSON.stringify({ success: true, result: fcmResult }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

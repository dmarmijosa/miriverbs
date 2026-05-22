import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { GoogleAuth } from "npm:google-auth-library@^9.0.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { push_token, title, body, data } = await req.json();

    if (!push_token) {
      return new Response(JSON.stringify({ error: 'Missing push_token' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Retrieve Firebase service account from database vault using a secure security-definer function
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: serviceAccountJson, error: dbError } = await supabase.rpc('get_firebase_service_account');
    if (dbError || !serviceAccountJson) {
      return new Response(JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT is not configured: ' + (dbError?.message || 'Empty secret') }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    let privateKey = serviceAccount.private_key;
    if (privateKey) {
      privateKey = privateKey.replace(/\\+n/g, '\n');
    }
    const auth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: privateKey,
      },
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    if (!accessToken) {
      throw new Error("Failed to get Google Access Token");
    }

    const projectId = serviceAccount.project_id || "miri-verbs";
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

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

    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmMessage),
    });

    const fcmResult = await fcmResponse.json();

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

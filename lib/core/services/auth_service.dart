import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

// Google Web Client ID for OAuth identification
const _googleWebClientId = '899237516831-4rnv2mv30vfm691sul0m85ks2inh7kep.apps.googleusercontent.com';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  const AuthResult._({required this.success, this.errorMessage, this.user});

  factory AuthResult.ok(User user) => AuthResult._(success: true, user: user);
  factory AuthResult.error(String message) => AuthResult._(success: false, errorMessage: message);
}

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static Session? get currentSession => _supabase.auth.currentSession;

  // ── Register with Email & Password ────────────────────────────────────────
  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.error('No se pudo crear la cuenta.');
      }
      await NotificationService.syncTokenToDatabase();
      return AuthResult.ok(user);
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Error inesperado. Intenta de nuevo.');
    }
  }

  // ── Login with Email & Password ───────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.error('Credenciales incorrectas.');
      }
      await NotificationService.syncTokenToDatabase();
      return AuthResult.ok(user);
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Error inesperado. Intenta de nuevo.');
    }
  }

  // ── Login with Google ─────────────────────────────────────────────────────
  static Future<AuthResult> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.error('Inicio de sesión cancelado.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return AuthResult.error('No se pudo obtener el token de Google.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.error('No se pudo iniciar sesión con Google.');
      }

      // Upsert profile info
      final photoUrl = googleUser.photoUrl;
      final displayName = googleUser.displayName ?? '';
      await _supabase.from('profiles').upsert(
        {
          'id': user.id,
          if (displayName.isNotEmpty) 'full_name': displayName,
          if (photoUrl != null && photoUrl.isNotEmpty) 'avatar_url': photoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );

      await NotificationService.syncTokenToDatabase();
      return AuthResult.ok(user);
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Error al iniciar sesión con Google.');
    }
  }

  // ── Login with Apple ──────────────────────────────────────────────────────
  static Future<AuthResult> loginWithApple({required String idToken, String? accessToken, String? fullName}) async {
    try {
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.error('No se pudo iniciar sesión con Apple.');
      }

      if (fullName != null && fullName.isNotEmpty) {
        await _supabase.from('profiles').upsert(
          {
            'id': user.id,
            'full_name': fullName,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        );
      }

      await NotificationService.syncTokenToDatabase();
      return AuthResult.ok(user);
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Error al iniciar sesión con Apple.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await NotificationService.clearTokenFromDatabase();
    await _supabase.auth.signOut();
  }

  // ── Get User Profile ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      if (data != null && (data['avatar_url'] == null || (data['avatar_url'] as String).isEmpty)) {
        final metaUrl = user.userMetadata?['avatar_url'] as String? ?? user.userMetadata?['picture'] as String?;
        if (metaUrl != null && metaUrl.isNotEmpty) {
          data['avatar_url'] = metaUrl;
        }
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  // ── Error Helper mapping ──────────────────────────────────────────────────
  static String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email already registered') || m.contains('user already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (m.contains('password should be at least')) {
      return 'La contraseña es demasiado corta.';
    }
    if (m.contains('invalid email')) {
      return 'El correo electrónico no es válido.';
    }
    if (m.contains('rate limit exceeded')) {
      return 'Demasiados intentos. Espera unos minutos.';
    }
    return 'Error: $message';
  }
}

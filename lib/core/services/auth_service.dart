import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

// Google Web Client ID for OAuth identification
const _googleWebClientId = '481557558534-5ptcs4ltl5sbohj95cdv7boirs2ore9f.apps.googleusercontent.com';

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
      final googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? '481557558534-2fpuem13he1i1em1hcvkvm82qrglclj5.apps.googleusercontent.com' : null,
        serverClientId: _googleWebClientId,
      );
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
  static Future<AuthResult> loginWithApple() async {
    try {
      final rawCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = rawCredential.identityToken;
      if (idToken == null) {
        return AuthResult.error('No se pudo obtener el Token de Identidad de Apple.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: rawCredential.authorizationCode,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.error('No se pudo iniciar sesión con Apple.');
      }

      final givenName = rawCredential.givenName;
      final familyName = rawCredential.familyName;
      String? fullName;
      if (givenName != null || familyName != null) {
        fullName = '${givenName ?? ''} ${familyName ?? ''}'.trim();
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
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Inicio de sesión cancelado.');
      }
      return AuthResult.error('Error de Apple: ${e.message}');
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

  // ── Update User Avatar ────────────────────────────────────────────────────
  static Future<bool> updateAvatar(String avatarUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      await _supabase.from('profiles').update({'avatar_url': avatarUrl}).eq('id', user.id);
      return true;
    } catch (_) {
      return false;
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

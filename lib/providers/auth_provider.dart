import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/app_settings.dart';
import '../services/supabase_service.dart';
import '../services/local_database_service.dart';
import 'settings_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AuthState()) {
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    // Controlla se c'è un utente salvato localmente
    final localUser = LocalDatabaseService.getCurrentUser();
    if (localUser != null) {
      state = state.copyWith(user: localUser, isAuthenticated: true);
    }
  }

  void reloadUserFromStorage() {
    _checkAuthStatus();
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final settings = ref.read(settingsProvider);
      
      if (settings.databaseMode == DatabaseMode.supabase) {
        return await _signInWithSupabase(email, password);
      } else {
        return await _signInWithMongoDB(email, password);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante il login: $e',
      );
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final settings = ref.read(settingsProvider);
      
      if (settings.databaseMode == DatabaseMode.supabase) {
        return await _signUpWithSupabase(email, password);
      } else {
        return await _signUpWithMongoDB(email, password);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la registrazione: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final settings = ref.read(settingsProvider);
    
    // Se non usa autenticazione reale, mantieni la demo
    if (!settings.useRealAuth) {
      return await _signInDemo(username, password);
    }
    
    // Converte username in email per Supabase
    final email = username.contains('@') ? username : '$username@fester.app';
    return await signInWithEmail(email: email, password: password);
  }

  Future<bool> _signInDemo(String username, String password) async {
    if (username == 'admin' && password == 'admin123') {
      final demoUser = User(
        username: 'admin',
        passwordHash: 'demo_hash',
        eventId: 'demo_event_id',
        role: UserRole.host,
      );
      
      await LocalDatabaseService.saveCurrentUser(demoUser);
      state = state.copyWith(
        user: demoUser, 
        isLoading: false, 
        isAuthenticated: true
      );
      return true;
    }
    
    state = state.copyWith(
      isLoading: false,
      error: 'Credenziali demo non valide',
    );
    return false;
  }

  Future<bool> _signInWithSupabase(String email, String password) async {
    try {
      final response = await SupabaseConfig.signIn(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        // Salva il token JWT
        await ref.read(settingsProvider.notifier)
            .updateAuthToken(response.session!.accessToken);

        // Ottieni o crea il profilo utente
        final supabase = SupabaseConfig.client;
        final profileResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .single();

        // Crea l'oggetto User dai dati Supabase + profilo
        final user = User(
          id: response.user!.id,
          username: profileResponse['username'] ?? response.user!.email?.split('@').first ?? 'user',
          passwordHash: '', // Non salvare la password in chiaro
          eventId: profileResponse['event_id']?.toString() ?? 'default_event',
          role: UserRole.values.firstWhere(
            (role) => role.name == (profileResponse.containsKey('role') ? profileResponse['role'] as String? ?? 'staff' : 'staff'),
          ),
        );

        await LocalDatabaseService.saveCurrentUser(user);
        state = state.copyWith(
          user: user, 
          isLoading: false, 
          isAuthenticated: true
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Credenziali Supabase non valide',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore Supabase: $e',
      );
      return false;
    }
  }

  Future<bool> _signInWithMongoDB(String email, String password) async {
    try {
      // Placeholder per connessione MongoDB
      // In un'implementazione reale, qui dovresti:
      // 1. Connettere a MongoDB su host:port
      // 2. Verificare credenziali nel database
      // 3. Ottenere il JWT token dal server
      
      // Per ora, simula una risposta positiva
      await Future.delayed(const Duration(seconds: 1));
      
      final user = User(
        username: email.split('@').first,
        passwordHash: '', 
        eventId: 'mongodb_event',
        role: UserRole.staff,
      );

      await LocalDatabaseService.saveCurrentUser(user);
      state = state.copyWith(
        user: user, 
        isLoading: false, 
        isAuthenticated: true
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore MongoDB: $e',
      );
      return false;
    }
  }

  Future<bool> _signUpWithSupabase(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.signUp(
        email: email,
        password: password,
        username: email.split('@').first, // Usa la parte prima della @ come username
      );

      if (response.user != null) {
        // Per la registrazione, il profilo viene creato automaticamente dal trigger
        // Se c'è una sessione, procedi come per il login
        if (response.session != null) {
          // Salva il token JWT
          await ref.read(settingsProvider.notifier)
              .updateAuthToken(response.session!.accessToken);

          // Aspetta che il trigger crei il profilo
          await Future.delayed(const Duration(milliseconds: 500));
          
          final supabase = SupabaseConfig.client;
          final profileResponse = await supabase
              .from('profiles')
              .select()
              .eq('id', response.user!.id)
              .single();

          // Crea l'oggetto User
          final user = User(
            id: response.user!.id,
            username: profileResponse['username'] ?? email.split('@').first,
            passwordHash: '',
            eventId: profileResponse['event_id']?.toString() ?? 'default_event',
            role: UserRole.values.firstWhere(
              (role) => role.name == (profileResponse.containsKey('role') ? profileResponse['role'] as String? ?? 'staff' : 'staff'),
            ),
          );

          await LocalDatabaseService.saveCurrentUser(user);
          state = state.copyWith(
            user: user, 
            isLoading: false, 
            isAuthenticated: true
          );
          return true;
        } else {
          // Registrazione completata ma richiede conferma email
          state = state.copyWith(
            isLoading: false,
            error: 'Registrazione completata! Controlla la tua email per confermare l\'account.',
          );
          return false;
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Errore durante la registrazione',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore Supabase: $e',
      );
      return false;
    }
  }

  Future<bool> _signUpWithMongoDB(String email, String password) async {
    // Implementa la logica per la registrazione con MongoDB
    // Questo è un esempio di come potresti farlo
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Placeholder per connessione MongoDB
      // In un'implementazione reale, qui dovresti:
      // 1. Connettere a MongoDB su host:port
      // 2. Verificare credenziali nel database
      // 3. Ottenere il JWT token dal server
      
      // Per ora, simula una risposta positiva
      await Future.delayed(const Duration(seconds: 1));
      
      final user = User(
        username: email.split('@').first,
        passwordHash: '', 
        eventId: 'mongodb_event',
        role: UserRole.staff,
      );

      await LocalDatabaseService.saveCurrentUser(user);
      state = state.copyWith(
        user: user, 
        isLoading: false, 
        isAuthenticated: true
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore MongoDB: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final settings = ref.read(settingsProvider);
      
      if (settings.databaseMode == DatabaseMode.supabase) {
        await SupabaseConfig.signOut();
      }
      
      // Clear JWT token
      await ref.read(settingsProvider.notifier).updateAuthToken(null);
      
      await LocalDatabaseService.clearCurrentUser();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: 'Errore durante il logout: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
}); 
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_manager.dart';
import '../core/config/app_config.dart';

class InitializationService {
  static final InitializationService _instance =
      InitializationService._internal();
  factory InitializationService() => _instance;
  InitializationService._internal();

  final List<String> _initializationLog = [];
  bool _isInitialized = false;

  List<String> get initializationLog => _initializationLog;
  bool get isInitialized => _isInitialized;

  void _log(String message) {
    _initializationLog.add(message);
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load environment variables in isolate
      await compute((message) async {
        await dotenv.load(
          fileName: const String.fromEnvironment(
            'ENV_FILE',
            defaultValue: '.env.dev',
          ),
        );
        return true;
      }, null);
      _log('📝 Environment loaded successfully');

      // 2. Initialize Firebase in parallel with other services
      final firebaseInit = Firebase.initializeApp();

      // 3. Initialize Supabase in parallel
      final supabaseInit = Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseKey,
      );

      // Wait for both to complete
      await Future.wait([
        firebaseInit.then((_) => _log('🔥 Firebase initialized')),
        supabaseInit.then((_) => _log('⚡ Supabase initialized')),
      ]);

      // 4. Initialize NotificationManager after Firebase is ready
      final notificationManager = NotificationManager();
      await notificationManager.initialize();
      _log('🔔 Notification manager initialized');

      _isInitialized = true;
    } catch (e, stackTrace) {
      _log('❌ Initialization error: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }
}

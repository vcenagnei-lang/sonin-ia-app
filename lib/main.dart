// ============================================================
// main.dart
// Ponto de entrada da Sonin.IA
// Liga todos os módulos e abre o app
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'data/local/database_helper.dart';
import 'data/remote/gemini_service.dart';
import 'ai/orchestrator.dart';
import 'voice/stt_service.dart';
import 'voice/tts_service.dart';
import 'features/chat/chat_screen.dart';
import 'features/devocional/devocional_service.dart';
import 'features/devocional/devocional_screen.dart';

// Injetor de dependências — acesso global aos serviços
final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deixar só em modo retrato — mais simples para idosos
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Inicializar fusos horários (para notificações)
  tz.initializeTimeZones();

  // Registrar todos os serviços
  await _configurarServicos();

  runApp(const SoninApp());
}


// ----------------------------------------------------------
// CONFIGURAR SERVIÇOS
// ----------------------------------------------------------
Future<void> _configurarServicos() async {

  // Banco de dados
  getIt.registerSingleton<DatabaseHelper>(DatabaseHelper());

  // IA Gemini
  getIt.registerSingleton<GeminiService>(GeminiService());

  // Cérebro central
  getIt.registerSingleton<Orchestrator>(Orchestrator());

  // Voz
  getIt.registerSingleton<SttService>(SttService());
  getIt.registerSingleton<TtsService>(TtsService());

  // Devocional
  // Chave do Gemini via --dart-define=GEMINI_API_KEY=... ao compilar
  const geminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  getIt.registerSingleton<DevocionalService>(
    DevocionalService(
      geminiApiKey: geminiKey,
      databaseHelper: getIt<DatabaseHelper>(),
      orchestrator: getIt<Orchestrator>(),
    ),
  );
}


// ----------------------------------------------------------
// APP PRINCIPAL
// ----------------------------------------------------------
class SoninApp extends StatelessWidget {
  const SoninApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonin.IA',
      debugShowCheckedModeBanner: false,

      // Tema geral — rosa pastel e floral
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,

        // Fonte padrão
        fontFamily: 'PlayfairDisplay',

        // Textos grandes para idosos
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 17),
          bodyMedium: TextStyle(fontSize: 15),
          bodySmall: TextStyle(fontSize: 13),
        ),

        // AppBar limpa
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        // Visual geral
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
      ),

      // Tela inicial
      home: const ChatScreen(),

      // Rotas do app
      routes: {
        '/chat':       (context) => const ChatScreen(),
        '/devocional': (context) => DevocionalScreen(
          service:    getIt<DevocionalService>(),
          ttsService: getIt<TtsService>(),
        ),
      },
    );
  }
}

// ============================================================
// tts_service.dart
// Texto → Voz da Sonin.IA
// Google Cloud TTS (gratuito, natural) para uso diário
// ElevenLabs (gratuito limitado) para momentos especiais
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {

  // ----------------------------------------------------------
  // CONFIGURAÇÃO
  // Chaves gratuitas:
  // Google Cloud TTS: console.cloud.google.com (1M chars/mês grátis)
  // ElevenLabs: elevenlabs.io (10k chars/mês grátis)
  // ----------------------------------------------------------
  static const String _googleApiKey    = 'SUA_CHAVE_GOOGLE_AQUI';
  static const String _elevenLabsKey   = 'SUA_CHAVE_ELEVENLABS_AQUI';
  static const String _elevenLabsVoice = 'SUA_VOZ_SONIN_AQUI'; // ID criado no ElevenLabs

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _inicializado = false;


  // ----------------------------------------------------------
  // INICIALIZAR
  // ----------------------------------------------------------
  Future<void> inicializar() async {
    if (_inicializado) return;

    // Configurar TTS offline do Android (fallback)
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.82);  // um pouco mais devagar para idosos
    await _flutterTts.setVolume(1.0);       // volume máximo
    await _flutterTts.setPitch(1.05);       // tom levemente feminino

    _inicializado = true;
  }


  // ----------------------------------------------------------
  // FALAR — método principal
  // Escolhe automaticamente a melhor voz disponível
  // ----------------------------------------------------------
  Future<void> falar(String texto, {bool momentoEspecial = false}) async {
    await inicializar();

    // Momentos especiais usam ElevenLabs (saudação, versículo)
    if (momentoEspecial && _elevenLabsKey != 'SUA_CHAVE_ELEVENLABS_AQUI') {
      final sucesso = await _falarElevenLabs(texto);
      if (sucesso) return;
    }

    // Uso diário usa Google Cloud TTS
    if (_googleApiKey != 'SUA_CHAVE_GOOGLE_AQUI') {
      final sucesso = await _falarGoogle(texto);
      if (sucesso) return;
    }

    // Fallback: TTS offline do Android
    await _falarOffline(texto);
  }

  // Parar a voz
  Future<void> parar() async {
    await _player.stop();
    await _flutterTts.stop();
  }


  // ----------------------------------------------------------
  // GOOGLE CLOUD TTS
  // Natural, gratuito até 1 milhão de chars/mês
  // ----------------------------------------------------------
  Future<bool> _falarGoogle(String texto) async {
    try {
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': texto},
          'voice': {
            'languageCode': 'pt-BR',
            'name': 'pt-BR-Wavenet-A', // voz feminina natural
            'ssmlGender': 'FEMALE',
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 0.9,  // levemente mais devagar
            'pitch': 1.0,
            'volumeGainDb': 2.0,  // um pouco mais alto
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBase64 = data['audioContent'];
        final audioBytes = base64Decode(audioBase64);

        // Salvar e tocar
        final dir = await getTemporaryDirectory();
        final arquivo = File('${dir.path}/sonin_fala.mp3');
        await arquivo.writeAsBytes(audioBytes);
        await _player.setFilePath(arquivo.path);
        await _player.play();
        return true;
      }
      return false;

    } catch (_) {
      return false;
    }
  }


  // ----------------------------------------------------------
  // ELEVENLABS TTS
  // Voz personalizada da Sonin.IA — momentos especiais
  // ----------------------------------------------------------
  Future<bool> _falarElevenLabs(String texto) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_elevenLabsVoice'),
        headers: {
          'xi-api-key': _elevenLabsKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': texto,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.75,
            'similarity_boost': 0.85,
            'style': 0.3,
            'use_speaker_boost': true,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final arquivo = File('${dir.path}/sonin_especial.mp3');
        await arquivo.writeAsBytes(response.bodyBytes);
        await _player.setFilePath(arquivo.path);
        await _player.play();
        return true;
      }
      return false;

    } catch (_) {
      return false;
    }
  }


  // ----------------------------------------------------------
  // TTS OFFLINE DO ANDROID
  // Fallback quando não tiver internet ou chave configurada
  // ----------------------------------------------------------
  Future<void> _falarOffline(String texto) async {
    await _flutterTts.speak(texto);
  }
}

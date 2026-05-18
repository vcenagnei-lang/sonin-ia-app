// ============================================================
// gemini_service.dart
// Integração com a API Gemini do Google (gratuita)
// Limite: 1500 requisições por dia no plano gratuito
// Chave gratuita em: aistudio.google.com
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {

  // ----------------------------------------------------------
  // CONFIGURAÇÃO
  // Coloque sua chave gratuita do aistudio.google.com aqui
  // ----------------------------------------------------------
  static const String _apiKey = 'SUA_CHAVE_AQUI';
  static const String _model = 'gemini-1.5-flash'; // modelo gratuito e rápido
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';


  // ----------------------------------------------------------
  // ENVIAR MENSAGEM PARA O GEMINI
  // ----------------------------------------------------------
  Future<String> enviarMensagem({
    required String systemPrompt,
    required String mensagemUsuario,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': systemPrompt}]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': mensagemUsuario}]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,      // criatividade moderada
            'maxOutputTokens': 300,  // respostas curtas para idosos
            'topP': 0.9,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE'
            },
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final texto = data['candidates'][0]['content']['parts'][0]['text'];
        return texto.trim();
      } else if (response.statusCode == 429) {
        // Limite de requisições atingido
        return _respostaOffline(mensagemUsuario);
      } else {
        return _respostaOffline(mensagemUsuario);
      }

    } catch (e) {
      // Sem internet ou erro — usa resposta offline
      return _respostaOffline(mensagemUsuario);
    }
  }


  // ----------------------------------------------------------
  // RESPOSTA OFFLINE
  // Quando não tiver internet ou atingir o limite
  // ----------------------------------------------------------
  String _respostaOffline(String mensagem) {
    final msg = mensagem.toLowerCase();

    if (msg.contains('bom dia') || msg.contains('oi') || msg.contains('olá')) {
      return 'Bom dia, Dona Sônia! 😊 Que Deus abençoe seu dia com muita paz e alegria! 🙏';
    }

    if (msg.contains('remédio') || msg.contains('remedinho')) {
      return 'Não esqueça do remédio, Dona Sônia! 💊 Saúde em dia é bênção de Deus! 🙏';
    }

    if (msg.contains('triste') || msg.contains('cansada') || msg.contains('sozinha')) {
      return 'Estou aqui com você, Dona Sônia. 🤍 Deus nunca nos abandona, e eu também não vou abandonar a senhora.';
    }

    if (msg.contains('obrigada') || msg.contains('obrigado')) {
      return 'Que nada, Dona Sônia! 🌸 É um prazer cuidar da senhora!';
    }

    if (msg.contains('louvor') || msg.contains('música') || msg.contains('musica')) {
      return 'Que ótima ideia! Um louvor anima qualquer dia! 🎵 Vou abrir um para a senhora!';
    }

    if (msg.contains('família') || msg.contains('filho') || msg.contains('neto')) {
      return 'Que bom falar da família né, Dona Sônia! 🥰 Eles são sua maior bênção!';
    }

    // Resposta padrão quando offline
    return 'Estou sem internet agora, Dona Sônia, mas estou aqui! 🌸 Me fala o que precisa e faço o que puder!';
  }


  // ----------------------------------------------------------
  // VERIFICAR SE TEM INTERNET
  // ----------------------------------------------------------
  Future<bool> temInternet() async {
    try {
      final result = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // ----------------------------------------------------------
  // EXTRAIR MEMÓRIA DA CONVERSA
  // Após cada mensagem, verifica se aprendeu algo novo
  // ----------------------------------------------------------
  Future<String?> extrairMemoria(String mensagem) async {
    try {
      final prompt = '''
Analise esta mensagem e extraia APENAS fatos importantes sobre a pessoa.
Mensagem: "$mensagem"

Se encontrar um fato importante, responda SOMENTE em JSON assim:
{"categoria": "saude", "chave": "remedio", "valor": "losartana"}

Categorias possíveis: saude, familia, preferencia, rotina, aniversario

Se não encontrar nada importante, responda apenas: nada
''';

      final resposta = await enviarMensagem(
        systemPrompt: 'Você extrai fatos de mensagens. Responda apenas JSON ou "nada".',
        mensagemUsuario: prompt,
      );

      if (resposta.trim().toLowerCase() == 'nada') return null;
      return resposta;

    } catch (_) {
      return null;
    }
  }
}

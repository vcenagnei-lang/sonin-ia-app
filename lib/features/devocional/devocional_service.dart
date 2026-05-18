// devocional_service.dart
//
// Service do módulo devocional — versão Gemini API (gratuito).
//
// Modelo principal: Gemini 2.5 Pro (free tier — 100 requests/dia, sobra muito
// já que rodamos 1x por dia).
// Fallback: Gemini 2.5 Flash (250 requests/dia) caso o Pro dê 429.
//
// Diferenciais dessa versão:
//   - Usa `responseSchema` do Gemini → JSON estruturado garantido
//   - `systemInstruction` separado das mensagens
//   - Retry com backoff exponencial em 429
//   - Fallback automático Pro → Flash → erro suave

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'devocional_models.dart';
import 'devocional_system_prompt.dart';

// Interfaces esperadas do projeto Sonin.IA:
//   - DatabaseHelper  (database_helper.dart)
//   - Orchestrator    (orchestrator.dart)

class DevocionalService {
  /// Chave da Gemini API (Google AI Studio).
  /// Em produção: --dart-define=GEMINI_API_KEY=... ou secrets manager.
  final String _geminiApiKey;

  /// Modelo principal. 2.5 Pro = melhor qualidade no free tier.
  static const String _modeloPrincipal = 'gemini-2.5-pro';

  /// Fallback se o Pro estourar limite (raro: usamos 1/dia, limite é 100/dia).
  static const String _modeloFallback = 'gemini-2.5-flash';

  /// Endpoint base da Gemini API.
  static const String _baseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final dynamic _db;            // DatabaseHelper
  final dynamic _orchestrator;  // Orchestrator

  DevocionalService({
    required String geminiApiKey,
    required dynamic databaseHelper,
    required dynamic orchestrator,
  })  : _geminiApiKey = geminiApiKey,
        _db = databaseHelper,
        _orchestrator = orchestrator;

  // ============================================================
  // FLUXO PRINCIPAL
  // ============================================================

  Future<DevocionalDoDia> obterDevocionalDeHoje() async {
    final hoje = _dataHoje();

    final cacheado = await _carregarDoCache(hoje);
    if (cacheado != null) return cacheado;

    final contexto = await _montarContexto();
    final devocional = await _chamarGemini(contexto);

    final musicaComUrl = await _resolverMusicaNoYoutube(devocional.musica);
    final devocionalFinal = DevocionalDoDia(
      saudacao: devocional.saudacao,
      versiculo: devocional.versiculo,
      reflexao: devocional.reflexao,
      conviteConversa: devocional.conviteConversa,
      musica: musicaComUrl,
      metadata: devocional.metadata,
      dataGeracao: hoje,
    );

    await _salvarNoCache(devocionalFinal);
    return devocionalFinal;
  }

  Future<bool> jaAbriuHoje() async {
    final dev = await _carregarDoCache(_dataHoje());
    return dev?.aberto ?? false;
  }

  Future<void> marcarComoAberto() async => _atualizarFlag(aberto: true);
  Future<void> marcarComoOuvido() async => _atualizarFlag(ouvido: true);
  Future<void> marcarComoConversado() async =>
      _atualizarFlag(conversado: true);

  Future<void> _atualizarFlag({
    bool? aberto,
    bool? ouvido,
    bool? conversado,
  }) async {
    final hoje = _dataHoje();
    final dev = await _carregarDoCache(hoje);
    if (dev == null) return;
    await _salvarNoCache(dev.copyWith(
      aberto: aberto,
      ouvido: ouvido,
      conversado: conversado,
    ));
  }

  // ============================================================
  // CONTEXTO
  // ============================================================

  Future<DevocionalContext> _montarContexto() async {
    final agora = DateTime.now();
    final dataFormatada = DateFormat(
      "EEEE, d 'de' MMMM 'de' y",
      'pt_BR',
    ).format(agora);
    final diaSemana = DateFormat('EEEE', 'pt_BR').format(agora).toLowerCase();
    final horaDia = _periodoDoDia(agora.hour);

    final humorRecente = await _orchestrator.detectarHumorRecente();
    final ultimasConversas = await _db.resumoConversasUltimos7Dias();
    final memorias = await _db.memoriasRelevantesParaDevocional();
    final versiculosUsados = await _db.versiculosUsadosUltimos30Dias();
    final assuntoEmergente = await _orchestrator.detectarAssuntoEmergente();
    final diaEspecial = _verificarDiaEspecial(agora);

    return DevocionalContext(
      dataHoje: dataFormatada,
      horaDia: horaDia,
      diaSemana: diaSemana,
      humorRecente: humorRecente,
      ultimasConversas: ultimasConversas,
      memoriasRelevantes: memorias,
      versiculosUsadosUltimos30Dias: versiculosUsados,
      assuntoEmergente: assuntoEmergente,
      ehDiaEspecial: diaEspecial != null,
      contextoEspecial: diaEspecial,
    );
  }

  String _periodoDoDia(int hora) {
    if (hora < 12) return 'manhã';
    if (hora < 18) return 'tarde';
    return 'noite';
  }

  String? _verificarDiaEspecial(DateTime agora) {
    final dia = agora.day;
    final mes = agora.month;
    if (dia == 4 && mes == 7) return 'Hoje é o aniversário da Dona Sônia 🌸';
    if (dia == 6 && mes == 7) return 'Hoje é aniversário do Rodrigo (Digo)';
    if (dia == 5 && mes == 9) return 'Hoje é aniversário do Rafael (Finha)';
    if (dia == 6 && mes == 11) return 'Hoje é aniversário do Vando (caçula)';
    if (dia == 3 && mes == 12 && agora.year == 2026) {
      return 'Hoje é a formatura do Dudu — o neto amado!';
    }
    return null;
  }

  // ============================================================
  // CHAMADA AO GEMINI
  // ============================================================

  Future<DevocionalDoDia> _chamarGemini(DevocionalContext ctx) async {
    final systemPrompt = DevocionalSystemPrompt.build(
      dataHoje: ctx.dataHoje,
      horaDia: ctx.horaDia,
      diaSemana: ctx.diaSemana,
      humorRecente: ctx.humorRecente,
      ultimasConversas: ctx.ultimasConversas,
      memoriasRelevantes: ctx.memoriasRelevantes,
      versiculosUsadosUltimos30Dias: ctx.versiculosUsadosUltimos30Dias,
      assuntoEmergente: ctx.assuntoEmergente,
      ehDiaEspecial: ctx.ehDiaEspecial,
      contextoEspecial: ctx.contextoEspecial,
    );

    const userMessage = 'Prepare a palavra de hoje para a Dona Sônia. '
        'Responda no formato JSON exigido.';

    // Tenta no Pro com até 2 retries; se estourar, vai pro Flash.
    try {
      return await _chamarModelo(
        modelo: _modeloPrincipal,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxRetries: 2,
      );
    } on RateLimitException {
      return await _chamarModelo(
        modelo: _modeloFallback,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxRetries: 2,
      );
    }
  }

  Future<DevocionalDoDia> _chamarModelo({
    required String modelo,
    required String systemPrompt,
    required String userMessage,
    required int maxRetries,
  }) async {
    final url =
        '$_baseEndpoint/$modelo:generateContent?key=$_geminiApiKey';

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 2048,
        // Aqui está a mágica: força saída JSON estruturada.
        'responseMimeType': 'application/json',
        'responseSchema': _schemaJsonDevocional(),
      },
    };

    // Retry com backoff exponencial: 1s, 2s, 4s
    for (int tentativa = 0; tentativa <= maxRetries; tentativa++) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          return _parsearRespostaGemini(response.body);
        }

        if (response.statusCode == 429) {
          if (tentativa == maxRetries) {
            throw RateLimitException('Limite do $modelo atingido');
          }
          await Future.delayed(Duration(seconds: 1 << tentativa));
          continue;
        }

        // Outros erros HTTP — não tem retry
        throw DevocionalException(
          'Gemini retornou ${response.statusCode}: ${response.body}',
        );
      } on TimeoutException {
        if (tentativa == maxRetries) {
          throw DevocionalException('Timeout ao chamar Gemini');
        }
        await Future.delayed(Duration(seconds: 1 << tentativa));
      }
    }

    throw DevocionalException('Não foi possível chamar Gemini após retries');
  }

  /// Schema JSON que força o Gemini a devolver exatamente os campos esperados.
  /// Essa é uma das vantagens grandes da Gemini API — saída garantida.
  Map<String, dynamic> _schemaJsonDevocional() => {
        'type': 'OBJECT',
        'properties': {
          'saudacao': {'type': 'STRING'},
          'versiculo': {
            'type': 'OBJECT',
            'properties': {
              'referencia': {'type': 'STRING'},
              'texto': {'type': 'STRING'},
            },
            'required': ['referencia', 'texto'],
          },
          'reflexao': {'type': 'STRING'},
          'convite_conversa': {'type': 'STRING'},
          'musica': {
            'type': 'OBJECT',
            'properties': {
              'titulo': {'type': 'STRING'},
              'artista': {'type': 'STRING'},
              'ano': {'type': 'STRING'},
              'motivo': {'type': 'STRING'},
            },
            'required': ['titulo', 'artista', 'ano', 'motivo'],
          },
          'metadata': {
            'type': 'OBJECT',
            'properties': {
              'humor_detectado_hoje': {'type': 'STRING'},
              'tom_da_palavra': {'type': 'STRING'},
              'tema_central': {'type': 'STRING'},
              'porta_aberta': {'type': 'STRING'},
            },
            'required': [
              'humor_detectado_hoje',
              'tom_da_palavra',
              'tema_central',
              'porta_aberta',
            ],
          },
        },
        'required': [
          'saudacao',
          'versiculo',
          'reflexao',
          'convite_conversa',
          'musica',
          'metadata',
        ],
      };

  DevocionalDoDia _parsearRespostaGemini(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;

    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw DevocionalException(
        'Gemini não retornou candidates. Pode ter sido bloqueado: $responseBody',
      );
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw DevocionalException('Resposta do Gemini sem content');
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw DevocionalException('Resposta do Gemini sem parts');
    }

    final texto = parts
        .map((p) => p['text'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n');

    Map<String, dynamic> devocionalJson;
    try {
      // Com responseSchema o texto já vem como JSON limpo.
      devocionalJson = jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      // Fallback defensivo: limpar possíveis cercas
      final limpo = _limparJson(texto);
      devocionalJson = jsonDecode(limpo) as Map<String, dynamic>;
    }

    return DevocionalDoDia.fromJson(
      devocionalJson,
      dataGeracao: _dataHoje(),
    );
  }

  String _limparJson(String texto) {
    var t = texto.trim();
    if (t.startsWith('```json')) t = t.substring(7).trim();
    if (t.startsWith('```')) t = t.substring(3).trim();
    if (t.endsWith('```')) t = t.substring(0, t.length - 3).trim();
    return t;
  }

  // ============================================================
  // YOUTUBE
  // ============================================================

  Future<SugestaoMusical> _resolverMusicaNoYoutube(SugestaoMusical m) async {
    final query = Uri.encodeQueryComponent(m.queryBusca);
    final url = 'https://www.youtube.com/results?search_query=$query';
    // TODO: integrar com youtube_explode_dart pra tocar áudio direto no app
    return m.copyWithUrl(url);
  }

  // ============================================================
  // CACHE (SQLite)
  // ============================================================

  Future<DevocionalDoDia?> _carregarDoCache(String data) async {
    final raw = await _db.obterDevocionalDoDia(data) as String?;
    if (raw == null) return null;
    try {
      return DevocionalDoDia.fromDbString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvarNoCache(DevocionalDoDia dev) async {
    await _db.salvarDevocionalDoDia(dev.dataGeracao, dev.toDbString());
  }

  String _dataHoje() => DateFormat('yyyy-MM-dd').format(DateTime.now());
}

// ============================================================
// EXCEÇÕES
// ============================================================

class DevocionalException implements Exception {
  final String message;
  DevocionalException(this.message);
  @override
  String toString() => 'DevocionalException: $message';
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => 'RateLimitException: $message';
}

// devocional_models.dart
//
// Estruturas de dados do módulo devocional.
// Todos os dados que viajam entre o Opus, o cache local e a UI.

import 'dart:convert';

/// Representação completa de um devocional do dia.
class DevocionalDoDia {
  final String saudacao;
  final Versiculo versiculo;
  final String reflexao;
  final String conviteConversa;
  final SugestaoMusical musica;
  final DevocionalMetadata metadata;

  /// Data em que esse devocional foi gerado (YYYY-MM-DD).
  final String dataGeracao;

  /// Se a Dona Sônia já abriu o devocional hoje.
  final bool aberto;

  /// Se ela já ouviu o áudio.
  final bool ouvido;

  /// Se ela já conversou sobre.
  final bool conversado;

  DevocionalDoDia({
    required this.saudacao,
    required this.versiculo,
    required this.reflexao,
    required this.conviteConversa,
    required this.musica,
    required this.metadata,
    required this.dataGeracao,
    this.aberto = false,
    this.ouvido = false,
    this.conversado = false,
  });

  factory DevocionalDoDia.fromJson(
    Map<String, dynamic> json, {
    required String dataGeracao,
    bool aberto = false,
    bool ouvido = false,
    bool conversado = false,
  }) {
    return DevocionalDoDia(
      saudacao: json['saudacao'] as String? ?? '',
      versiculo: Versiculo.fromJson(json['versiculo'] as Map<String, dynamic>),
      reflexao: json['reflexao'] as String? ?? '',
      conviteConversa: json['convite_conversa'] as String? ?? '',
      musica: SugestaoMusical.fromJson(json['musica'] as Map<String, dynamic>),
      metadata: DevocionalMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      dataGeracao: dataGeracao,
      aberto: aberto,
      ouvido: ouvido,
      conversado: conversado,
    );
  }

  Map<String, dynamic> toJson() => {
        'saudacao': saudacao,
        'versiculo': versiculo.toJson(),
        'reflexao': reflexao,
        'convite_conversa': conviteConversa,
        'musica': musica.toJson(),
        'metadata': metadata.toJson(),
        'data_geracao': dataGeracao,
        'aberto': aberto,
        'ouvido': ouvido,
        'conversado': conversado,
      };

  /// Versão para guardar no SQLite (string única).
  String toDbString() => jsonEncode(toJson());

  factory DevocionalDoDia.fromDbString(String dbString) {
    final map = jsonDecode(dbString) as Map<String, dynamic>;
    return DevocionalDoDia(
      saudacao: map['saudacao'] as String? ?? '',
      versiculo: Versiculo.fromJson(map['versiculo'] as Map<String, dynamic>),
      reflexao: map['reflexao'] as String? ?? '',
      conviteConversa: map['convite_conversa'] as String? ?? '',
      musica: SugestaoMusical.fromJson(map['musica'] as Map<String, dynamic>),
      metadata:
          DevocionalMetadata.fromJson(map['metadata'] as Map<String, dynamic>),
      dataGeracao: map['data_geracao'] as String,
      aberto: map['aberto'] as bool? ?? false,
      ouvido: map['ouvido'] as bool? ?? false,
      conversado: map['conversado'] as bool? ?? false,
    );
  }

  DevocionalDoDia copyWith({
    bool? aberto,
    bool? ouvido,
    bool? conversado,
  }) {
    return DevocionalDoDia(
      saudacao: saudacao,
      versiculo: versiculo,
      reflexao: reflexao,
      conviteConversa: conviteConversa,
      musica: musica,
      metadata: metadata,
      dataGeracao: dataGeracao,
      aberto: aberto ?? this.aberto,
      ouvido: ouvido ?? this.ouvido,
      conversado: conversado ?? this.conversado,
    );
  }
}

class Versiculo {
  final String referencia;
  final String texto;

  Versiculo({required this.referencia, required this.texto});

  factory Versiculo.fromJson(Map<String, dynamic> json) => Versiculo(
        referencia: json['referencia'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'referencia': referencia,
        'texto': texto,
      };
}

class SugestaoMusical {
  final String titulo;
  final String artista;
  final String ano;
  final String motivo;

  /// URL do YouTube (será resolvida pelo service depois).
  final String? youtubeUrl;

  SugestaoMusical({
    required this.titulo,
    required this.artista,
    required this.ano,
    required this.motivo,
    this.youtubeUrl,
  });

  /// Query pronta pra buscar no YouTube.
  String get queryBusca => '$titulo $artista gospel';

  factory SugestaoMusical.fromJson(Map<String, dynamic> json) =>
      SugestaoMusical(
        titulo: json['titulo'] as String? ?? '',
        artista: json['artista'] as String? ?? '',
        ano: json['ano']?.toString() ?? '',
        motivo: json['motivo'] as String? ?? '',
        youtubeUrl: json['youtube_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'artista': artista,
        'ano': ano,
        'motivo': motivo,
        if (youtubeUrl != null) 'youtube_url': youtubeUrl,
      };

  SugestaoMusical copyWithUrl(String url) => SugestaoMusical(
        titulo: titulo,
        artista: artista,
        ano: ano,
        motivo: motivo,
        youtubeUrl: url,
      );
}

class DevocionalMetadata {
  final String humorDetectadoHoje;
  final String tomDaPalavra;
  final String temaCentral;
  final String portaAberta;

  DevocionalMetadata({
    required this.humorDetectadoHoje,
    required this.tomDaPalavra,
    required this.temaCentral,
    required this.portaAberta,
  });

  factory DevocionalMetadata.fromJson(Map<String, dynamic> json) =>
      DevocionalMetadata(
        humorDetectadoHoje: json['humor_detectado_hoje'] as String? ?? '',
        tomDaPalavra: json['tom_da_palavra'] as String? ?? '',
        temaCentral: json['tema_central'] as String? ?? '',
        portaAberta: json['porta_aberta'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'humor_detectado_hoje': humorDetectadoHoje,
        'tom_da_palavra': tomDaPalavra,
        'tema_central': temaCentral,
        'porta_aberta': portaAberta,
      };
}

/// Contexto montado pelo orchestrator e injetado no prompt do Opus.
class DevocionalContext {
  final String dataHoje;
  final String horaDia;
  final String diaSemana;
  final String? humorRecente;
  final List<String> ultimasConversas;
  final List<String> memoriasRelevantes;
  final List<String> versiculosUsadosUltimos30Dias;
  final String? assuntoEmergente;
  final bool ehDiaEspecial;
  final String? contextoEspecial;

  DevocionalContext({
    required this.dataHoje,
    required this.horaDia,
    required this.diaSemana,
    this.humorRecente,
    this.ultimasConversas = const [],
    this.memoriasRelevantes = const [],
    this.versiculosUsadosUltimos30Dias = const [],
    this.assuntoEmergente,
    this.ehDiaEspecial = false,
    this.contextoEspecial,
  });
}

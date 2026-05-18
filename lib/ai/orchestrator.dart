// ============================================================
// orchestrator.dart
// Cérebro da Sonin.IA — versão 2
// Atualizado com detectarHumorRecente() e detectarAssuntoEmergente()
// ============================================================

import '../data/local/database_helper.dart';
import '../data/remote/gemini_service.dart';
import '../core/constants/sonin_personality.dart';

class Orchestrator {

  final DatabaseHelper _db = DatabaseHelper();
  final GeminiService _gemini = GeminiService();


  // ----------------------------------------------------------
  // PROCESSAR MENSAGEM
  // ----------------------------------------------------------
  Future<String> processar(String mensagemUsuario) async {
    await _db.salvarMensagem('usuario', mensagemUsuario);
    final contexto = await _montarContexto();
    final resposta = await _gerarResposta(
      mensagem: mensagemUsuario,
      contexto: contexto,
    );
    await _db.salvarMensagem('sonin', resposta);
    _aprenderDaMensagem(mensagemUsuario);
    return resposta;
  }


  // ----------------------------------------------------------
  // MONTAR CONTEXTO
  // ----------------------------------------------------------
  Future<String> _montarContexto() async {
    final hoje = DateTime.now();
    final hora = hoje.hour;

    String periodo;
    if (hora >= 5 && hora < 12) periodo = 'manhã';
    else if (hora >= 12 && hora < 18) periodo = 'tarde';
    else if (hora >= 18 && hora < 21) periodo = 'noite';
    else periodo = 'madrugada';

    const dias = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
    final diaSemana = dias[hoje.weekday % 7];
    final memorias = await _db.getMemoriasFormatadas();
    final historico = await _db.getHistoricoFormatado(limite: 5);
    final anivHoje = await _db.getAniversariosHoje();
    final anivAmanha = await _db.getAniversariosAmanha();

    String aniversarios = '';
    if (anivHoje.isNotEmpty) {
      aniversarios = 'HOJE é aniversário de: ${anivHoje.map((a) => a['nome']).join(', ')}!';
    } else if (anivAmanha.isNotEmpty) {
      aniversarios = 'AMANHÃ é aniversário de: ${anivAmanha.map((a) => a['nome']).join(', ')}.';
    }

    return '''
HORÁRIO: $periodo de $diaSemana, ${hoje.day}/${hoje.month}/${hoje.year}
${aniversarios.isNotEmpty ? 'DATAS ESPECIAIS: $aniversarios' : ''}
MEMÓRIAS DA DONA SÔNIA:
$memorias
HISTÓRICO RECENTE:
$historico
    '''.trim();
  }


  // ----------------------------------------------------------
  // GERAR RESPOSTA
  // ----------------------------------------------------------
  Future<String> _gerarResposta({
    required String mensagem,
    required String contexto,
  }) async {
    final comandoEspecial = _verificarComando(mensagem);
    if (comandoEspecial != null) return comandoEspecial;

    final promptCompleto = SoninPersonality.buildPrompt(
      contextoAtual: contexto,
      humoreAtual: _detectarHumorDaMensagem(mensagem),
      historicoRecente: '',
      memoriasRelevantes: '',
    );

    return await _gemini.enviarMensagem(
      systemPrompt: promptCompleto,
      mensagemUsuario: mensagem,
    );
  }


  // ----------------------------------------------------------
  // VERIFICAR COMANDOS ESPECIAIS
  // ----------------------------------------------------------
  String? _verificarComando(String mensagem) {
    final msg = mensagem.toLowerCase();

    if (msg.contains('tomei') && msg.contains('remédio') ||
        msg.contains('tomei o remedinho')) {
      return 'Que ótimo, Dona Sônia! 💊 Deus cuida da sua saúde. 🙏';
    }
    if (msg.contains('louvor') || msg.contains('música') || msg.contains('musica')) {
      return 'ABRIR_LOUVOR';
    }
    if (msg.contains('versículo') || msg.contains('versiculo') || msg.contains('palavra')) {
      return 'MOSTRAR_VERSICULO';
    }
    return null;
  }


  // ----------------------------------------------------------
  // DETECTAR HUMOR DA MENSAGEM (uso interno)
  // ----------------------------------------------------------
  String _detectarHumorDaMensagem(String mensagem) {
    final msg = mensagem.toLowerCase();

    if (['triste', 'cansada', 'sozinha', 'saudade', 'chorei', 'difícil']
        .any(msg.contains)) {
      return 'triste ou cansada — seja extra carinhosa e acolhedora';
    }
    if (['preocupada', 'ansiedade', 'medo', 'nervosa', 'problema']
        .any(msg.contains)) {
      return 'preocupada — seja calma e tranquilizadora';
    }
    if (['feliz', 'alegre', 'graças', 'ótimo', 'maravilha', 'bênção']
        .any(msg.contains)) {
      return 'alegre — compartilhe a alegria!';
    }
    return 'normal — seja carinhosa e natural';
  }


  // ----------------------------------------------------------
  // DETECTAR HUMOR RECENTE — para o devocional
  // Analisa as últimas mensagens e retorna o humor predominante
  // ----------------------------------------------------------
  Future<String?> detectarHumorRecente() async {
    try {
      final mensagens = await _db.resumoConversasUltimos7Dias();
      if (mensagens.isEmpty) return null;

      // Pegar as últimas 10 mensagens
      final ultimas = mensagens.take(10).join(' ').toLowerCase();

      // Contadores de humor
      int tristeza = 0, alegria = 0, preocupacao = 0, gratidao = 0;

      final palavrasTristeza = ['triste', 'saudade', 'sozinha', 'cansada', 'chorei', 'difícil', 'dor'];
      final palavrasAlegria = ['feliz', 'alegre', 'animada', 'ótimo', 'maravilha', 'graças a deus'];
      final palavrasPreocupacao = ['preocupada', 'medo', 'ansiedade', 'nervosa', 'problema'];
      final palavrasGratidao = ['graças', 'obrigada', 'bênção', 'benção', 'deus é bom'];

      for (final p in palavrasTristeza) if (ultimas.contains(p)) tristeza++;
      for (final p in palavrasAlegria) if (ultimas.contains(p)) alegria++;
      for (final p in palavrasPreocupacao) if (ultimas.contains(p)) preocupacao++;
      for (final p in palavrasGratidao) if (ultimas.contains(p)) gratidao++;

      // Determinar humor predominante
      final max = [tristeza, alegria, preocupacao, gratidao].reduce(
        (a, b) => a > b ? a : b,
      );

      if (max == 0) return 'estável e tranquila';
      if (max == tristeza) return 'com um leve peso no coração, talvez saudade';
      if (max == alegria) return 'animada e de bom humor';
      if (max == preocupacao) return 'um pouco preocupada com algo';
      if (max == gratidao) return 'grata e de coração cheio';

      return 'estável';
    } catch (_) {
      return null;
    }
  }


  // ----------------------------------------------------------
  // DETECTAR ASSUNTO EMERGENTE — para o devocional
  // Identifica o tema que ela mais tocou nas últimas conversas
  // ----------------------------------------------------------
  Future<String?> detectarAssuntoEmergente() async {
    try {
      final mensagens = await _db.resumoConversasUltimos7Dias();
      if (mensagens.isEmpty) return null;

      final texto = mensagens.take(15).join(' ').toLowerCase();

      // Temas e suas palavras-chave
      final temas = {
        'família e filhos': ['filho', 'rafael', 'rodrigo', 'evandro', 'finha', 'digo', 'vando', 'dudu', 'familia'],
        'saúde e cuidado': ['remédio', 'médico', 'dor', 'saúde', 'hospital', 'exame'],
        'fé e espiritualidade': ['deus', 'jesus', 'oração', 'igreja', 'louvor', 'bíblia', 'culto'],
        'saudade e perdas': ['saudade', 'falta', 'lembro', 'irmã', 'mãe', 'sobrinho'],
        'gratidão': ['graças', 'obrigada', 'bênção', 'deus é bom', 'abençoado'],
        'solidão': ['sozinha', 'solitária', 'silêncio', 'ninguém'],
      };

      String? temaPredominante;
      int maxContagem = 0;

      for (final entry in temas.entries) {
        int contagem = 0;
        for (final palavra in entry.value) {
          if (texto.contains(palavra)) contagem++;
        }
        if (contagem > maxContagem) {
          maxContagem = contagem;
          temaPredominante = entry.key;
        }
      }

      return maxContagem > 0 ? temaPredominante : null;
    } catch (_) {
      return null;
    }
  }


  // ----------------------------------------------------------
  // APRENDER DA MENSAGEM
  // ----------------------------------------------------------
  Future<void> _aprenderDaMensagem(String mensagem) async {
    try {
      final memoria = await _gemini.extrairMemoria(mensagem);
      if (memoria != null && memoria.isNotEmpty) {
        final limpo = memoria
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        if (limpo.contains('categoria') &&
            limpo.contains('chave') &&
            limpo.contains('valor')) {
          final categoria = _extrairValorJson(limpo, 'categoria');
          final chave = _extrairValorJson(limpo, 'chave');
          final valor = _extrairValorJson(limpo, 'valor');

          if (categoria != null && chave != null && valor != null) {
            await _db.salvarMemoria(categoria, chave, valor);
          }
        }
      }
    } catch (_) {}
  }

  String? _extrairValorJson(String json, String chave) {
    try {
      final regex = RegExp('"$chave"\\s*:\\s*"([^"]+)"');
      final match = regex.firstMatch(json);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }


  // ----------------------------------------------------------
  // SAUDAÇÃO INICIAL
  // ----------------------------------------------------------
  Future<String> getSaudacaoInicial() async {
    final hoje = DateTime.now();
    final hora = hoje.hour;
    const dias = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
    final diaSemana = dias[hoje.weekday % 7];

    final anivHoje = await _db.getAniversariosHoje();
    final anivAmanha = await _db.getAniversariosAmanha();

    if (anivHoje.isNotEmpty) {
      final nome = anivHoje.first['nome'];
      if (nome == 'Dona Sônia') {
        return 'Feliz aniversário, Dona Sônia!! 🎂🎉 Que Deus abençoe muito a sua vida hoje e sempre! ❤️';
      }
      return 'Dona Sônia! Hoje é aniversário d${nome == 'Tia Silmara' ? 'a' : 'o'} $nome! 🎂 Quer que eu te ajude a preparar uma mensagem especial?';
    }

    if (anivAmanha.isNotEmpty) {
      final nome = anivAmanha.first['nome'];
      return 'Dona Sônia, amanhã é aniversário d${nome == 'Tia Silmara' ? 'a' : 'o'} $nome! 🎂 Quer preparar uma mensagem hoje?';
    }

    return SoninPersonality.getSaudacao(
      hora: hora,
      diaSemana: diaSemana,
      estaChovendo: false,
      temAniversarioHoje: false,
      nomeAniversariante: null,
    );
  }
}

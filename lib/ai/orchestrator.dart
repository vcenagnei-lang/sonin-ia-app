// ============================================================
// orchestrator.dart
// Cérebro da Sonin.IA
// Decide o que fazer com cada mensagem da Dona Sônia
// ============================================================

import '../data/local/database_helper.dart';
import '../data/remote/gemini_service.dart';
import '../core/constants/sonin_personality.dart';

class Orchestrator {

  final DatabaseHelper _db = DatabaseHelper();
  final GeminiService _gemini = GeminiService();


  // ----------------------------------------------------------
  // PROCESSAR MENSAGEM
  // Ponto de entrada — chamado a cada mensagem da Dona Sônia
  // ----------------------------------------------------------
  Future<String> processar(String mensagemUsuario) async {

    // 1. Salvar mensagem da Dona Sônia no banco
    await _db.salvarMensagem('usuario', mensagemUsuario);

    // 2. Montar contexto completo
    final contexto = await _montarContexto();

    // 3. Gerar resposta
    final resposta = await _gerarResposta(
      mensagem: mensagemUsuario,
      contexto: contexto,
    );

    // 4. Salvar resposta da Sonin.IA no banco
    await _db.salvarMensagem('sonin', resposta);

    // 5. Aprender com a conversa (em background)
    _aprenderDaMensagem(mensagemUsuario);

    return resposta;
  }


  // ----------------------------------------------------------
  // MONTAR CONTEXTO
  // Junta tudo que a IA precisa saber antes de responder
  // ----------------------------------------------------------
  Future<String> _montarContexto() async {
    final hoje = DateTime.now();
    final hora = hoje.hour;

    // Período do dia
    String periodo;
    if (hora >= 5 && hora < 12) periodo = 'manhã';
    else if (hora >= 12 && hora < 18) periodo = 'tarde';
    else if (hora >= 18 && hora < 21) periodo = 'noite';
    else periodo = 'madrugada';

    // Dia da semana
    const dias = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
    final diaSemana = dias[hoje.weekday % 7];

    // Memórias da Dona Sônia
    final memorias = await _db.getMemoriasFormatadas();

    // Histórico recente
    final historico = await _db.getHistoricoFormatado(limite: 5);

    // Aniversários hoje ou amanhã
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

    // Verificar comandos especiais primeiro
    final comandoEspecial = _verificarComando(mensagem);
    if (comandoEspecial != null) return comandoEspecial;

    // Montar prompt completo com personalidade + contexto
    final promptCompleto = SoninPersonality.buildPrompt(
      contextoAtual: contexto,
      humoreAtual: _detectarHumor(mensagem),
      historicoRecente: '',
      memoriasRelevantes: '',
    );

    // Enviar para o Gemini
    return await _gemini.enviarMensagem(
      systemPrompt: promptCompleto,
      mensagemUsuario: mensagem,
    );
  }


  // ----------------------------------------------------------
  // VERIFICAR COMANDOS ESPECIAIS
  // Respostas rápidas sem precisar chamar a IA
  // ----------------------------------------------------------
  String? _verificarComando(String mensagem) {
    final msg = mensagem.toLowerCase();

    // Tomou o remédio
    if (msg.contains('tomei') && msg.contains('remédio') ||
        msg.contains('tomei o remedinho')) {
      return 'Que ótimo, Dona Sônia! 💊 Que bom que não esqueceu! Deus cuida da sua saúde. 🙏';
    }

    // Quer ouvir louvor
    if (msg.contains('louvor') || msg.contains('música') || msg.contains('musica')) {
      return 'ABRIR_LOUVOR'; // sinal para a tela abrir o YouTube
    }

    // Quer versículo
    if (msg.contains('versículo') || msg.contains('versiculo') || msg.contains('palavra')) {
      return 'MOSTRAR_VERSICULO'; // sinal para mostrar o versículo do dia
    }

    return null;
  }


  // ----------------------------------------------------------
  // DETECTAR HUMOR
  // Analisa o tom da mensagem para adaptar a resposta
  // ----------------------------------------------------------
  String _detectarHumor(String mensagem) {
    final msg = mensagem.toLowerCase();

    if (['triste', 'cansada', 'sozinha', 'saudade', 'chorei', 'difícil']
        .any(msg.contains)) {
      return 'triste ou cansada — seja extra carinhosa e acolhedora';
    }

    if (['preocupada', 'ansiedade', 'medo', 'nervosa', 'problema']
        .any(msg.contains)) {
      return 'preocupada — seja calma e tranquilizadora';
    }

    if (['feliz', 'alegre', 'graças', 'ótimo', 'maravilha', 'bênção', 'animada']
        .any(msg.contains)) {
      return 'alegre — compartilhe a alegria!';
    }

    return 'normal — seja carinhosa e natural';
  }


  // ----------------------------------------------------------
  // APRENDER DA MENSAGEM
  // Roda em background após cada conversa
  // ----------------------------------------------------------
  Future<void> _aprenderDaMensagem(String mensagem) async {
    try {
      final memoria = await _gemini.extrairMemoria(mensagem);
      if (memoria != null && memoria.isNotEmpty) {
        // Tentar parsear o JSON retornado
        // Ex: {"categoria": "saude", "chave": "remedio", "valor": "losartana"}
        final limpo = memoria
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Salvar no banco
        // (parsing simplificado — em produção usar dart:convert)
        if (limpo.contains('categoria') &&
            limpo.contains('chave') &&
            limpo.contains('valor')) {
          // Extração básica dos valores
          final categoria = _extrairValorJson(limpo, 'categoria');
          final chave = _extrairValorJson(limpo, 'chave');
          final valor = _extrairValorJson(limpo, 'valor');

          if (categoria != null && chave != null && valor != null) {
            await _db.salvarMemoria(categoria, chave, valor);
          }
        }
      }
    } catch (_) {
      // Silencioso — aprendizado é opcional
    }
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
  // Chamada quando o app abre
  // ----------------------------------------------------------
  Future<String> getSaudacaoInicial() async {
    final hoje = DateTime.now();
    final hora = hoje.hour;
    const dias = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
    final diaSemana = dias[hoje.weekday % 7];

    // Verificar aniversários
    final anivHoje = await _db.getAniversariosHoje();
    final anivAmanha = await _db.getAniversariosAmanha();

    if (anivHoje.isNotEmpty) {
      final nome = anivHoje.first['nome'];
      if (nome == 'Dona Sônia') {
        return 'Feliz aniversário, Dona Sônia!! 🎂🎉 Que Deus abençoe muito a sua vida hoje e sempre! A família toda te ama! ❤️';
      }
      return 'Dona Sônia! Hoje é aniversário d${nome == 'Tia Silmara' ? 'a' : 'o'} $nome! 🎂 Quer que eu te ajude a preparar uma mensagem especial?';
    }

    if (anivAmanha.isNotEmpty) {
      final nome = anivAmanha.first['nome'];
      return 'Dona Sônia, amanhã é aniversário d${nome == 'Tia Silmara' ? 'a' : 'o'} $nome! 🎂 Quer preparar uma mensagem hoje?';
    }

    // Saudação normal
    return SoninPersonality.getSaudacao(
      hora: hora,
      diaSemana: diaSemana,
      estaChovendo: false,
      temAniversarioHoje: false,
      nomeAniversariante: null,
    );
  }
}

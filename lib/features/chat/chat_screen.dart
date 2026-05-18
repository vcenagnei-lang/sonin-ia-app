// ============================================================
// chat_screen.dart
// Tela principal da Sonin.IA
// Estética floral, pastel, acolhedora — para a Dona Sônia
// ============================================================

import 'package:flutter/material.dart';
import '../../ai/orchestrator.dart';
import '../../voice/stt_service.dart';
import '../../voice/tts_service.dart';
import '../../data/local/database_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {

  // Serviços
  final Orchestrator _orchestrator = Orchestrator();
  final SttService _stt = SttService();
  final TtsService _tts = TtsService();
  final DatabaseHelper _db = DatabaseHelper();

  // Mensagens na tela
  final List<Map<String, dynamic>> _mensagens = [];
  final ScrollController _scrollController = ScrollController();

  // Estado
  bool _ouvindo = false;
  bool _pensando = false;
  String _textoOuvindo = '';

  // Animação do botão de voz
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;


  // ----------------------------------------------------------
  // CORES E ESTÉTICA FLORAL PASTEL
  // ----------------------------------------------------------
  static const Color _rosaPrincipal   = Color(0xFFF48FB1); // rosa suave
  static const Color _rosaClaro       = Color(0xFFFCE4EC); // rosa muito claro
  static const Color _lilas           = Color(0xFFE1BEE7); // lilás suave
  static const Color _verdeMenta      = Color(0xFFC8E6C9); // verde menta
  static const Color _bege            = Color(0xFFFFF8F0); // bege quente
  static const Color _textoPrincipal  = Color(0xFF5D4037); // marrom suave
  static const Color _textoSecundario = Color(0xFF8D6E63); // marrom claro


  @override
  void initState() {
    super.initState();
    _inicializarAnimacao();
    _inicializarServicos();
  }

  void _inicializarAnimacao() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _inicializarServicos() async {
    await _stt.inicializar();
    await _tts.inicializar();

    // Configurar callbacks de voz
    _stt.onTextoParcial = (texto) {
      setState(() => _textoOuvindo = texto);
    };

    _stt.onTextoFinal = (texto) async {
      setState(() {
        _ouvindo = false;
        _textoOuvindo = '';
        _pulseController.stop();
        _pulseController.reset();
      });
      await _enviarMensagem(texto);
    };

    _stt.onFimDeOuvir = () {
      setState(() {
        _ouvindo = false;
        _textoOuvindo = '';
      });
      _pulseController.stop();
      _pulseController.reset();
    };

    // Saudação inicial
    await Future.delayed(const Duration(milliseconds: 800));
    final saudacao = await _orchestrator.getSaudacaoInicial();
    _adicionarMensagem(saudacao, ehSonin: true, especial: true);
    await _tts.falar(saudacao, momentoEspecial: true);
  }


  // ----------------------------------------------------------
  // ENVIAR MENSAGEM
  // ----------------------------------------------------------
  Future<void> _enviarMensagem(String texto) async {
    if (texto.trim().isEmpty) return;

    // Adicionar mensagem da Dona Sônia
    _adicionarMensagem(texto, ehSonin: false);

    // Mostrar que está pensando
    setState(() => _pensando = true);

    // Processar e obter resposta
    final resposta = await _orchestrator.processar(texto);

    setState(() => _pensando = false);

    // Verificar comandos especiais
    if (resposta == 'ABRIR_LOUVOR') {
      _abrirLouvor();
      return;
    }
    if (resposta == 'MOSTRAR_VERSICULO') {
      _mostrarVersiculo();
      return;
    }

    // Adicionar resposta da Sonin.IA
    _adicionarMensagem(resposta, ehSonin: true);

    // Falar a resposta
    await _tts.falar(resposta);
  }

  void _adicionarMensagem(String texto, {
    required bool ehSonin,
    bool especial = false,
  }) {
    setState(() {
      _mensagens.add({
        'texto': texto,
        'ehSonin': ehSonin,
        'especial': especial,
        'hora': _getHoraFormatada(),
      });
    });
    _scrollParaBaixo();
  }

  String _getHoraFormatada() {
    final agora = DateTime.now();
    return '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  }

  void _scrollParaBaixo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  // ----------------------------------------------------------
  // BOTÃO DE VOZ
  // ----------------------------------------------------------
  Future<void> _toggleVoz() async {
    if (_ouvindo) {
      await _stt.pararOuvir();
      setState(() => _ouvindo = false);
      _pulseController.stop();
      _pulseController.reset();
    } else {
      await _tts.parar();
      setState(() {
        _ouvindo = true;
        _textoOuvindo = 'Ouvindo...';
      });
      _pulseController.repeat(reverse: true);
      await _stt.comecarOuvir();
    }
  }


  // ----------------------------------------------------------
  // AÇÕES ESPECIAIS
  // ----------------------------------------------------------
  void _abrirLouvor() {
    _adicionarMensagem(
      'Abrindo um louvor lindo para você, Dona Sônia! 🎵🙏',
      ehSonin: true,
    );
    // Abrir YouTube com busca de louvor
    // launchUrl(Uri.parse('https://youtube.com/results?search_query=louvores+gospel+suaves'));
  }

  void _mostrarVersiculo() {
    final diaDoAno = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    // Versículo do dia (simplificado aqui)
    _adicionarMensagem(
      '📖 Versículo do dia:\n\n"Tudo posso naquele que me fortalece."\n— Filipenses 4:13',
      ehSonin: true,
      especial: true,
    );
  }


  // ----------------------------------------------------------
  // INTERFACE
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bege,
      body: Stack(
        children: [
          // Fundo floral
          _buildFundoFloral(),

          // Conteúdo principal
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildConversa()),
                if (_ouvindo) _buildIndicadorVoz(),
                _buildBotaoVoz(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // FUNDO FLORAL
  // ----------------------------------------------------------
  Widget _buildFundoFloral() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF0F5), // rosa muito claro no topo
            Color(0xFFFFF8F0), // bege quente embaixo
          ],
        ),
      ),
      child: CustomPaint(
        painter: _FloralPainter(),
        size: Size.infinite,
      ),
    );
  }


  // ----------------------------------------------------------
  // HEADER COM AVATAR
  // ----------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: _rosaPrincipal.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar da Sonin.IA
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _rosaPrincipal, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _rosaPrincipal.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/avatar.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nome e status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sonin.IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textoPrincipal,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _pensando
                      ? 'pensando...'
                      : _ouvindo
                          ? 'ouvindo você... 🎤'
                          : 'aqui pra você 🌸',
                  style: TextStyle(
                    fontSize: 12,
                    color: _pensando || _ouvindo
                        ? _rosaPrincipal
                        : _textoSecundario,
                  ),
                ),
              ],
            ),
          ),

          // Botão de configurações discreto
          IconButton(
            icon: const Icon(Icons.more_vert, color: _textoSecundario),
            onPressed: () {},
            iconSize: 20,
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // ÁREA DE CONVERSA
  // ----------------------------------------------------------
  Widget _buildConversa() {
    if (_mensagens.isEmpty) {
      return _buildTelaVazia();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _mensagens.length + (_pensando ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _mensagens.length && _pensando) {
          return _buildBolhaPensando();
        }
        return _buildBolha(_mensagens[index]);
      },
    );
  }

  Widget _buildTelaVazia() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/avatar.png',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 16),
          const Text(
            'Toque no botão e fale comigo! 🌸',
            style: TextStyle(
              fontSize: 16,
              color: _textoSecundario,
            ),
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // BOLHAS DE CONVERSA
  // ----------------------------------------------------------
  Widget _buildBolha(Map<String, dynamic> mensagem) {
    final ehSonin = mensagem['ehSonin'] as bool;
    final especial = mensagem['especial'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            ehSonin ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar pequeno da Sonin (só nas mensagens dela)
          if (ehSonin) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _rosaPrincipal, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          // Bolha da mensagem
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: ehSonin
                    ? especial
                        ? _lilas.withOpacity(0.9)
                        : Colors.white.withOpacity(0.95)
                    : _rosaPrincipal.withOpacity(0.85),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(ehSonin ? 4 : 20),
                  bottomRight: Radius.circular(ehSonin ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensagem['texto'],
                    style: TextStyle(
                      fontSize: 16,
                      color: ehSonin ? _textoPrincipal : Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mensagem['hora'],
                    style: TextStyle(
                      fontSize: 10,
                      color: ehSonin
                          ? _textoSecundario.withOpacity(0.6)
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBolhaPensando() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _rosaPrincipal, width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset('assets/images/avatar.png', fit: BoxFit.cover),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildPontoPensando(0),
                const SizedBox(width: 4),
                _buildPontoPensando(200),
                const SizedBox(width: 4),
                _buildPontoPensando(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPontoPensando(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _rosaPrincipal.withOpacity(0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }


  // ----------------------------------------------------------
  // INDICADOR DE VOZ
  // ----------------------------------------------------------
  Widget _buildIndicadorVoz() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _rosaClaro,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rosaPrincipal.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, color: _rosaPrincipal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _textoOuvindo.isEmpty ? 'Ouvindo...' : _textoOuvindo,
              style: TextStyle(
                color: _textoPrincipal,
                fontSize: 14,
                fontStyle: _textoOuvindo.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // BOTÃO DE VOZ PRINCIPAL
  // ----------------------------------------------------------
  Widget _buildBotaoVoz() {
    return Container(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          // Texto de instrução
          Text(
            _ouvindo ? 'Toque para parar' : 'Toque e fale comigo',
            style: TextStyle(
              fontSize: 13,
              color: _textoSecundario,
            ),
          ),
          const SizedBox(height: 12),

          // Botão principal
          GestureDetector(
            onTap: _toggleVoz,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _ouvindo ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: _ouvindo
                        ? [
                            const Color(0xFFE91E63),
                            const Color(0xFFC2185B),
                          ]
                        : [
                            _rosaPrincipal,
                            const Color(0xFFE91E63),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _rosaPrincipal.withOpacity(0.5),
                      blurRadius: _ouvindo ? 20 : 12,
                      spreadRadius: _ouvindo ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _ouvindo ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    _stt.cancelar();
    _tts.parar();
    super.dispose();
  }
}


// ----------------------------------------------------------
// PINTOR DO FUNDO FLORAL
// Desenha flores suaves no fundo da tela
// ----------------------------------------------------------
class _FloralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Flores decorativas nos cantos
    _desenharFlor(canvas, paint,
        Offset(size.width * 0.05, size.height * 0.08), 30,
        const Color(0xFFF8BBD9));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.92, size.height * 0.05), 20,
        const Color(0xFFE1BEE7));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.88, size.height * 0.25), 15,
        const Color(0xFFF48FB1));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.08, size.height * 0.35), 18,
        const Color(0xFFCE93D8));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.95, size.height * 0.65), 25,
        const Color(0xFFF8BBD9));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.05, size.height * 0.75), 20,
        const Color(0xFFE1BEE7));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.15, size.height * 0.92), 35,
        const Color(0xFFF48FB1).withOpacity(0.4));

    _desenharFlor(canvas, paint,
        Offset(size.width * 0.85, size.height * 0.90), 28,
        const Color(0xFFCE93D8).withOpacity(0.4));
  }

  void _desenharFlor(Canvas canvas, Paint paint, Offset centro,
      double tamanho, Color cor) {
    paint.color = cor.withOpacity(0.35);

    // 5 pétalas ao redor do centro
    for (int i = 0; i < 5; i++) {
      final angulo = (i * 72) * (3.14159 / 180);
      final offset = Offset(
        centro.dx + tamanho * 0.6 * (angulo == 0 ? 1 : 0.95) * _cos(angulo),
        centro.dy + tamanho * 0.6 * _sin(angulo),
      );
      canvas.drawCircle(offset, tamanho * 0.45, paint);
    }

    // Centro da flor
    paint.color = cor.withOpacity(0.5);
    canvas.drawCircle(centro, tamanho * 0.25, paint);
  }

  double _cos(double angulo) => angulo == 0 ? 1 :
    (angulo < 1.6 ? 0.309 : angulo < 3.2 ? -0.809 :
     angulo < 4.8 ? -0.809 : 0.309);

  double _sin(double angulo) => angulo == 0 ? 0 :
    (angulo < 1.6 ? 0.951 : angulo < 3.2 ? 0.588 :
     angulo < 4.8 ? -0.588 : -0.951);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

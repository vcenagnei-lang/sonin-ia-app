// devocional_screen.dart
//
// Tela do devocional da Sonin.IA.
//
// Estética: fundo floral pastel, tons rosados e lilás.
// Linguagem visual: aberta, espaçosa, tipografia generosa (a Dona Sônia
// não enxerga letrinha pequena). Animações suaves, nada agressivo.
//
// Fluxo:
//   1. Aparece em silêncio — ela lê primeiro
//   2. Botão ▶️ pra ouvir em voz alta (TTS)
//   3. Botão 💬 pra conversar sobre
//   4. No final — card da música com play/pause

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'devocional_models.dart';
import 'devocional_service.dart';

// Dependências do projeto:
//   import 'tts_service.dart';
//   import 'chat_screen.dart';

class DevocionalScreen extends StatefulWidget {
  final DevocionalService service;
  final dynamic ttsService; // TtsService — voz natural via Google TTS / ElevenLabs

  const DevocionalScreen({
    super.key,
    required this.service,
    required this.ttsService,
  });

  @override
  State<DevocionalScreen> createState() => _DevocionalScreenState();
}

class _DevocionalScreenState extends State<DevocionalScreen>
    with TickerProviderStateMixin {
  DevocionalDoDia? _devocional;
  bool _carregando = true;
  String? _erro;

  // Animação de entrada — versículo aparece como uma respiração
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Estado do TTS (voz da reflexão)
  bool _ouvindo = false;

  // Player da música gospel
  late final AudioPlayer _musicaPlayer;
  bool _tocandoMusica = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _musicaPlayer = AudioPlayer();
    _musicaPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _tocandoMusica = state == PlayerState.playing);
    });

    _carregarDevocional();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _musicaPlayer.dispose();
    super.dispose();
  }

  Future<void> _carregarDevocional() async {
    try {
      final dev = await widget.service.obterDevocionalDeHoje();
      await widget.service.marcarComoAberto();
      if (!mounted) return;
      setState(() {
        _devocional = dev;
        _carregando = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro =
            'Não consegui buscar a palavra de hoje agora. Vamos tentar daqui a pouco? 🌸';
        _carregando = false;
      });
    }
  }

  // ============================================================
  // OUVIR A REFLEXÃO (TTS)
  // ============================================================
  Future<void> _toggleOuvir() async {
    if (_devocional == null) return;
    if (_ouvindo) {
      await widget.ttsService.pause();
      if (!mounted) return;
      setState(() => _ouvindo = false);
      return;
    }
    final texto = '${_devocional!.saudacao}\n\n'
        '${_devocional!.versiculo.texto}\n'
        '${_devocional!.versiculo.referencia}\n\n'
        '${_devocional!.reflexao}\n\n'
        '${_devocional!.conviteConversa}';

    setState(() => _ouvindo = true);
    await widget.ttsService.falar(texto, onComplete: () {
      if (!mounted) return;
      setState(() => _ouvindo = false);
    });
    await widget.service.marcarComoOuvido();
  }

  // ============================================================
  // CONVERSAR SOBRE A PALAVRA
  // ============================================================
  Future<void> _conversar() async {
    if (_devocional == null) return;
    await widget.service.marcarComoConversado();
    if (!mounted) return;

    // Abre a tela de conversa já com o contexto do devocional injetado
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'contexto_inicial': 'devocional_${_devocional!.dataGeracao}',
        'tema': _devocional!.metadata.temaCentral,
      },
    );
  }

  // ============================================================
  // TOCAR / PAUSAR MÚSICA
  // ============================================================
  Future<void> _toggleMusica() async {
    if (_devocional?.musica.youtubeUrl == null) return;
    final url = _devocional!.musica.youtubeUrl!;

    if (_tocandoMusica) {
      await _musicaPlayer.pause();
    } else {
      // Em produção: usar yt_player_flutter ou youtube_explode_dart
      // para extrair o stream de áudio do YouTube e tocar via audioplayers.
      // Aqui, ponto de integração:
      await _musicaPlayer.play(UrlSource(url));
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF7D5A8A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Palavra de Hoje',
          style: TextStyle(
            color: Color(0xFF7D5A8A),
            fontFamily: 'Lora',
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCE4EC), // rosa pastel suave
              Color(0xFFF3E5F5), // lilás claro
              Color(0xFFFFF8F0), // creme rosado
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Camada decorativa: flores muito sutis nos cantos
            const _FloresDecorativas(),

            // Conteúdo
            SafeArea(
              child: _carregando
                  ? const _Carregando()
                  : _erro != null
                      ? _ErroSuave(mensagem: _erro!)
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _conteudo(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    final d = _devocional!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saudação
          Text(
            d.saudacao,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: Color(0xFF8E5572),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Card do versículo
          _CardVersiculo(versiculo: d.versiculo),
          const SizedBox(height: 28),

          // Reflexão
          Text(
            d.reflexao,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 19,
              height: 1.7,
              color: Color(0xFF4A3850),
            ),
          ),
          const SizedBox(height: 28),

          // Convite à conversa
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE5C9D5),
                width: 1,
              ),
            ),
            child: Text(
              d.conviteConversa,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Color(0xFF7D5A8A),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Botões de ação (ouvir + conversar)
          Row(
            children: [
              Expanded(
                child: _BotaoSuave(
                  icone: _ouvindo
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: _ouvindo ? 'Pausar' : 'Ouvir',
                  onTap: _toggleOuvir,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BotaoSuave(
                  icone: Icons.chat_bubble_outline_rounded,
                  label: 'Conversar',
                  onTap: _conversar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Card da música gospel
          _CardMusica(
            musica: d.musica,
            tocando: _tocandoMusica,
            onToggle: _toggleMusica,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENTES VISUAIS
// ============================================================

class _CardVersiculo extends StatelessWidget {
  final Versiculo versiculo;
  const _CardVersiculo({required this.versiculo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.85),
            const Color(0xFFFCE4EC).withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5C9D5).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFFB48BC4),
            size: 28,
          ),
          const SizedBox(height: 16),
          Text(
            '"${versiculo.texto}"',
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 20,
              fontStyle: FontStyle.italic,
              color: Color(0xFF4A3850),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            versiculo.referencia,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E5572),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoSuave extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  const _BotaoSuave({
    required this.icone,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5C9D5), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5C9D5).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: const Color(0xFF8E5572), size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7D5A8A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMusica extends StatelessWidget {
  final SugestaoMusical musica;
  final bool tocando;
  final VoidCallback onToggle;

  const _CardMusica({
    required this.musica,
    required this.tocando,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB48BC4), Color(0xFFD4A5C3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB48BC4).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'Pra ouvir agora 🎵',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tocando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: const Color(0xFF8E5572),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musica.titulo,
                      style: const TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${musica.artista} • ${musica.ano}',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.88),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (musica.motivo.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              musica.motivo,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.92),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FloresDecorativas extends StatelessWidget {
  const _FloresDecorativas();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Opacity(
              opacity: 0.18,
              child: Icon(
                Icons.local_florist_rounded,
                size: 160,
                color: const Color(0xFFE5C9D5),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Opacity(
              opacity: 0.14,
              child: Icon(
                Icons.local_florist_rounded,
                size: 180,
                color: const Color(0xFFD4A5C3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFB48BC4),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Preparando a palavra de hoje... 🌸',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 17,
              color: Color(0xFF8E5572),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroSuave extends StatelessWidget {
  final String mensagem;
  const _ErroSuave({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 18,
            color: Color(0xFF8E5572),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET DO BOTÃO NA TELA PRINCIPAL
// ============================================================

/// Botão que aparece na tela principal (chat_screen.dart).
/// Quando o devocional do dia ainda não foi aberto: pulsa suave,
/// com brilho dourado. Quando já foi aberto: fica normal.
class BotaoDevocional extends StatefulWidget {
  final DevocionalService service;
  final VoidCallback onTap;

  const BotaoDevocional({
    super.key,
    required this.service,
    required this.onTap,
  });

  @override
  State<BotaoDevocional> createState() => _BotaoDevocionalState();
}

class _BotaoDevocionalState extends State<BotaoDevocional>
    with SingleTickerProviderStateMixin {
  bool _jaAbriu = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _checarStatus();
  }

  Future<void> _checarStatus() async {
    final ja = await widget.service.jaAbriuHoje();
    if (!mounted) return;
    setState(() => _jaAbriu = ja);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) {
        final escala = _jaAbriu ? 1.0 : 1.0 + (_pulseCtrl.value * 0.06);
        final brilho = _jaAbriu ? 0.0 : (_pulseCtrl.value * 0.6);
        return Transform.scale(
          scale: escala,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (!_jaAbriu)
                  BoxShadow(
                    color: const Color(0xFFFFD580).withOpacity(brilho),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          widget.onTap();
          setState(() => _jaAbriu = true);
        },
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCE4EC), Color(0xFFD4A5C3)],
            ),
          ),
          child: const Center(
            child: Text('🌸', style: TextStyle(fontSize: 38)),
          ),
        ),
      ),
    );
  }
}

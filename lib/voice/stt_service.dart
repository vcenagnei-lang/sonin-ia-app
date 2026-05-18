// ============================================================
// stt_service.dart
// Voz → Texto (Speech to Text)
// Ouve a Dona Sônia e converte para texto
// Gratuito, funciona offline com o Google STT do Android
// ============================================================

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SttService {

  final SpeechToText _stt = SpeechToText();

  bool _disponivel = false;
  bool _ouvindo = false;

  // Callbacks — a tela vai usar esses para atualizar a UI
  Function(String texto)? onTextoFinal;
  Function(String textoParcial)? onTextoParcial;
  Function()? onFimDeOuvir;
  Function(String erro)? onErro;


  // ----------------------------------------------------------
  // INICIALIZAR
  // ----------------------------------------------------------
  Future<bool> inicializar() async {
    _disponivel = await _stt.initialize(
      onError: (erro) {
        _ouvindo = false;
        onErro?.call(erro.errorMsg);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _ouvindo = false;
          onFimDeOuvir?.call();
        }
      },
    );
    return _disponivel;
  }


  // ----------------------------------------------------------
  // COMEÇAR A OUVIR
  // Chamado quando a Dona Sônia toca o botão de voz
  // ----------------------------------------------------------
  Future<void> comecarOuvir() async {
    if (!_disponivel) {
      await inicializar();
    }

    if (!_disponivel) {
      onErro?.call('Reconhecimento de voz não disponível neste aparelho.');
      return;
    }

    if (_ouvindo) return;

    _ouvindo = true;

    await _stt.listen(
      onResult: (SpeechRecognitionResult resultado) {
        if (resultado.finalResult) {
          // Texto final — Dona Sônia terminou de falar
          onTextoFinal?.call(resultado.recognizedWords);
          _ouvindo = false;
        } else {
          // Texto parcial — mostra enquanto ela ainda fala
          onTextoParcial?.call(resultado.recognizedWords);
        }
      },
      localeId: 'pt_BR',          // português do Brasil
      listenFor: const Duration(seconds: 30),   // ouve por até 30 segundos
      pauseFor: const Duration(seconds: 4),     // para após 4s de silêncio
      partialResults: true,       // mostra texto enquanto fala
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }


  // ----------------------------------------------------------
  // PARAR DE OUVIR
  // ----------------------------------------------------------
  Future<void> pararOuvir() async {
    if (_ouvindo) {
      await _stt.stop();
      _ouvindo = false;
    }
  }


  // ----------------------------------------------------------
  // CANCELAR
  // ----------------------------------------------------------
  Future<void> cancelar() async {
    await _stt.cancel();
    _ouvindo = false;
  }


  // ----------------------------------------------------------
  // GETTERS
  // ----------------------------------------------------------
  bool get estaOuvindo => _ouvindo;
  bool get disponivel => _disponivel;
}

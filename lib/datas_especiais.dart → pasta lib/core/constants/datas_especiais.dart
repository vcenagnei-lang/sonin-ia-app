// ============================================================
// datas_especiais.dart
// Aniversários, feriados e datas importantes para a Dona Sônia
// A Sonin.IA usa esse arquivo para surpreender nos momentos certos
// ============================================================

class DatasEspeciais {

  // ----------------------------------------------------------
  // ANIVERSÁRIOS DA FAMÍLIA
  // ----------------------------------------------------------
  static const List<Map<String, dynamic>> aniversarios = [
    {
      'nome': 'Dona Sônia',
      'dia': 4,
      'mes': 7,
      'relacao': 'você mesma! Feliz aniversário! 🎂',
      'mensagem_sonin': 'Hoje é seu aniversário, Dona Sônia! 🎂🎉 Que Deus abençoe cada dia da sua vida com muita saúde, paz e alegria. A família toda te ama muito!',
    },
    {
      'nome': 'Rodrigo',
      'dia': 6,
      'mes': 7,
      'relacao': 'filho',
      'mensagem_sonin': 'Dona Sônia, amanhã é aniversário do Digo! 🎂 Quer que eu te ajude a preparar uma mensagem especial para ele?',
    },
    {
      'nome': 'Rafael',
      'dia': 5,
      'mes': 9,
      'relacao': 'filho',
      'mensagem_sonin': 'Dona Sônia, amanhã é aniversário do Finha! 🎂 Quer que eu te ajude a preparar uma mensagem especial para ele?',
    },
    {
      'nome': 'Evandro',
      'dia': 6,
      'mes': 11,
      'relacao': 'filho caçula',
      'mensagem_sonin': 'Dona Sônia, amanhã é aniversário do Vando, seu caçulinha! 🎂 Quer que eu te ajude a preparar uma mensagem especial?',
    },
    {
      'nome': 'Tia Silmara',
      'dia': 15,
      'mes': 3,
      'relacao': 'familiar',
      'mensagem_sonin': 'Dona Sônia, hoje é aniversário da tia Silmara! 🎂 Quer mandar uma mensagem para ela?',
    },
  ];


  // ----------------------------------------------------------
  // DATAS ESPECIAIS DA FAMÍLIA
  // ----------------------------------------------------------
  static const List<Map<String, dynamic>> datasEspeciais = [
    {
      'nome': 'Formatura do Dudu',
      'dia': 3,
      'mes': 12,
      'ano': 2026,
      'mensagem_sonin': 'Dona Sônia, hoje é a formatura do Duduzinho! 🎓🥹 Que dia especial! O primeiro formando da família!',
    },
  ];


  // ----------------------------------------------------------
  // FERIADOS NACIONAIS E DE SÃO PAULO
  // ----------------------------------------------------------
  static const List<Map<String, dynamic>> feriados = [

    // Feriados Nacionais
    {'nome': 'Ano Novo',             'dia': 1,  'mes': 1,
     'mensagem': 'Feliz Ano Novo, Dona Sônia! 🎆 Que Deus abençoe esse novo ano com muita saúde e alegria para toda a família!'},

    {'nome': 'Carnaval',             'dia': 0,  'mes': 0,  'movel': true,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é Carnaval, mas sei que você prefere um bom louvor né? 😊🙏'},

    {'nome': 'Sexta-feira Santa',    'dia': 0,  'mes': 0,  'movel': true,
     'mensagem': 'Dona Sônia, hoje é Sexta-feira Santa. Um dia de reflexão e gratidão pela vida de Cristo. 🙏'},

    {'nome': 'Páscoa',               'dia': 0,  'mes': 0,  'movel': true,
     'mensagem': 'Feliz Páscoa, Dona Sônia! 🐣✝️ Cristo ressuscitou! Que essa Páscoa traga renovação e esperança para você e toda a família!'},

    {'nome': 'Dia do Trabalho',      'dia': 1,  'mes': 5,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é feriado, dia do trabalhador. Um dia abençoado para descansar! 🙏'},

    {'nome': 'Corpus Christi',       'dia': 0,  'mes': 0,  'movel': true,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é feriado de Corpus Christi. Um ótimo dia para descansar e ouvir um louvor. 🙏'},

    {'nome': 'Independência do Brasil', 'dia': 7, 'mes': 9,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é 7 de setembro, Independência do Brasil! 🇧🇷 Um dia abençoado para você!'},

    {'nome': 'Nossa Senhora Aparecida', 'dia': 12, 'mes': 10,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é feriado de Nossa Senhora Aparecida. Um dia abençoado! 🙏'},

    {'nome': 'Finados',              'dia': 2,  'mes': 11,
     'mensagem': 'Bom dia, Dona Sônia. Hoje é Dia de Finados, um dia de lembrança e oração. 🙏 Que Deus console os corações de quem perdeu alguém querido.'},

    {'nome': 'Proclamação da República', 'dia': 15, 'mes': 11,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é feriado, dia da Proclamação da República. Bom descanso! 🙏'},

    {'nome': 'Natal',                'dia': 25, 'mes': 12,
     'mensagem': 'Feliz Natal, Dona Sônia! 🎄✨ Que o nascimento de Jesus traga paz, amor e alegria para você e toda a família! Amo você!'},

    // Feriados de São Paulo (Estado e Cidade)
    {'nome': 'Aniversário de São Paulo', 'dia': 25, 'mes': 1,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é aniversário da cidade de São Paulo! 🎂 Feriado aqui no estado!'},

    {'nome': 'Revolução Constitucionalista', 'dia': 9, 'mes': 7,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é feriado aqui em São Paulo, dia da Revolução Constitucionalista. Bom descanso! 🙏'},

    // Datas especiais (não feriado mas importantes)
    {'nome': 'Dia das Mães',         'dia': 0,  'mes': 5,  'movel': true,
     'mensagem': 'Feliz Dia das Mães, Dona Sônia! 🌸💐 Você é uma mãe incrível, cheia de amor e fé. O Evandro, o Rodrigo e o Rafael têm muito orgulho de você!'},

    {'nome': 'Dia dos Pais',         'dia': 0,  'mes': 8,  'movel': true,
     'mensagem': 'Bom dia, Dona Sônia! Hoje é Dia dos Pais. Um dia para lembrar com carinho de quem já se foi e abraçar o Zé com muito amor. 🙏'},

    {'nome': 'Dia das Mulheres',     'dia': 8,  'mes': 3,
     'mensagem': 'Feliz Dia das Mulheres, Dona Sônia! 🌸 Você é uma mulher de fé, de força e de muito amor. Que Deus te abençoe sempre!'},

    {'nome': 'Dia de Finados',       'dia': 2,  'mes': 11,
     'mensagem': 'Bom dia, Dona Sônia. Hoje é Dia de Finados. Um dia de oração e memória. 🙏'},
  ];


  // ----------------------------------------------------------
  // VERIFICAR SE HOJE TEM ALGO ESPECIAL
  // ----------------------------------------------------------
  static Map<String, dynamic>? verificarHoje(DateTime hoje) {

    // Verifica aniversários amanhã (aviso com 1 dia de antecedência)
    final amanha = hoje.add(const Duration(days: 1));
    for (final a in aniversarios) {
      if (a['dia'] == amanha.day && a['mes'] == amanha.month) {
        return {'tipo': 'aniversario_amanha', ...a};
      }
    }

    // Verifica aniversários hoje
    for (final a in aniversarios) {
      if (a['dia'] == hoje.day && a['mes'] == hoje.month) {
        return {'tipo': 'aniversario_hoje', ...a};
      }
    }

    // Verifica datas especiais
    for (final d in datasEspeciais) {
      if (d['dia'] == hoje.day && d['mes'] == hoje.month) {
        return {'tipo': 'data_especial', ...d};
      }
    }

    // Verifica feriados
    for (final f in feriados) {
      if (f['dia'] == hoje.day && f['mes'] == hoje.month) {
        return {'tipo': 'feriado', ...f};
      }
    }

    return null;
  }
}

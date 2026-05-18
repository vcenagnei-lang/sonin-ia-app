// ============================================================
// database_helper.dart
// Banco de dados local da Sonin.IA
// Guarda conversas, memórias e lembretes da Dona Sônia
// Funciona 100% offline, zero custo
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {

  // Instância única do banco (padrão Singleton)
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // ----------------------------------------------------------
  // ABRIR OU CRIAR O BANCO
  // ----------------------------------------------------------
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final caminho = await getDatabasesPath();
    final caminhoCompleto = join(caminho, 'sonin_ia.db');

    return await openDatabase(
      caminhoCompleto,
      version: 1,
      onCreate: _criarTabelas,
    );
  }


  // ----------------------------------------------------------
  // CRIAR AS TABELAS
  // Chamado apenas na primeira vez que o app abre
  // ----------------------------------------------------------
  Future<void> _criarTabelas(Database db, int version) async {

    // Tabela de mensagens — histórico de conversas
    await db.execute('''
      CREATE TABLE mensagens (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        papel       TEXT NOT NULL,  -- 'usuario' ou 'sonin'
        conteudo    TEXT NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');

    // Tabela de memórias — fatos sobre a Dona Sônia
    await db.execute('''
      CREATE TABLE memorias (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria   TEXT NOT NULL,  -- saude, familia, preferencia, rotina
        chave       TEXT NOT NULL,
        valor       TEXT NOT NULL,
        atualizado  TEXT NOT NULL
      )
    ''');

    // Tabela de lembretes — remédios, compromissos
    await db.execute('''
      CREATE TABLE lembretes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nome        TEXT NOT NULL,
        hora        INTEGER NOT NULL,
        minuto      INTEGER NOT NULL,
        mensagem    TEXT NOT NULL,
        ativo       INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabela de aniversários aprendidos pela IA
    await db.execute('''
      CREATE TABLE aniversarios (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nome        TEXT NOT NULL,
        dia         INTEGER NOT NULL,
        mes         INTEGER NOT NULL,
        relacao     TEXT
      )
    ''');

    // Inserir lembrete padrão do remédio
    await db.insert('lembretes', {
      'nome': 'Remédio da manhã',
      'hora': 8,
      'minuto': 0,
      'mensagem': 'Dona Sônia, já são 8h! Hora do remédio da manhã. 💊',
      'ativo': 1,
    });

    // Inserir aniversários já conhecidos
    final aniversarios = [
      {'nome': 'Dona Sônia',  'dia': 4,  'mes': 7,  'relacao': 'você mesma'},
      {'nome': 'Rodrigo',     'dia': 6,  'mes': 7,  'relacao': 'filho'},
      {'nome': 'Rafael',      'dia': 5,  'mes': 9,  'relacao': 'filho'},
      {'nome': 'Evandro',     'dia': 6,  'mes': 11, 'relacao': 'filho caçula'},
      {'nome': 'Tia Silmara', 'dia': 15, 'mes': 3,  'relacao': 'familiar'},
    ];

    for (final a in aniversarios) {
      await db.insert('aniversarios', a);
    }
  }


  // ----------------------------------------------------------
  // MENSAGENS — salvar e buscar conversa
  // ----------------------------------------------------------

  // Salvar mensagem nova
  Future<void> salvarMensagem(String papel, String conteudo) async {
    final db = await database;
    await db.insert('mensagens', {
      'papel': papel,
      'conteudo': conteudo,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Buscar últimas N mensagens (para contexto da IA)
  Future<List<Map<String, dynamic>>> buscarUltimasMensagens({int limite = 10}) async {
    final db = await database;
    return await db.query(
      'mensagens',
      orderBy: 'id DESC',
      limit: limite,
    );
  }

  // Formatar histórico para enviar para a IA
  Future<String> getHistoricoFormatado({int limite = 5}) async {
    final mensagens = await buscarUltimasMensagens(limite: limite);
    final invertidas = mensagens.reversed.toList();

    return invertidas.map((m) {
      final papel = m['papel'] == 'usuario' ? 'Dona Sônia' : 'Sonin';
      return '$papel: ${m['conteudo']}';
    }).join('\n');
  }


  // ----------------------------------------------------------
  // MEMÓRIAS — o que a Sonin.IA aprendeu
  // ----------------------------------------------------------

  // Salvar ou atualizar memória
  Future<void> salvarMemoria(String categoria, String chave, String valor) async {
    final db = await database;

    // Verifica se já existe
    final existente = await db.query(
      'memorias',
      where: 'categoria = ? AND chave = ?',
      whereArgs: [categoria, chave],
    );

    if (existente.isEmpty) {
      await db.insert('memorias', {
        'categoria': categoria,
        'chave': chave,
        'valor': valor,
        'atualizado': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'memorias',
        {
          'valor': valor,
          'atualizado': DateTime.now().toIso8601String(),
        },
        where: 'categoria = ? AND chave = ?',
        whereArgs: [categoria, chave],
      );
    }
  }

  // Buscar todas as memórias (para contexto da IA)
  Future<String> getMemoriasFormatadas() async {
    final db = await database;
    final memorias = await db.query('memorias', orderBy: 'categoria');

    if (memorias.isEmpty) return 'Nenhuma memória ainda.';

    return memorias.map((m) {
      return '- ${m['categoria']}: ${m['chave']} = ${m['valor']}';
    }).join('\n');
  }


  // ----------------------------------------------------------
  // LEMBRETES — remédios e compromissos
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> getLembretes() async {
    final db = await database;
    return await db.query('lembretes', where: 'ativo = 1');
  }

  Future<void> adicionarLembrete({
    required String nome,
    required int hora,
    required int minuto,
    required String mensagem,
  }) async {
    final db = await database;
    await db.insert('lembretes', {
      'nome': nome,
      'hora': hora,
      'minuto': minuto,
      'mensagem': mensagem,
      'ativo': 1,
    });
  }


  // ----------------------------------------------------------
  // ANIVERSÁRIOS
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAniversariosHoje() async {
    final db = await database;
    final hoje = DateTime.now();
    return await db.query(
      'aniversarios',
      where: 'dia = ? AND mes = ?',
      whereArgs: [hoje.day, hoje.month],
    );
  }

  Future<List<Map<String, dynamic>>> getAniversariosAmanha() async {
    final db = await database;
    final amanha = DateTime.now().add(const Duration(days: 1));
    return await db.query(
      'aniversarios',
      where: 'dia = ? AND mes = ?',
      whereArgs: [amanha.day, amanha.month],
    );
  }

  Future<void> salvarAniversario({
    required String nome,
    required int dia,
    required int mes,
    String? relacao,
  }) async {
    final db = await database;
    await db.insert('aniversarios', {
      'nome': nome,
      'dia': dia,
      'mes': mes,
      'relacao': relacao ?? '',
    });
  }
}

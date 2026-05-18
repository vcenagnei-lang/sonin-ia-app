// ============================================================
// database_helper.dart
// Banco de dados local da Sonin.IA
// Versão 2 — com suporte ao módulo devocional
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

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
      version: 2,
      onCreate: _criarTabelas,
      onUpgrade: _atualizarTabelas,
    );
  }

  // ----------------------------------------------------------
  // CRIAR TABELAS
  // ----------------------------------------------------------
  Future<void> _criarTabelas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mensagens (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        papel       TEXT NOT NULL,
        conteudo    TEXT NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE memorias (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria   TEXT NOT NULL,
        chave       TEXT NOT NULL,
        valor       TEXT NOT NULL,
        atualizado  TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE aniversarios (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nome        TEXT NOT NULL,
        dia         INTEGER NOT NULL,
        mes         INTEGER NOT NULL,
        relacao     TEXT
      )
    ''');

    // Devocional — cache diário
    await db.execute('''
      CREATE TABLE devocionais (
        data        TEXT PRIMARY KEY,
        json        TEXT NOT NULL,
        aberto      INTEGER NOT NULL DEFAULT 0,
        ouvido      INTEGER NOT NULL DEFAULT 0,
        conversado  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Versículos usados — evitar repetição em 30 dias
    await db.execute('''
      CREATE TABLE versiculos_usados (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        referencia  TEXT NOT NULL,
        data_uso    TEXT NOT NULL
      )
    ''');

    await _inserirDadosIniciais(db);
  }

  // ----------------------------------------------------------
  // ATUALIZAR TABELAS — app antigo para versão 2
  // ----------------------------------------------------------
  Future<void> _atualizarTabelas(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS devocionais (
          data        TEXT PRIMARY KEY,
          json        TEXT NOT NULL,
          aberto      INTEGER NOT NULL DEFAULT 0,
          ouvido      INTEGER NOT NULL DEFAULT 0,
          conversado  INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS versiculos_usados (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          referencia  TEXT NOT NULL,
          data_uso    TEXT NOT NULL
        )
      ''');
    }
  }

  // ----------------------------------------------------------
  // DADOS INICIAIS
  // ----------------------------------------------------------
  Future<void> _inserirDadosIniciais(Database db) async {
    await db.insert('lembretes', {
      'nome': 'Remédio da manhã',
      'hora': 8,
      'minuto': 0,
      'mensagem': 'Dona Sônia, já são 8h! Hora do remédio da manhã. 💊',
      'ativo': 1,
    });

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
  // MENSAGENS
  // ----------------------------------------------------------
  Future<void> salvarMensagem(String papel, String conteudo) async {
    final db = await database;
    await db.insert('mensagens', {
      'papel': papel,
      'conteudo': conteudo,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> buscarUltimasMensagens({int limite = 10}) async {
    final db = await database;
    return await db.query('mensagens', orderBy: 'id DESC', limit: limite);
  }

  Future<String> getHistoricoFormatado({int limite = 5}) async {
    final mensagens = await buscarUltimasMensagens(limite: limite);
    final invertidas = mensagens.reversed.toList();
    return invertidas.map((m) {
      final papel = m['papel'] == 'usuario' ? 'Dona Sônia' : 'Sonin';
      return '$papel: ${m['conteudo']}';
    }).join('\n');
  }

  // Resumo das conversas dos últimos 7 dias — para o devocional
  Future<List<String>> resumoConversasUltimos7Dias() async {
    final db = await database;
    final seteDiasAtras = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final mensagens = await db.query(
      'mensagens',
      where: 'timestamp >= ? AND papel = ?',
      whereArgs: [seteDiasAtras, 'usuario'],
      orderBy: 'timestamp DESC',
      limit: 30,
    );
    return mensagens.map((m) => m['conteudo'] as String).toList();
  }

  // ----------------------------------------------------------
  // MEMÓRIAS
  // ----------------------------------------------------------
  Future<void> salvarMemoria(String categoria, String chave, String valor) async {
    final db = await database;
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
        {'valor': valor, 'atualizado': DateTime.now().toIso8601String()},
        where: 'categoria = ? AND chave = ?',
        whereArgs: [categoria, chave],
      );
    }
  }

  Future<String> getMemoriasFormatadas() async {
    final db = await database;
    final memorias = await db.query('memorias', orderBy: 'categoria');
    if (memorias.isEmpty) return 'Nenhuma memória ainda.';
    return memorias.map((m) {
      return '- ${m['categoria']}: ${m['chave']} = ${m['valor']}';
    }).join('\n');
  }

  // Memórias relevantes para o devocional
  Future<List<String>> memoriasRelevantesParaDevocional() async {
    final db = await database;
    final categorias = ['saude', 'emocional', 'familia', 'espiritualidade', 'rotina'];
    final memorias = await db.query(
      'memorias',
      where: 'categoria IN (${categorias.map((_) => '?').join(',')})',
      whereArgs: categorias,
      orderBy: 'atualizado DESC',
      limit: 15,
    );
    return memorias.map((m) {
      return '${m['categoria']}: ${m['chave']} = ${m['valor']}';
    }).toList();
  }

  // ----------------------------------------------------------
  // LEMBRETES
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

  // ----------------------------------------------------------
  // DEVOCIONAL — cache e controle
  // ----------------------------------------------------------
  Future<String?> obterDevocionalDoDia(String data) async {
    final db = await database;
    final resultado = await db.query(
      'devocionais',
      where: 'data = ?',
      whereArgs: [data],
    );
    if (resultado.isEmpty) return null;
    return resultado.first['json'] as String?;
  }

  Future<void> salvarDevocionalDoDia(String data, String json) async {
    final db = await database;
    await db.insert(
      'devocionais',
      {'data': data, 'json': json, 'aberto': 0, 'ouvido': 0, 'conversado': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizarFlagsDevocional(
    String data, {
    bool? aberto,
    bool? ouvido,
    bool? conversado,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (aberto != null) updates['aberto'] = aberto ? 1 : 0;
    if (ouvido != null) updates['ouvido'] = ouvido ? 1 : 0;
    if (conversado != null) updates['conversado'] = conversado ? 1 : 0;
    if (updates.isEmpty) return;
    await db.update('devocionais', updates, where: 'data = ?', whereArgs: [data]);
  }

  Future<bool> devocionalAbertoHoje() async {
    final db = await database;
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final resultado = await db.query(
      'devocionais',
      where: 'data = ?',
      whereArgs: [hoje],
    );
    if (resultado.isEmpty) return false;
    return (resultado.first['aberto'] as int) == 1;
  }

  // ----------------------------------------------------------
  // VERSÍCULOS USADOS
  // ----------------------------------------------------------
  Future<void> registrarVersiculoUsado(String referencia) async {
    final db = await database;
    await db.insert('versiculos_usados', {
      'referencia': referencia,
      'data_uso': DateTime.now().toIso8601String(),
    });
  }

  Future<List<String>> versiculosUsadosUltimos30Dias() async {
    final db = await database;
    final trintaDiasAtras = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final resultado = await db.query(
      'versiculos_usados',
      where: 'data_uso >= ?',
      whereArgs: [trintaDiasAtras],
      orderBy: 'data_uso DESC',
    );
    return resultado.map((r) => r['referencia'] as String).toList();
  }
}

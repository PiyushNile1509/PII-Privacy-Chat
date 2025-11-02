import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';

class LocalStorageService {
  static Database? _database;
  static const String _dbName = 'pii_privacy_chat.db';
  static const int _dbVersion = 2;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        user_message TEXT NOT NULL,
        anonymized_text TEXT NOT NULL,
        llm_prompt TEXT NOT NULL,
        bot_response TEXT NOT NULL,
        reconstructed_text TEXT NOT NULL,
        privacy_score REAL NOT NULL,
        processing_time REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN llm_prompt TEXT DEFAULT ""');
    }
  }

  static Future<void> saveSession(ChatSession session) async {
    final db = await database;
    await db.insert(
      'sessions',
      {
        'id': session.id,
        'title': session.title,
        'created_at': session.createdAt.toIso8601String(),
        'updated_at': session.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ChatSession>> getSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) {
      return ChatSession(
        id: maps[i]['id'],
        title: maps[i]['title'],
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });
  }

  static Future<void> updateSession(ChatSession session) async {
    final db = await database;
    await db.update(
      'sessions',
      {
        'title': session.title,
        'updated_at': session.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  static Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  static Future<void> saveMessage(String sessionId, ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': message.id,
        'session_id': sessionId,
        'user_message': message.userMessage,
        'anonymized_text': message.anonymizedText,
        'llm_prompt': message.llmPrompt,
        'bot_response': message.botResponse,
        'reconstructed_text': message.reconstructedText,
        'privacy_score': message.privacyScore,
        'processing_time': message.processingTime,
        'timestamp': message.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return ChatMessage(
        id: maps[i]['id'],
        userMessage: maps[i]['user_message'],
        anonymizedText: maps[i]['anonymized_text'],
        llmPrompt: maps[i]['llm_prompt'] ?? maps[i]['anonymized_text'],
        botResponse: maps[i]['bot_response'],
        reconstructedText: maps[i]['reconstructed_text'],
        privacyScore: maps[i]['privacy_score'],
        processingTime: maps[i]['processing_time'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  static Future<List<ChatMessage>> getAllMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ChatMessage(
        id: maps[i]['id'],
        userMessage: maps[i]['user_message'],
        anonymizedText: maps[i]['anonymized_text'],
        llmPrompt: maps[i]['llm_prompt'] ?? maps[i]['anonymized_text'],
        botResponse: maps[i]['bot_response'],
        reconstructedText: maps[i]['reconstructed_text'],
        privacyScore: maps[i]['privacy_score'],
        processingTime: maps[i]['processing_time'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('sessions');
  }
}
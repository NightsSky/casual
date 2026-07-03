import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/models.dart';

class StorageService {
  static const _notesKey = 'gitnote_notes';
  static const _gitConfigKey = 'gitnote_git_config';

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = notes.map((n) => n.toJson()).toList();
    await prefs.setString(_notesKey, jsonEncode(jsonList));
  }

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_notesKey);
    if (data == null) return [];

    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => Note.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveGitConfig(GitConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gitConfigKey, jsonEncode(config.toJson()));
  }

  Future<GitConfig> loadGitConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_gitConfigKey);
    if (data == null) {
      return const GitConfig(
        platform: GitPlatform.github,
        token: '',
        owner: '',
        repo: '',
      );
    }

    return GitConfig.fromJson(jsonDecode(data));
  }

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

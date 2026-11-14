import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Everything the app remembers lives on the phone: the profile, the chat,
/// and what Kayra has learned about the user.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  /// A random id for this install, used by the server for the daily limit.
  String get deviceId {
    final saved = _prefs.getString('deviceId');
    if (saved != null) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final id = List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
    _prefs.setString('deviceId', id);
    return id;
  }

  Profile? get profile {
    final raw = _prefs.getString('profile');
    return raw == null ? null : Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(Profile profile) =>
      _prefs.setString('profile', jsonEncode(profile.toJson()));

  List<ChatMessage> get messages {
    final raw = _prefs.getString('messages');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMessages(List<ChatMessage> messages) => _prefs.setString(
      'messages', jsonEncode(messages.map((m) => m.toJson()).toList()));

  List<String> get memory => _prefs.getStringList('memory') ?? [];

  Future<void> saveMemory(List<String> memory) =>
      _prefs.setStringList('memory', memory);

  /// Deletes the profile, chat and memory. The device id stays so the daily
  /// limit cannot be reset by wiping data from inside the app.
  Future<void> deleteMyData() async {
    await _prefs.remove('profile');
    await _prefs.remove('messages');
    await _prefs.remove('memory');
  }
}

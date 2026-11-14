class ChatMessage {
  ChatMessage({required this.fromUser, required this.text, DateTime? time})
      : time = time ?? DateTime.now();

  final bool fromUser;
  final String text;
  final DateTime time;

  Map<String, dynamic> toJson() =>
      {'fromUser': fromUser, 'text': text, 'time': time.toIso8601String()};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        fromUser: json['fromUser'] as bool,
        text: json['text'] as String,
        time: DateTime.parse(json['time'] as String),
      );
}

class Profile {
  const Profile({required this.name, required this.nickname});

  final String name;

  /// What Kayra calls the user. Falls back to [name] when left empty.
  final String nickname;

  String get callName => nickname.isEmpty ? name : nickname;

  Map<String, dynamic> toJson() => {'name': name, 'nickname': nickname};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String,
        nickname: json['nickname'] as String? ?? '',
      );
}

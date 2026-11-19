/// The relationship levels, in order. The server decides which one the user is on.
const levelNames = ['Stranger', 'Dost', 'Crush', 'Girlfriend', 'Soulmate'];

class Mood {
  const Mood(this.id, this.label, {this.level, this.plus = false});

  final String id;
  final String label;

  /// The level index that unlocks this mood, if any.
  final int? level;

  /// Whether only Kayra Plus members can pick it.
  final bool plus;
}

const moods = [
  Mood('sweet', '🥰 Sweet'),
  Mood('funny', '😜 Funny'),
  Mood('flirty', '😏 Flirty', level: 2),
  Mood('shy', '🙈 Shy', plus: true),
];

class KayraPhoto {
  const KayraPhoto(this.asset, {this.level, this.plus = false});

  final String asset;
  final int? level;
  final bool plus;
}

const kayraPhotos = [
  KayraPhoto('assets/kayra/g1.jpg'),
  KayraPhoto('assets/kayra/g2.jpg', level: 2),
  KayraPhoto('assets/kayra/g3.jpg', level: 3),
  KayraPhoto('assets/kayra/g4.jpg', plus: true),
];

const reactions = ['❤️', '😂', '😮', '🥺', '🔥'];

class Message {
  const Message({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.reaction,
  });

  final int id;
  final String role;
  final String text;
  final DateTime time;
  final String? reaction;

  bool get fromUser => role == 'user';

  Message withReaction(String? emoji) =>
      Message(id: id, role: role, text: text, time: time, reaction: emoji);

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as int,
        role: json['role'] as String,
        text: json['text'] as String,
        reaction: json['reaction'] as String?,
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
      );
}

class Progress {
  const Progress({
    required this.xp,
    required this.level,
    required this.levelName,
    required this.levelStart,
    required this.nextAt,
    required this.streak,
  });

  final int xp;
  final int level;
  final String levelName;
  final int levelStart;
  final int? nextAt;
  final int streak;

  /// How far along the current level the user is, from 0 to 1.
  double get fraction =>
      nextAt == null ? 1 : ((xp - levelStart) / (nextAt! - levelStart)).clamp(0, 1).toDouble();

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
        xp: json['xp'] as int,
        level: json['level'] as int,
        levelName: json['levelName'] as String,
        levelStart: json['levelStart'] as int,
        nextAt: json['nextAt'] as int?,
        streak: json['streak'] as int,
      );
}

class Profile {
  const Profile({required this.name, required this.nickname, required this.mood, required this.email});

  final String name;
  final String nickname;
  final String mood;
  final String email;

  String get callName => nickname.isEmpty ? name : nickname;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String,
        nickname: json['nickname'] as String,
        mood: json['mood'] as String,
        email: json['email'] as String,
      );
}

class PlusStatus {
  const PlusStatus({required this.active, this.until, this.productId});

  final bool active;
  final DateTime? until;
  final String? productId;

  factory PlusStatus.fromJson(Map<String, dynamic> json) => PlusStatus(
        active: json['active'] as bool,
        until: json['until'] == null ? null : DateTime.fromMillisecondsSinceEpoch(json['until'] as int),
        productId: json['productId'] as String?,
      );
}

class Usage {
  const Usage({required this.limit, required this.remaining});

  final int limit;
  final int remaining;

  factory Usage.fromJson(Map<String, dynamic> json) =>
      Usage(limit: json['limit'] as int, remaining: json['remaining'] as int);
}

class Memory {
  const Memory({required this.id, required this.fact});

  final int id;
  final String fact;

  factory Memory.fromJson(Map<String, dynamic> json) =>
      Memory(id: json['id'] as int, fact: json['fact'] as String);
}

class MemoryList {
  const MemoryList({required this.items, required this.limit});

  final List<Memory> items;
  final int limit;

  factory MemoryList.fromJson(Map<String, dynamic> json) => MemoryList(
        items: [for (final m in json['items'] as List) Memory.fromJson(m as Map<String, dynamic>)],
        limit: json['limit'] as int,
      );
}

/// Everything the server knows about the signed-in user.
class Me {
  const Me({
    required this.profile,
    required this.progress,
    required this.plus,
    required this.usage,
    required this.memory,
    required this.messages,
    required this.purchaseAccountId,
  });

  final Profile profile;
  final Progress progress;
  final PlusStatus plus;
  final Usage usage;
  final MemoryList memory;
  final List<Message> messages;
  final String purchaseAccountId;

  bool get needsProfile => profile.name.isEmpty;

  Me copyWith({
    Profile? profile,
    Progress? progress,
    PlusStatus? plus,
    Usage? usage,
    MemoryList? memory,
    List<Message>? messages,
  }) =>
      Me(
        profile: profile ?? this.profile,
        progress: progress ?? this.progress,
        plus: plus ?? this.plus,
        usage: usage ?? this.usage,
        memory: memory ?? this.memory,
        messages: messages ?? this.messages,
        purchaseAccountId: purchaseAccountId,
      );

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        profile: Profile.fromJson(json['profile'] as Map<String, dynamic>),
        progress: Progress.fromJson(json['progress'] as Map<String, dynamic>),
        plus: PlusStatus.fromJson(json['plus'] as Map<String, dynamic>),
        usage: Usage.fromJson(json['usage'] as Map<String, dynamic>),
        memory: MemoryList.fromJson(json['memory'] as Map<String, dynamic>),
        messages: [for (final m in json['messages'] as List) Message.fromJson(m as Map<String, dynamic>)],
        purchaseAccountId: json['purchaseAccountId'] as String,
      );
}

class ChatResult {
  const ChatResult({
    required this.sent,
    required this.reply,
    required this.suggestions,
    required this.progress,
    required this.usage,
    this.levelUp,
  });

  final Message sent;
  final Message reply;
  final List<String> suggestions;
  final Progress progress;
  final Usage usage;
  final String? levelUp;

  factory ChatResult.fromJson(Map<String, dynamic> json) => ChatResult(
        sent: Message.fromJson(json['sent'] as Map<String, dynamic>),
        reply: Message.fromJson(json['reply'] as Map<String, dynamic>),
        suggestions: (json['suggestions'] as List).cast<String>(),
        progress: Progress.fromJson(json['progress'] as Map<String, dynamic>),
        usage: Usage.fromJson(json['usage'] as Map<String, dynamic>),
        levelUp: json['levelUp'] as String?,
      );
}

class SignInResult {
  const SignInResult({required this.token, required this.suggestedName, required this.me});

  final String token;
  final String suggestedName;
  final Me me;
}

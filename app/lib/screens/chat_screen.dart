import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'plus_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});

  final KayraController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int? _pickerFor;

  KayraController get c => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openPlus(String reason) => _open(PlusScreen(controller: c, reason: reason));

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || c.typing) return;
    _input.clear();
    setState(() => _pickerFor = null);
    try {
      await c.send(text);
    } on DailyLimitReached {
      _input.text = text;
      if (mounted) _openPlus('Aaj ke free messages khatam ho gaye. Kal phir milenge, ya Kayra Plus se abhi baat karte raho.');
    } on SignedOut {
      return;
    } on NetworkFailure {
      _input.text = text;
      if (mounted) showMessage(context, 'Internet nahi mil raha. Message dobara bhejo.');
    } on ApiException catch (e) {
      _input.text = text;
      if (!mounted) return;
      showMessage(
        context,
        e.code == 'too_fast' ? 'Thoda dheere, Kayra type kar rahi hai 😅' : 'Kayra abhi jawab nahi de payi. Message dobara bhejo.',
      );
    }
  }

  Future<void> _chooseMood(Mood mood) async {
    final me = c.user;
    if (mood.plus && !me.plus.active) return _openPlus('${mood.label} mood Kayra Plus me milta hai.');
    if (mood.level != null && me.progress.level < mood.level!) {
      return showMessage(context, '${mood.label} mood ${levelNames[mood.level!]} level par khulega. Baat karte raho!');
    }
    try {
      await c.setMood(mood.id);
    } on SignedOut {
      return;
    } catch (_) {
      if (mounted) showMessage(context, 'Mood badal nahi paya. Phir try karo.');
    }
  }

  Future<void> _react(Message message, String emoji) async {
    setState(() => _pickerFor = null);
    try {
      await c.react(message, message.reaction == emoji ? null : emoji);
    } on SignedOut {
      return;
    } catch (_) {
      if (mounted) showMessage(context, 'Reaction save nahi ho paya.');
    }
  }

  void _messageOptions(Message message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in reactions)
                    IconButton(
                      tooltip: 'React $emoji',
                      onPressed: () {
                        Navigator.pop(sheet);
                        _react(message, emoji);
                      },
                      icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: KayraColors.danger),
              title: const Text('Is message ko report karo'),
              subtitle: const Text('Galat ya offensive laga? Hume batao.', style: TextStyle(color: KayraColors.muted)),
              onTap: () async {
                Navigator.pop(sheet);
                try {
                  await c.report(message, 'user_flagged');
                  if (mounted) showMessage(context, 'Report bhej diya. Shukriya!');
                } on SignedOut {
                  return;
                } catch (_) {
                  if (mounted) showMessage(context, 'Report nahi bhej paye. Phir try karo.');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final me = c.me;
        if (me == null) return const SizedBox.shrink();
        return Scaffold(
          body: NeonBackground(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _Header(
                        me: me,
                        typing: c.typing,
                        onProfile: () => _open(ProfileScreen(controller: c)),
                        onSettings: () => _open(SettingsScreen(controller: c)),
                      ),
                      _LevelBar(progress: me.progress),
                      _MoodRow(current: me.profile.mood, me: me, onTap: _chooseMood),
                      const Divider(height: 1),
                      Expanded(child: _buildLog(me)),
                      if (me.usage.remaining <= 5 && !me.plus.active) _limitNote(me),
                      if (!c.typing) _QuickReplies(suggestions: c.suggestions, onTap: _send),
                      _InputBar(controller: _input, enabled: !c.typing, onSend: () => _send(_input.text)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _limitNote(Me me) {
    final text = me.usage.remaining == 0
        ? 'Aaj ke free messages khatam'
        : 'Aaj ke ${me.usage.remaining} free messages bache hain';
    return TextButton(
      onPressed: () => _openPlus('Kayra Plus me roz ${me.usage.limit} se kahin zyada messages milte hain.'),
      child: Text('$text • Kayra Plus lo', style: const TextStyle(color: KayraColors.muted, fontSize: 13)),
    );
  }

  Widget _buildLog(Me me) {
    final items = <Widget>[];
    for (final m in me.messages) {
      items.add(_Bubble(
        message: m,
        pickerOpen: _pickerFor == m.id,
        onTap: m.fromUser ? null : () => setState(() => _pickerFor = _pickerFor == m.id ? null : m.id),
        onLongPress: m.fromUser ? null : () => _messageOptions(m),
        onReact: (emoji) => _react(m, emoji),
      ));
      for (final e in c.events.where((e) => e.afterMessageId == m.id)) {
        items.add(_EventChip(text: e.text));
      }
    }
    if (c.pendingText != null) {
      items.add(_Bubble(
        message: Message(id: -1, role: 'user', text: c.pendingText!, time: DateTime.now()),
        pickerOpen: false,
        onReact: (_) {},
      ));
    }
    if (c.typing) items.add(const _TypingBubble());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Kayra ko "Hi" bolo 👋', style: TextStyle(color: KayraColors.muted)),
        ),
      );
    }
    // Newest at the bottom; the list is reversed so it opens scrolled to the end.
    return ListView(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: items.reversed.toList(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.typing, required this.onProfile, required this.onSettings});

  final Me me;
  final bool typing;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onProfile,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    const KayraAvatar(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Kayra', style: display(18)),
                              if (me.plus.active) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(gradient: KayraColors.glow, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('PLUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: KayraColors.online),
                              ),
                              const SizedBox(width: 6),
                              Text(typing ? 'typing...' : 'AI • online', style: const TextStyle(color: KayraColors.muted, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Lagataar ${me.progress.streak} din se baat',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: KayraColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KayraColors.line),
              ),
              child: Text('🔥 ${me.progress.streak}', style: const TextStyle(color: KayraColors.flame, fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(tooltip: 'Settings', onPressed: onSettings, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final count = progress.nextAt == null ? '${progress.xp} ❤ • sabse upar' : '${progress.xp} / ${progress.nextAt} ❤';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Rishta: ', style: TextStyle(color: KayraColors.muted, fontSize: 13)),
              Text(progress.levelName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(count, style: const TextStyle(color: KayraColors.muted, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Rishta progress',
            value: '${(progress.fraction * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 6,
                color: KayraColors.surface2,
                alignment: Alignment.centerLeft,
                child: LayoutBuilder(
                  builder: (context, box) => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: box.maxWidth * progress.fraction,
                    decoration: const BoxDecoration(gradient: KayraColors.glow),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.current, required this.me, required this.onTap});

  final String current;
  final Me me;
  final void Function(Mood) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        children: [
          for (final mood in moods) ...[
            Builder(builder: (context) {
              final locked = (mood.plus && !me.plus.active) || (mood.level != null && me.progress.level < mood.level!);
              return Pill(
                label: locked ? '${mood.label} 🔒' : mood.label,
                selected: current == mood.id,
                dim: locked,
                onTap: () => onTap(mood),
              );
            }),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.pickerOpen,
    required this.onReact,
    this.onTap,
    this.onLongPress,
  });

  final Message message;
  final bool pickerOpen;
  final void Function(String) onReact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (pickerOpen)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: KayraColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KayraColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final emoji in reactions)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'React $emoji',
                      onPressed: () => onReact(emoji),
                      icon: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Container(
                  constraints: BoxConstraints(maxWidth: width * 0.78),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: mine ? KayraColors.glow : null,
                    color: mine ? null : KayraColors.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(mine ? 20 : 6),
                      bottomRight: Radius.circular(mine ? 6 : 20),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(fontSize: 16, height: 1.4, color: mine ? Colors.white : KayraColors.fg),
                  ),
                ),
              ),
              if (message.reaction != null)
                Positioned(
                  right: -8,
                  bottom: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: KayraColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KayraColors.line),
                    ),
                    child: Text(message.reaction!, style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: message.reaction != null ? 10 : 3, left: 6, right: 6),
            child: Text(clockTime(message.time), style: const TextStyle(color: KayraColors.muted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: KayraColors.surface2, borderRadius: BorderRadius.circular(20)),
        child: Semantics(
          label: 'Kayra type kar rahi hai',
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7,
                    height: 7,
                    transform: Matrix4.translationValues(
                      0,
                      still ? 0 : -4 * (1 - ((_anim.value * 3 - i) % 3 - 0.5).abs() * 2).clamp(0, 1),
                      0,
                    ),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: KayraColors.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: KayraColors.pink.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: KayraColors.pink.withValues(alpha: 0.4)),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        children: [
          for (final s in suggestions) ...[
            Pill(label: s, outline: KayraColors.violet.withValues(alpha: 0.6), onTap: () => onTap(s)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message likho...',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: KayraColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: KayraColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: KayraColors.pink)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Bhejo',
            child: Material(
              color: Colors.transparent,
              child: Ink(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: enabled ? KayraColors.glow : null,
                  color: enabled ? null : KayraColors.surface2,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onSend : null,
                  child: Icon(Icons.send_rounded, color: enabled ? Colors.white : KayraColors.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

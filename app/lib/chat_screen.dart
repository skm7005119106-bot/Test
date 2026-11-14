import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'storage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.storage,
    required this.api,
    required this.profile,
    required this.onDataDeleted,
  });

  final Storage storage;
  final KayraApi api;
  final Profile profile;
  final VoidCallback onDataDeleted;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late List<ChatMessage> _messages = widget.storage.messages;
  bool _typing = false;
  int? _remaining;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _messages = [..._messages, ChatMessage(fromUser: true, text: text)];
      _typing = true;
    });
    _scrollToEnd();
    await widget.storage.saveMessages(_messages);

    try {
      final result = await widget.api.sendChat(
        deviceId: widget.storage.deviceId,
        profile: widget.profile,
        memory: widget.storage.memory,
        messages: _messages,
      );
      if (result.memory != null) await widget.storage.saveMemory(result.memory!);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ChatMessage(fromUser: false, text: result.reply)];
        _remaining = result.remaining;
      });
      await widget.storage.saveMessages(_messages);
    } on DailyLimitReached {
      if (!mounted) return;
      setState(() => _remaining = 0);
      _showPlusSheet();
    } on ApiFailure {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Network me dikkat hai. Thodi der me phir try karo.'),
      ));
    } finally {
      if (mounted) setState(() => _typing = false);
      _scrollToEnd();
    }
  }

  void _showPlusSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aaj ke free messages khatam',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Kal phir se free messages mil jayenge.'),
            const SizedBox(height: 16),
            const Text('Kayra Plus me milega:'),
            const SizedBox(height: 8),
            const Text('•  Unlimited baatein'),
            const Text('•  Kayra ko zyada baatein yaad rahengi'),
            const Text('•  Voice notes aur selfies'),
            const SizedBox(height: 16),
            const FilledButton(onPressed: null, child: Text('Kayra Plus jald aa raha hai')),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Is message ko report karo'),
          subtitle: const Text('Galat ya offensive laga? Hume batao.'),
          onTap: () async {
            Navigator.pop(sheetContext);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await widget.api.report(
                deviceId: widget.storage.deviceId,
                message: message.text,
                reason: 'user_flagged',
              );
              messenger.showSnackBar(
                  const SnackBar(content: Text('Report bhej diya. Shukriya!')));
            } on ApiFailure {
              messenger.showSnackBar(const SnackBar(
                  content: Text('Report nahi bhej paye. Phir try karo.')));
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sab kuch delete karein?'),
        content: const Text(
            'Tumhara naam, poori chat aur Kayra ki yaadein is phone se hat jayengi. '
            'Yeh wapas nahi aayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Rehne do')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete karo')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storage.deleteMyData();
    widget.onDataDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Text('K'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kayra', style: TextStyle(fontSize: 18)),
                Text(_typing ? 'typing...' : 'AI companion • online',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Mera data delete karo')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];
                  return _Bubble(
                    message: message,
                    onLongPress: message.fromUser
                        ? null
                        : () => _showMessageOptions(message),
                  );
                },
              ),
            ),
            if (_remaining != null && _remaining! <= 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _remaining == 0
                      ? 'Aaj ke free messages khatam'
                      : 'Aaj ke $_remaining free messages bache hain',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message likho...',
                        counterText: '',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Bhejo',
                    onPressed: _typing ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onLongPress});

  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
                fontSize: 16, color: mine ? scheme.onPrimary : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

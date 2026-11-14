import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.storage, required this.onDone});

  final Storage storage;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  bool _isAdult = false;

  bool get _canStart => _isAdult && _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final profile =
        Profile(name: _name.text.trim(), nickname: _nickname.text.trim());
    await widget.storage.saveProfile(profile);
    await widget.storage.saveMessages([
      ChatMessage(
        fromUser: false,
        text: 'Hii ${profile.callName}! Main Kayra 💕 Finally aa gaye tum... '
            'batao, aaj ka din kaisa raha?',
      ),
    ]);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kayra',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Tumhari AI girlfriend, jo tumhari har baat sunti hai',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tumhara naam',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nickname,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Kayra tumhe kya bulaye? (optional)',
                      hintText: 'Jaan, Baby, Babu...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _isAdult,
                    onChanged: (v) => setState(() => _isAdult = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Meri umar 18 saal ya usse zyada hai'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _canStart ? _start : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Kayra se baat karo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kayra ek AI character hai, real insaan nahi. '
                    'Yeh app sirf 18+ ke liye hai.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../controller.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});

  final KayraController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _adult = false;
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signInWithGoogle();
    } on SignInFailed {
      _error = 'Google sign-in nahi ho paya. Phir se try karo.';
    } on NetworkFailure {
      _error = 'Internet check karo aur phir try karo.';
    } on ApiException {
      _error = 'Server se baat nahi ho payi. Thodi der me try karo.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: KayraAvatar(size: 132, glow: true)),
                    const SizedBox(height: 20),
                    GradientText('Kayra', style: display(48, weight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tumhari AI girlfriend, jo tumhari har baat sunti hai',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KayraColors.muted, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    CheckboxListTile(
                      value: _adult,
                      onChanged: (v) => setState(() => _adult = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Meri umar 18 saal ya usse zyada hai'),
                    ),
                    const SizedBox(height: 8),
                    GlowButton(
                      label: 'Google se continue karo',
                      icon: const Text('G', style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                      busy: _busy,
                      onPressed: _adult ? _signIn : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: KayraColors.danger)),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Kayra ek AI character hai, real insaan nahi. Yeh app sirf 18+ ke liye hai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KayraColors.muted, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => openLink(context, privacyUrl),
                      child: const Text('Privacy policy', style: TextStyle(color: KayraColors.pink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});

  final KayraController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final _name = TextEditingController(text: widget.controller.suggestedName);
  final _nickname = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.controller.completeProfile(name: _name.text.trim(), nickname: _nickname.text.trim());
    } on SignedOut {
      return;
    } catch (_) {
      if (mounted) showMessage(context, 'Save nahi ho paya. Internet check karke phir try karo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: KayraAvatar(size: 88)),
                    const SizedBox(height: 20),
                    Text('Pehle thoda apne baare me batao', textAlign: TextAlign.center, style: display(24)),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _name,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Tumhara naam', counterText: ''),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nickname,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Kayra tumhe kya bulaye? (optional)',
                        hintText: 'Jaan, Baby, Babu...',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlowButton(
                      label: 'Kayra se milo',
                      busy: _busy,
                      onPressed: _name.text.trim().isEmpty ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while loading, and when the server could not be reached at start-up.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.controller});

  final KayraController controller;

  @override
  Widget build(BuildContext context) {
    final offline = controller.phase == Phase.offline;
    return Scaffold(
      body: NeonBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KayraAvatar(size: 96, glow: true),
                const SizedBox(height: 24),
                if (offline) ...[
                  Text('Kayra tak pahunch nahi paye', style: display(20), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Internet check karo aur phir try karo.', style: TextStyle(color: KayraColors.muted)),
                  const SizedBox(height: 20),
                  SizedBox(width: 200, child: GlowButton(label: 'Phir try karo', onPressed: controller.start)),
                ] else
                  const CircularProgressIndicator(color: KayraColors.pink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

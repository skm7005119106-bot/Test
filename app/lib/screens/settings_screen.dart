import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets.dart';
import 'memories_screen.dart';
import 'plus_screen.dart';

const appVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final KayraController controller;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _editNames(BuildContext context) async {
    final me = controller.user;
    final name = TextEditingController(text: me.profile.name);
    final nickname = TextEditingController(text: me.profile.nickname);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Naam badlo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Tumhara naam', counterText: '')),
            const SizedBox(height: 12),
            TextField(
              controller: nickname,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Kayra tumhe kya bulaye?', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Rehne do')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save karo')),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    try {
      await controller.updateNames(name: name.text.trim(), nickname: nickname.text.trim());
      if (context.mounted) showMessage(context, 'Save ho gaya');
    } on SignedOut {
      return;
    } catch (_) {
      if (context.mounted) showMessage(context, 'Save nahi ho paya. Phir try karo.');
    }
  }

  Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Rehne do')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action, style: const TextStyle(color: KayraColors.danger)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearChat(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Chat history saaf karein?',
      body: 'Saare messages delete ho jayenge. Rishta level, streak aur Kayra ki yaadein bani rahengi.',
      action: 'Saaf karo',
    );
    if (!ok) return;
    try {
      await controller.clearChat();
      if (context.mounted) showMessage(context, 'Chat saaf ho gayi');
    } on SignedOut {
      return;
    } catch (_) {
      if (context.mounted) showMessage(context, 'Chat saaf nahi ho payi. Phir try karo.');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final plus = controller.user.plus.active;
    final navigator = Navigator.of(context);
    final ok = await _confirm(
      context,
      title: 'Account delete karein?',
      body: 'Tumhara naam, saari chat, Kayra ki yaadein, level aur streak hamesha ke liye delete ho jayenge. '
          'Yeh wapas nahi aayega.'
          '${plus ? '\n\nKayra Plus subscription isse cancel nahi hoga. Use Google Play > Subscriptions me cancel karo.' : ''}',
      action: 'Delete karo',
    );
    if (!ok) return;
    try {
      await controller.deleteAccount();
      navigator.popUntil((route) => route.isFirst);
    } on SignedOut {
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (context.mounted) showMessage(context, 'Account delete nahi ho paya. Internet check karke phir try karo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final me = controller.me;
        if (me == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const _Section('Profile'),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(me.profile.name),
                    subtitle: Text(
                      me.profile.nickname.isEmpty ? me.profile.email : 'Kayra bulati hai: ${me.profile.nickname}',
                      style: const TextStyle(color: KayraColors.muted),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _editNames(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined),
                    title: const Text('Kayra ki yaadein'),
                    subtitle: Text('${me.memory.items.length} baatein yaad hain', style: const TextStyle(color: KayraColors.muted)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, MemoriesScreen(controller: controller)),
                  ),
                  const _Section('Kayra Plus'),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined, color: KayraColors.pink),
                    title: Text(me.plus.active ? 'Kayra Plus chalu hai' : 'Kayra Plus lo'),
                    subtitle: Text(
                      me.plus.active && me.plus.until != null
                          ? 'Agla renewal ya expiry: ${shortDate(me.plus.until!)}'
                          : 'Roz ${me.usage.limit} free messages • aaj ${me.usage.remaining} bache',
                      style: const TextStyle(color: KayraColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, PlusScreen(controller: controller)),
                  ),
                  const _Section('Madad aur privacy'),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => openLink(context, privacyUrl),
                  ),
                  const ListTile(
                    leading: Icon(Icons.health_and_safety_outlined),
                    title: Text('Mann pareshaan hai?'),
                    subtitle: Text(
                      'Tele-MANAS 14416 par call karo (free, 24x7). Kayra ek AI hai, therapist nahi.',
                      style: TextStyle(color: KayraColors.muted),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Open-source licenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(context: context, applicationName: 'Kayra', applicationVersion: appVersion),
                  ),
                  const _Section('Account'),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: const Text('Chat history saaf karo'),
                    onTap: () => _clearChat(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await controller.signOut();
                      navigator.popUntil((route) => route.isFirst);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: KayraColors.danger),
                    title: const Text('Account delete karo', style: TextStyle(color: KayraColors.danger)),
                    onTap: () => _deleteAccount(context),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Kayra $appVersion • Kayra ek AI character hai, real insaan nahi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KayraColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: KayraColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
    );
  }
}

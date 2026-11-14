import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'chat_screen.dart';
import 'onboarding_screen.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KayraApp(storage: await Storage.open(), api: HttpKayraApi()));
}

class KayraApp extends StatefulWidget {
  const KayraApp({super.key, required this.storage, required this.api});

  final Storage storage;
  final KayraApi api;

  @override
  State<KayraApp> createState() => _KayraAppState();
}

class _KayraAppState extends State<KayraApp> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.storage.profile;
    return MaterialApp(
      title: 'Kayra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD6249F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: profile == null
          ? OnboardingScreen(
              storage: widget.storage,
              onDone: () => setState(() {}),
            )
          : ChatScreen(
              storage: widget.storage,
              api: widget.api,
              profile: profile,
              onDataDeleted: () => setState(() {}),
            ),
    );
  }
}

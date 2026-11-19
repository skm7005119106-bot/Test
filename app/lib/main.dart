import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'controller.dart';
import 'screens/chat_screen.dart';
import 'screens/welcome_screens.dart';
import 'services.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Inter', 'Sora']) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/OFL-$font.txt'));
    }
  });
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: KayraColors.bg,
  ));
  final controller = KayraController(
    api: HttpKayraApi(),
    auth: GoogleAuthService(),
    billing: kIsWeb ? NoBillingService() : PlayBillingService(),
    session: await SessionStore.open(),
  );
  runApp(KayraApp(controller: controller));
  controller.start();
}

class KayraApp extends StatelessWidget {
  const KayraApp({super.key, required this.controller});

  final KayraController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kayra',
      debugShowCheckedModeBanner: false,
      theme: kayraTheme(),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.phase) {
          Phase.loading || Phase.offline => StatusScreen(controller: controller),
          Phase.signedOut => SignInScreen(controller: controller),
          Phase.needsProfile => SetupScreen(controller: controller),
          Phase.ready => ChatScreen(controller: controller),
        },
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key, required this.controller});

  final KayraController controller;

  Future<void> _forget(BuildContext context, Memory memory) async {
    try {
      await controller.forget(memory);
      if (context.mounted) showMessage(context, 'Kayra yeh baat bhool gayi');
    } on SignedOut {
      return;
    } catch (_) {
      if (context.mounted) showMessage(context, 'Delete nahi ho paya. Phir try karo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final me = controller.me;
        if (me == null) return const SizedBox.shrink();
        final memory = me.memory;
        return Scaffold(
          appBar: AppBar(title: const Text('Kayra ki yaadein')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Text(
                    'Baaton baaton me Kayra tumhare baare me yeh seekh chuki hai. '
                    'Koi baat galat hai ya yaad nahi rakhwani, to use hata do.',
                    style: const TextStyle(color: KayraColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${memory.items.length} / ${memory.limit} yaadein${me.plus.active ? '' : ' • Kayra Plus me 40'}',
                    style: const TextStyle(color: KayraColors.muted, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 16),
                  if (memory.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: KayraColors.surface, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        children: [
                          const Text('🧠', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 10),
                          Text('Abhi kuch yaad nahi', style: display(18)),
                          const SizedBox(height: 6),
                          const Text(
                            'Kayra se apne baare me baat karo. Har kuch messages ke baad woh zaroori baatein yaad kar legi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: KayraColors.muted),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final item in memory.items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                        decoration: BoxDecoration(
                          color: KayraColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: KayraColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.fact, style: const TextStyle(fontSize: 15))),
                            IconButton(
                              tooltip: 'Bhool jao',
                              onPressed: () => _forget(context, item),
                              icon: const Icon(Icons.close, color: KayraColors.muted),
                            ),
                          ],
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

import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'plus_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final KayraController controller;

  void _openPhoto(BuildContext context, KayraPhoto photo) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialog) => GestureDetector(
        onTap: () => Navigator.pop(dialog),
        child: Center(
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(photo.asset, semanticLabel: 'Kayra ki photo'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final me = controller.me;
        if (me == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(title: const Text('Kayra')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 78 / 69,
                      child: Image.asset('assets/kayra/hero.jpg', fit: BoxFit.cover, semanticLabel: 'Kayra'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Kayra, 22', style: display(28)),
                  const SizedBox(height: 4),
                  const Text('Mumbai • Fashion aur content creator • AI companion', style: TextStyle(color: KayraColors.muted)),
                  const SizedBox(height: 14),
                  const Text(
                    'Delhi ki ladki, ab Mumbai ki baarish ki deewani. Chai ke bina din shuru nahi hota, '
                    'aur purane Bollywood gaano par nakhre zaroor karti hoon.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  _RelationshipCard(progress: me.progress),
                  const _Heading('Pasand'),
                  const _Tags(['Adrak wali chai', 'Baarish', 'Kishore Kumar', 'Late night baatein', 'Street shopping']),
                  const _Heading('Napasand'),
                  const _Tags(['Late reply', 'Jhooth', 'Thanda khana']),
                  const _Heading('Photos'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 4 / 5,
                    children: [
                      for (final photo in kayraPhotos) _PhotoTile(photo: photo, me: me, onOpen: () {
                        final needsLevel = photo.level != null && me.progress.level < photo.level!;
                        if (photo.plus && !me.plus.active) {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => PlusScreen(controller: controller, reason: 'Yeh photo Kayra Plus me milegi.'),
                          ));
                        } else if (needsLevel) {
                          showMessage(context, 'Yeh photo ${levelNames[photo.level!]} level par khulegi. Baat karte raho!');
                        } else {
                          _openPhoto(context, photo);
                        }
                      }),
                    ],
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

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KayraColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KayraColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tum dono ka rishta', style: TextStyle(color: KayraColors.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(progress.levelName, style: display(20)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${progress.xp} ❤', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('🔥 ${progress.streak} din', style: const TextStyle(color: KayraColors.flame, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: KayraColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags(this.tags);

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: KayraColors.surface2, borderRadius: BorderRadius.circular(999)),
            child: Text(tag, style: const TextStyle(fontSize: 14)),
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.me, required this.onOpen});

  final KayraPhoto photo;
  final Me me;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final plusLocked = photo.plus && !me.plus.active;
    final levelLocked = photo.level != null && me.progress.level < photo.level!;
    final locked = plusLocked || levelLocked;
    final label = plusLocked ? '🔒 Kayra Plus' : '🔒 ${levelNames[photo.level ?? 0]} level par';
    return Semantics(
      button: true,
      label: locked ? 'Lock ki hui photo: $label' : 'Kayra ki photo',
      child: GestureDetector(
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (locked)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x66000000), BlendMode.darken),
                    child: Image.asset(photo.asset, fit: BoxFit.cover),
                  ),
                )
              else
                Image.asset(photo.asset, fit: BoxFit.cover),
              if (locked)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

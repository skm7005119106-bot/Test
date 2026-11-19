import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';

/// Kayra's round photo inside a pink-to-violet ring.
class KayraAvatar extends StatelessWidget {
  const KayraAvatar({super.key, this.size = 46, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: KayraColors.glow,
        boxShadow: glow ? [BoxShadow(color: KayraColors.pink.withValues(alpha: 0.45), blurRadius: 48)] : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: KayraColors.bg),
        child: ClipOval(
          child: Image.asset('assets/kayra/avatar.jpg', width: size, height: size, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// The main call-to-action: a pink-to-violet pill.
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled ? KayraColors.glow : null,
            color: enabled ? null : KayraColors.surface2,
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled ? [BoxShadow(color: KayraColors.pink.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))] : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Center(
                child: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[icon!, const SizedBox(width: 10)],
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: enabled ? Colors.white : KayraColors.muted,
                                ),
                              ),
                            ),
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

/// A rounded pill used for moods, quick replies and tags.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.onTap, this.selected = false, this.dim = false, this.outline});

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool dim;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? KayraColors.glow : null,
            color: selected ? null : KayraColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: outline ?? KayraColors.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : KayraColors.fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text painted with Kayra's gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => KayraColors.glow.createShader(bounds),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }
}

/// The page background: dark with a soft violet and pink glow.
class NeonBackground extends StatelessWidget {
  const NeonBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KayraColors.bg,
        gradient: RadialGradient(
          center: Alignment(0.9, -1.1),
          radius: 1.1,
          colors: [Color(0x478B5CFF), Color(0x000D0716)],
        ),
      ),
      // List tiles and buttons draw their touch ripples on this layer, above the glow.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

String clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

String shortDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

const privacyUrl = '$kayraApiUrl/privacy';
const playSubscriptionsUrl = 'https://play.google.com/store/account/subscriptions?package=com.kayraapp.kayra';

Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text('Link nahi khul paya: $url')));
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

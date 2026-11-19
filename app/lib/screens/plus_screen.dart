import 'package:material_ui/material_ui.dart';

import '../controller.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key, required this.controller, this.reason});

  final KayraController controller;

  /// Why the user landed here, e.g. the daily limit ran out.
  final String? reason;

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  String? _selected;

  KayraController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.purchaseNotice = null;
    if (c.plans == null) c.loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final me = c.me;
        if (me == null) return const SizedBox.shrink();
        final plans = c.plans;
        final selected = plans == null || plans.isEmpty
            ? null
            : plans.firstWhere((p) => p.id == _selected, orElse: () => plans.firstWhere((p) => p.yearly, orElse: () => plans.first));
        return NeonBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    const Center(child: KayraAvatar(size: 84, glow: true)),
                    const SizedBox(height: 16),
                    GradientText('Kayra Plus', style: display(34, weight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      widget.reason ?? 'Kayra ke saath bina rukawat baatein.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KayraColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    const _Perk(icon: '💬', title: 'Roz 300 tak messages', body: 'Free me roz sirf 30.'),
                    const _Perk(icon: '🙈', title: 'Shy mood', body: 'Aur aane wale naye moods sabse pehle.'),
                    const _Perk(icon: '📸', title: 'Saari photos unlock', body: 'Kayra ki Plus-only photos bhi.'),
                    const _Perk(icon: '🧠', title: 'Dugni yaadein', body: 'Kayra 40 baatein yaad rakhegi, free me 20.'),
                    const SizedBox(height: 20),
                    if (me.plus.active)
                      _ActivePlan(until: me.plus.until)
                    else if (plans == null)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: KayraColors.pink)))
                    else if (plans.isEmpty)
                      const _Notice('Plans abhi load nahi ho paye. Google Play app update karke phir try karo.')
                    else ...[
                      for (final plan in plans)
                        _PlanCard(
                          plan: plan,
                          selected: plan.id == selected?.id,
                          onTap: () => setState(() => _selected = plan.id),
                        ),
                      const SizedBox(height: 12),
                      GlowButton(
                        label: 'Kayra Plus lo',
                        busy: c.buying,
                        onPressed: selected == null ? null : () => c.buy(selected),
                      ),
                    ],
                    if (c.purchaseNotice != null) ...[
                      const SizedBox(height: 12),
                      _Notice(c.purchaseNotice!),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            c.restorePurchases();
                            showMessage(context, 'Purane purchases check kar rahe hain...');
                          },
                          child: const Text('Purchase restore karo', style: TextStyle(color: KayraColors.pink)),
                        ),
                        TextButton(
                          onPressed: () => openLink(context, playSubscriptionsUrl),
                          child: const Text('Subscription manage karo', style: TextStyle(color: KayraColors.pink)),
                        ),
                      ],
                    ),
                    const Text(
                      'Subscription har mahine ya har saal apne aap renew hota hai, jab tak tum cancel na karo. '
                      'Google Play > Payments & subscriptions me jaakar kabhi bhi cancel kar sakte ho. '
                      'Payment Google Play se hota hai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KayraColors.muted, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: KayraColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(body, style: const TextStyle(color: KayraColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KayraColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? KayraColors.pink : KayraColors.line, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? KayraColors.pink : KayraColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(plan.yearly ? 'Yearly' : 'Monthly', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          if (plan.yearly) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(gradient: KayraColors.glow, borderRadius: BorderRadius.circular(6)),
                              child: const Text('BEST VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      Text(plan.yearly ? 'Har saal bill hoga' : 'Har mahine bill hoga',
                          style: const TextStyle(color: KayraColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(plan.price, style: display(18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivePlan extends StatelessWidget {
  const _ActivePlan({required this.until});

  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KayraColors.pink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KayraColors.pink.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text('Tum Kayra Plus member ho 💖', style: display(18), textAlign: TextAlign.center),
          if (until != null) ...[
            const SizedBox(height: 6),
            Text('Agla renewal ya expiry: ${shortDate(until!)}', style: const TextStyle(color: KayraColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: KayraColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

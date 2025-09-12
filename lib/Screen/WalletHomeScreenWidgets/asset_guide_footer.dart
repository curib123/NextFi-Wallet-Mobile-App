

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';

class AssetGuideFooter extends StatefulWidget {
  const AssetGuideFooter({
    super.key,
    required this.colors,

    // Dynamic context (all optional)
    this.xlmBalance,
    this.usdcBalance,
    this.hasUsdcTrustline, // bool or Future<bool>
    this.isTestnet,

    // UX
    this.randomizeEvery = const Duration(minutes: 1),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 12,

    // Advanced
    this.lowXlmThreshold = 0.2,
    this.includeTags = const <String>{}, // empty = include all
    this.excludeTags = const <String>{},
    this.extraTips = const <GuideTip>[],
    this.rngSeed,
  });

  final AppColor colors;

  final double? xlmBalance;
  final double? usdcBalance;
  final Object? hasUsdcTrustline; // bool or Future<bool>
  final bool? isTestnet;

  final Duration randomizeEvery;
  final EdgeInsets padding;
  final double borderRadius;

  final double lowXlmThreshold;
  final Set<String> includeTags;
  final Set<String> excludeTags;
  final List<GuideTip> extraTips;
  final int? rngSeed;

  @override
  State<AssetGuideFooter> createState() => _AssetGuideFooterState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Model & catalog
// ─────────────────────────────────────────────────────────────────────────────

class GuideTip {
  final String id;
  final IconData icon;
  final String text;
  final Set<String> tags; // e.g., {'xlm','fees','warning'}

  const GuideTip({
    required this.id,
    required this.icon,
    required this.text,
    this.tags = const {},
  });
}

class TipContext {
  final double? xlmBalance;
  final double? usdcBalance;
  final bool? hasUsdcTrustline;
  final bool? isTestnet;
  final double lowXlmThreshold;

  const TipContext({
    required this.xlmBalance,
    required this.usdcBalance,
    required this.hasUsdcTrustline,
    required this.isTestnet,
    required this.lowXlmThreshold,
  });
}

typedef TipPredicate = bool Function(TipContext ctx);

class TipBlueprint {
  final GuideTip tip;
  final TipPredicate? when;

  const TipBlueprint(this.tip, {this.when});
}

// Big, curated catalog (short, friendly, non-techy).
// Tags help you filter/style (e.g., color accents).
final List<TipBlueprint> _TIP_CATALOG = <TipBlueprint>[
  // ── Core XLM (what & when) ────────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'xlm_what',
    icon: LucideIcons.sparkles,
    text: 'XLM keeps things moving — tiny fees, fast transfers.',
    tags: {'xlm', 'fees', 'info'},
  )),
  TipBlueprint(GuideTip(
    id: 'xlm_when',
    icon: LucideIcons.rocket,
    text: 'Use XLM for quick sends and to cover network fees.',
    tags: {'xlm', 'fees', 'success'},
  )),
  TipBlueprint(GuideTip(
    id: 'xlm_buffer',
    icon: LucideIcons.shield,
    text: 'Keep a small XLM buffer so everything runs smoothly.',
    tags: {'xlm', 'fees', 'tip'},
  )),
  TipBlueprint(GuideTip(
    id: 'xlm_reserve',
    icon: LucideIcons.badgeInfo,
    text: 'Stellar keeps a tiny reserve—don’t send your very last XLM.',
    tags: {'xlm', 'fees', 'info'},
  )),

  // ── Core USDC (what & when) ───────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'usdc_what',
    icon: LucideIcons.badgeDollarSign,
    text: 'USDC aims to stay 1 usd — great for saving and getting paid.',
    tags: {'usdc', 'info'},
  )),
  TipBlueprint(GuideTip(
    id: 'usdc_when',
    icon: LucideIcons.piggyBank,
    text: 'Use USDC to hold or send stable value.',
    tags: {'usdc', 'success'},
  )),
  TipBlueprint(GuideTip(
    id: 'usdc_trustline',
    icon: LucideIcons.badgeAlert,
    text: 'First time with USDC? Enable it once to receive it.',
    tags: {'usdc', 'trustline', 'tip'},
  ), when: (ctx) => ctx.hasUsdcTrustline == false),

  // ── Swaps & payments ──────────────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'swap_keep_xlm',
    icon: LucideIcons.arrowLeftRight,
    text: 'Swapping? Keep a little XLM for the fees.',
    tags: {'swap', 'xlm', 'fees', 'tip'},
  )),
  TipBlueprint(GuideTip(
    id: 'payment_memo',
    icon: LucideIcons.stickyNote,
    text: 'Sending to an exchange? Check if a memo is required.',
    tags: {'transfer', 'memo', 'warning'},
  )),
  TipBlueprint(GuideTip(
    id: 'send_small_first',
    icon: LucideIcons.send,
    text: 'New address? Try a small test send first.',
    tags: {'transfer', 'security', 'tip'},
  )),

  // ── Safety & security ─────────────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'sec_secret',
    icon: LucideIcons.lock,
    text: 'Never share your secret phrase. No support will ask for it.',
    tags: {'security', 'warning'},
  )),
  TipBlueprint(GuideTip(
    id: 'sec_verify',
    icon: LucideIcons.shieldCheck,
    text: 'Double-check addresses and links before sending.',
    tags: {'security', 'tip'},
  )),
  TipBlueprint(GuideTip(
    id: 'sec_scams',
    icon: LucideIcons.alertOctagon,
    text: 'Ignore “airdrop” DMs—if it sounds too good, it is.',
    tags: {'security', 'warning'},
  )),

  // ── Practical nudges (conditional) ────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'low_xlm',
    icon: LucideIcons.alertTriangle,
    text: 'Low XLM — add a little so transactions keep working.',
    tags: {'xlm', 'fees', 'warning'},
  ), when: (ctx) => (ctx.xlmBalance ?? double.infinity) < ctx.lowXlmThreshold),

  TipBlueprint(GuideTip(
    id: 'use_usdc_for_value',
    icon: LucideIcons.circleDollarSign,
    text: 'Holding value? Park most in USDC; keep some XLM for fees.',
    tags: {'usdc', 'xlm', 'tip'},
  ), when: (ctx) =>
  (ctx.usdcBalance ?? 0) < (ctx.xlmBalance ?? 0) // nudge toward stability
  ),

  TipBlueprint(GuideTip(
    id: 'swap_tiny_for_fees',
    icon: LucideIcons.arrowUpDown,
    text: 'Out of XLM? Swap a tiny bit of USDC to cover fees.',
    tags: {'swap', 'fees', 'tip'},
  ), when: (ctx) =>
  (ctx.xlmBalance ?? 0) < ctx.lowXlmThreshold && (ctx.usdcBalance ?? 0) > 0),

  // ── Network / environment ─────────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'testnet_note',
    icon: LucideIcons.testTube,
    text: 'Testnet is for practice—tokens there have no real value.',
    tags: {'env', 'info'},
  ), when: (ctx) => ctx.isTestnet == true),

  // ── General money hygiene ─────────────────────────────────────────────────
  TipBlueprint(GuideTip(
    id: 'backup_phrase',
    icon: LucideIcons.server,
    text: 'Back up your secret phrase offline—paper beats screenshots.',
    tags: {'security', 'tip'},
  )),
  TipBlueprint(GuideTip(
    id: 'fee_are_tiny',
    icon: LucideIcons.badgeInfo,
    text: 'Fees are tiny, but you still need a bit of XLM.',
    tags: {'xlm', 'fees', 'info'},
  )),
  TipBlueprint(GuideTip(
    id: 'share_address_safely',
    icon: LucideIcons.share,
    text: 'It’s fine to share your public address—just never the secret.',
    tags: {'security', 'info'},
  )),
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AssetGuideFooterState extends State<AssetGuideFooter> {
  late final math.Random _rng =
  widget.rngSeed == null ? math.Random() : math.Random(widget.rngSeed);

  List<GuideTip> _tips = const [];
  int _index = 0;

  Timer? _timer;
  bool? _resolvedTrustline;

  @override
  void initState() {
    super.initState();
    _maybeResolveTrustline().then((_) {
      _assembleTips();
      _pickRandomNow();
    });
    _assembleTips();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AssetGuideFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trustlineChanged = oldWidget.hasUsdcTrustline != widget.hasUsdcTrustline;
    final balancesChanged =
        oldWidget.xlmBalance != widget.xlmBalance || oldWidget.usdcBalance != widget.usdcBalance;
    final envChanged = oldWidget.isTestnet != widget.isTestnet;
    final filtersChanged = oldWidget.includeTags != widget.includeTags ||
        oldWidget.excludeTags != widget.excludeTags;
    final extrasChanged = oldWidget.extraTips != widget.extraTips;

    if (trustlineChanged) {
      _maybeResolveTrustline().then((_) {
        _assembleTips();
        _pickRandomNow();
      });
    }
    if (balancesChanged || envChanged || filtersChanged || extrasChanged) {
      _assembleTips();
      _pickRandomNow();
    }
    if (oldWidget.randomizeEvery != widget.randomizeEvery) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _maybeResolveTrustline() async {
    final v = widget.hasUsdcTrustline;
    if (v is Future<bool>) {
      try {
        final b = await v;
        if (mounted) _resolvedTrustline = b;
      } catch (_) {
        if (mounted) _resolvedTrustline = null;
      }
    } else if (v is bool) {
      _resolvedTrustline = v;
    } else {
      _resolvedTrustline = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(widget.randomizeEvery, (_) {
      if (!mounted || _tips.isEmpty) return;
      _pickRandomNow();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _startTimer();
  }

  void _pickRandomNow() {
    if (_tips.isEmpty) return;
    if (_tips.length == 1) {
      setState(() => _index = 0);
      return;
    }
    int next = _rng.nextInt(_tips.length);
    if (next == _index) {
      next = (next + 1 + _rng.nextInt(_tips.length - 1)) % _tips.length;
    }
    setState(() => _index = next);
  }

  void _assembleTips() {
    final ctx = TipContext(
      xlmBalance: widget.xlmBalance,
      usdcBalance: widget.usdcBalance,
      hasUsdcTrustline: _resolvedTrustline ??
          (widget.hasUsdcTrustline is bool ? widget.hasUsdcTrustline as bool : null),
      isTestnet: widget.isTestnet,
      lowXlmThreshold: widget.lowXlmThreshold,
    );

    // Build set from catalog
    final List<GuideTip> built = [];
    for (final bp in _TIP_CATALOG) {
      if (bp.when == null || bp.when!(ctx)) {
        // Tag filters
        if (widget.includeTags.isNotEmpty &&
            bp.tip.tags.intersection(widget.includeTags).isEmpty) {
          continue;
        }
        if (bp.tip.tags.intersection(widget.excludeTags).isNotEmpty) {
          continue;
        }
        built.add(bp.tip);
      }
    }

    // Add extras + dedupe by id
    final seen = <String>{};
    final dedup = <GuideTip>[];
    for (final t in [...built, ...widget.extraTips]) {
      if (seen.add(t.id)) dedup.add(t);
    }

    if (!mounted) return;
    setState(() {
      _tips = dedup;
      if (_tips.isEmpty) _index = 0; else _index = _index.clamp(0, _tips.length - 1);
    });
  }

  // Accent color by tags (simple heuristic)
  Color _accentFor(GuideTip tip) {
    final tags = tip.tags;
    if (tags.contains('warning') || tags.contains('security')) return Colors.orange;
    if (tags.contains('success')) return Colors.green;
    if (tags.contains('usdc')) return Colors.blue;
    if (tags.contains('xlm')) return Colors.indigo;
    return Colors.blueGrey;
  }

  LinearGradient _bg(Color base) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [base.withOpacity(0.10), base.withOpacity(0.04)],
  );

  @override
  Widget build(BuildContext context) {
    if (_tips.isEmpty) return const SizedBox.shrink();
    final tip = _tips[_index];
    final base = _accentFor(tip);
    final c = widget.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: _bg(base),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: c.border.withOpacity(0.5)),
      ),
      padding: widget.padding,
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: base.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(tip.icon, size: 16, color: base.withOpacity(0.95)),
          ),
          // One-line text — auto-shrinks if long (FittedBox)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _AutoShrinkText(
                key: ValueKey(tip.id),
                text: tip.text,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Auto-shrinks long one-liners cleanly.
class _AutoShrinkText extends StatelessWidget {
  const _AutoShrinkText({
    super.key,
    required this.text,
    required this.color,
    this.baseSize = 13.5,
    this.weight = FontWeight.w700,
  });

  final String text;
  final Color color;
  final double baseSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: baseSize,
          fontWeight: weight,
          color: color,
          height: 1.0,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

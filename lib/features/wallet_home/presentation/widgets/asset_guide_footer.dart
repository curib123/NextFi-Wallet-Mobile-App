// lib/Screen/WalletHomeScreenWidgets/asset_guide_footer.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/announcements/announcements_service.dart';

class AssetGuideFooter extends StatefulWidget {
  const AssetGuideFooter({
    super.key,
    required this.colors,

    // Dynamic context (all optional)
    this.xlmBalance,
    this.usdcBalance,
    this.isTestnet,
    this.hasUsdcTrustline,

    // UX
    this.randomizeEvery = const Duration(minutes: 1),
    this.padding,
    this.borderRadius = 12,
    this.dense = true, // slimmer by default
    this.allowTwoLines = true, // kept for backwards-compat
    this.maxLines = 3, // NEW: allow longer beginner text
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
  final bool? isTestnet;
  final bool? hasUsdcTrustline;

  final Duration randomizeEvery;
  final EdgeInsets? padding;
  final double borderRadius;
  final bool dense;
  final bool allowTwoLines;
  final int maxLines;

  final double lowXlmThreshold;
  final Set<String> includeTags;
  final Set<String> excludeTags;
  final List<GuideTip> extraTips;
  final int? rngSeed;

  @override
  State<AssetGuideFooter> createState() => _AssetGuideFooterState();
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// reusable_model & catalog
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GuideTip {
  final String id;
  final IconData icon;
  final String text; // supports \n line breaks
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

// Curated catalog â€” friendly, beginner-oriented; longer text with newlines.
// Keep each to ~2â€“3 short clauses so it fits in 2â€“3 lines on mobile.
final List<TipBlueprint> _tipCatalog = <TipBlueprint>[
  // â”€â”€ XLM: what & when (beginner friendly) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'xlm_transactions_long',
      icon: LucideIcons.send,
      text:
          'XLM is great for transactionsâ€”fast to arrive with very low fees.\nKeep a little XLM on hand so transfers and swaps always go through.',
      tags: {'xlm', 'fees', 'tip', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'xlm_risk_profile',
      icon: LucideIcons.trendingUp,
      text:
          'XLM price can move up and down more than USDC.\nGood for investing if youâ€™re comfortable with risk and short-term swings.',
      tags: {'xlm', 'risk', 'info', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'xlm_buffer',
      icon: LucideIcons.shield,
      text:
          'Keep a small XLM buffer for network fees and account reserve.\nIf you send your very last XLM, some actions may stop working.',
      tags: {'xlm', 'fees', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'xlm_planning',
      icon: LucideIcons.calendarDays,
      text:
          'Got a busy day tomorrow (payments, swaps, cash-outs)?\nTop up your XLM today so every step stays smooth and quick.',
      tags: {'xlm', 'planning', 'tip'},
    ),
  ),

  // â”€â”€ USDC: what & when (beginner friendly) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'usdc_simple',
      icon: LucideIcons.badgeDollarSign,
      text:
          'USDC is designed to track the US dollar (â‰ˆ1:1 USD).\nEasy to understandâ€”use it for savings, salaries, and daily budgeting.',
      tags: {'usdc', 'info', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'usdc_when',
      icon: LucideIcons.piggyBank,
      text:
          'Use USDC when you want a steady value without price swings.\nGreat for getting paid and holding funds you plan to spend later.',
      tags: {'usdc', 'success'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'usdc_trustline',
      icon: LucideIcons.badgeAlert,
      text:
          'First time receiving USDC on this wallet?\nEnable USDC once so your wallet can accept it.',
      tags: {'usdc', 'trustline', 'tip', 'beginner'},
    ),
    when: (ctx) => ctx.hasUsdcTrustline == false,
  ),
  TipBlueprint(
    GuideTip(
      id: 'usdc_exchange_min',
      icon: LucideIcons.fileWarning,
      text:
          'Depositing USDC to an exchange?\nCheck the minimum deposit amount and the network before sending.',
      tags: {'usdc', 'deposit', 'warning'},
    ),
  ),

  // â”€â”€ XLM vs USDC: quick heuristics â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'choose_asset_simple',
      icon: LucideIcons.helpCircle,
      text:
          'Not sure which to use?\nSend with XLM (fast, tiny fees). Store value in USDC (stable ~1:1 USD).',
      tags: {'info', 'beginner', 'xlm', 'usdc'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'hold_split',
      icon: LucideIcons.layoutGrid,
      text:
          'A simple approach many use:\nKeep most funds in USDC, and hold a small amount of XLM for fees and quick payments.',
      tags: {'tip', 'xlm', 'usdc', 'beginner'},
    ),
  ),

  // â”€â”€ Swaps & payments â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'swap_keep_xlm',
      icon: LucideIcons.arrowLeftRight,
      text:
          'Swapping assets?\nKeep a small XLM amount to cover swap and network fees at every step.',
      tags: {'swap', 'xlm', 'fees', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'swap_slippage',
      icon: LucideIcons.activity,
      text:
          'Large swaps can â€œslipâ€ if the market moves or thereâ€™s low liquidity.\nDoing it in smaller steps may get you a better overall rate.',
      tags: {'swap', 'price', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'payment_memo',
      icon: LucideIcons.stickyNote,
      text:
          'Sending to an exchange or business?\nSome require a Memo/Tag to credit your accountâ€”check before sending.',
      tags: {'transfer', 'memo', 'warning'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'send_small_first',
      icon: LucideIcons.send,
      text:
          'New address or service?\nTry a small test transaction first, then send the full amount once it arrives.',
      tags: {'transfer', 'security', 'tip', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'qr_over_typing',
      icon: LucideIcons.scanLine,
      text:
          'Use QR scan or copy-paste instead of typing long addresses.\nItâ€™s fasterâ€”and helps avoid costly typos.',
      tags: {'transfer', 'ux', 'tip', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'irreversible',
      icon: LucideIcons.alertTriangle,
      text:
          'Crypto transfers are final once sent.\nReview the address, amount, and network carefully before you confirm.',
      tags: {'transfer', 'warning'},
    ),
  ),

  // â”€â”€ Safety & security â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'sec_secret',
      icon: LucideIcons.lock,
      text:
          'Never share your secret phrase with anyoneâ€”support will never ask for it.\nWrite it down and keep it offline in a safe place.',
      tags: {'security', 'warning', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'sec_verify',
      icon: LucideIcons.shieldCheck,
      text:
          'Always double-check addresses and links (especially in DMs).\nWhen unsure, verify with the official website or a known contact.',
      tags: {'security', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'sec_scams',
      icon: LucideIcons.alertOctagon,
      text:
          'Be cautious of â€œairdropâ€ messages or offers that feel too good to be true.\nIf it sounds magical, itâ€™s almost always a scam.',
      tags: {'security', 'warning'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'sec_pin_bio',
      icon: LucideIcons.fingerprint,
      text:
          'Protect your wallet with a strong PIN or biometrics on this device.\nLock your phone and keep your apps updated.',
      tags: {'security', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'backup_phrase',
      icon: LucideIcons.server,
      text:
          'Back up your secret phrase on paper or a metal backup.\nAvoid screenshotsâ€”they can be discovered by malware or cloud sync.',
      tags: {'security', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'share_address_safely',
      icon: LucideIcons.share,
      text:
          'Itâ€™s okay to share your public address when someone needs to pay you.\nJust never share your secret phrase or private keys.',
      tags: {'security', 'info', 'beginner'},
    ),
  ),

  // â”€â”€ Practical nudges (conditional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'low_xlm',
      icon: LucideIcons.alertTriangle,
      text:
          'Your XLM looks lowâ€”top up a little so transactions keep working.\nWithout XLM, certain actions like swaps and trustlines may fail.',
      tags: {'xlm', 'fees', 'warning'},
    ),
    when: (ctx) => (ctx.xlmBalance ?? double.infinity) < ctx.lowXlmThreshold,
  ),
  TipBlueprint(
    GuideTip(
      id: 'use_usdc_for_value',
      icon: LucideIcons.circleDollarSign,
      text:
          'Holding value for a while?\nKeep most in USDC, and keep some XLM aside for network fees and quick sends.',
      tags: {'usdc', 'xlm', 'tip'},
    ),
    when: (ctx) => (ctx.usdcBalance ?? 0) < (ctx.xlmBalance ?? 0),
  ),
  TipBlueprint(
    GuideTip(
      id: 'swap_tiny_for_fees',
      icon: LucideIcons.arrowUpDown,
      text:
          'Out of XLM but have USDC?\nSwap a tiny amount into XLM to cover the fees for your next actions.',
      tags: {'swap', 'fees', 'tip'},
    ),
    when: (ctx) =>
        (ctx.xlmBalance ?? 0) < ctx.lowXlmThreshold &&
        (ctx.usdcBalance ?? 0) > 0,
  ),

  // â”€â”€ Network / environment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'testnet_note',
      icon: LucideIcons.testTube,
      text:
          'Youâ€™re on Testnetâ€”a practice network for learning and testing.\nTokens here have no real-world value.',
      tags: {'env', 'info', 'beginner'},
    ),
    when: (ctx) => ctx.isTestnet == true,
  ),

  // â”€â”€ On/Off-ramp & cash-out awareness (generic) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'onramp_compare',
      icon: LucideIcons.creditCard,
      text:
          'Buying with cash/card? Compare on-ramp fees and limits.\nSmall differences add upâ€”choose what fits your budget and speed.',
      tags: {'ramp', 'fees', 'tip'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'cashout_fees_timing',
      icon: LucideIcons.wallet,
      text:
          'Planning a cash-out later?\nCheck fees, processing times, and cut-off hours so your funds arrive when needed.',
      tags: {'ramp', 'fees', 'tip'},
    ),
  ),

  // â”€â”€ General money hygiene â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TipBlueprint(
    GuideTip(
      id: 'fees_are_tiny',
      icon: LucideIcons.badgeInfo,
      text:
          'Stellar fees are tiny, but you still need a bit of XLM to make things happen.\nThink of it like a small prepaid load for the network.',
      tags: {'xlm', 'fees', 'info', 'beginner'},
    ),
  ),
  TipBlueprint(
    GuideTip(
      id: 'keep_app_updated',
      icon: LucideIcons.refreshCw,
      text:
          'Keep your app up to date.\nUpdates include bug fixes, performance improvements, and safety patches.',
      tags: {'ux', 'security', 'tip'},
    ),
  ),
];

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Widget
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AssetGuideFooterState extends State<AssetGuideFooter> {
  late final math.Random _rng = widget.rngSeed == null
      ? math.Random()
      : math.Random(widget.rngSeed);
  final AnnouncementsService _announcementsService = AnnouncementsService();

  List<GuideTip> _tips = const [];
  List<GuideTip> _announcementTips = const [];
  int _index = 0;

  Timer? _timer;
  bool _paused = false; // pause on long-press

  @override
  void initState() {
    super.initState();
    _assembleTips();
    _loadAnnouncementTips();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AssetGuideFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final balancesChanged =
        oldWidget.xlmBalance != widget.xlmBalance ||
        oldWidget.usdcBalance != widget.usdcBalance;
    final envChanged = oldWidget.isTestnet != widget.isTestnet;
    final filtersChanged =
        oldWidget.includeTags != widget.includeTags ||
        oldWidget.excludeTags != widget.excludeTags;
    final extrasChanged = oldWidget.extraTips != widget.extraTips;

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
    _announcementsService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(widget.randomizeEvery, (_) {
      if (!mounted || _tips.isEmpty || _paused) return;
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
      hasUsdcTrustline: widget.hasUsdcTrustline,
      isTestnet: widget.isTestnet,
      lowXlmThreshold: widget.lowXlmThreshold,
    );

    final List<GuideTip> built = _announcementTips.isNotEmpty
        ? _announcementTips.where(_passesTagFilters).toList()
        : _catalogTipsFor(ctx);

    // Add extras and dedupe by id
    final seen = <String>{};
    final dedup = <GuideTip>[];
    for (final t in [...built, ...widget.extraTips]) {
      if (seen.add(t.id)) dedup.add(t);
    }

    if (!mounted) return;
    setState(() {
      _tips = dedup;
      if (_tips.isEmpty) {
        _index = 0;
      } else {
        _index = _index.clamp(0, _tips.length - 1);
      }
    });
  }

  Future<void> _loadAnnouncementTips() async {
    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;
      final announcements = await _announcementsService.getActiveForCurrentUser(
        appVersion: appVersion,
      );
      final mapped = announcements
          .map(_tipFromAnnouncement)
          .whereType<GuideTip>()
          .toList(growable: false);
      if (!mounted) return;
      _announcementTips = mapped;
      _assembleTips();
    } catch (_) {
      if (!mounted) return;
      _announcementTips = const [];
      _assembleTips();
    }
  }

  List<GuideTip> _catalogTipsFor(TipContext ctx) {
    final built = <GuideTip>[];
    for (final bp in _tipCatalog) {
      if (bp.when == null || bp.when!(ctx)) {
        if (_passesTagFilters(bp.tip)) {
          built.add(bp.tip);
        }
      }
    }
    return built;
  }

  bool _passesTagFilters(GuideTip tip) {
    if (widget.includeTags.isNotEmpty &&
        tip.tags.intersection(widget.includeTags).isEmpty) {
      return false;
    }
    if (tip.tags.intersection(widget.excludeTags).isNotEmpty) {
      return false;
    }
    return true;
  }

  GuideTip? _tipFromAnnouncement(AnnouncementItem item) {
    final title = item.title.trim();
    final message = item.message.trim();
    final text = _composeAnnouncementText(title: title, message: message);
    if (text.isEmpty) return null;

    return GuideTip(
      id: 'announcement_${item.displayKey}',
      icon: _iconForAnnouncement(item),
      text: text,
      tags: _tagsForAnnouncement(item, text),
    );
  }

  String _composeAnnouncementText({
    required String title,
    required String message,
  }) {
    final safeTitle = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final safeMessage = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (safeTitle.isEmpty) return safeMessage;
    if (safeMessage.isEmpty) return safeTitle;
    if (safeMessage.toLowerCase().startsWith(safeTitle.toLowerCase())) {
      return safeMessage;
    }
    return '$safeTitle\n$safeMessage';
  }

  IconData _iconForAnnouncement(AnnouncementItem item) {
    switch (item.type) {
      case AnnouncementType.maintenance:
        return Icons.build_rounded;
      case AnnouncementType.update:
        return Icons.system_update_alt_rounded;
      case AnnouncementType.announcement:
        return Icons.campaign_rounded;
    }
  }

  Set<String> _tagsForAnnouncement(AnnouncementItem item, String text) {
    final normalized = text.toLowerCase();
    final tags = <String>{
      switch (item.type) {
        AnnouncementType.maintenance => 'warning',
        AnnouncementType.update => 'info',
        AnnouncementType.announcement => 'tip',
      },
      'announcement',
    };

    if (normalized.contains('xlm') || normalized.contains('stellar')) {
      tags.add('xlm');
    }
    if (normalized.contains('usdc')) {
      tags.add('usdc');
    }
    if (normalized.contains('secure') ||
        normalized.contains('security') ||
        normalized.contains('scam') ||
        normalized.contains('phishing')) {
      tags.add('security');
    }
    if (normalized.contains('required') ||
        normalized.contains('important') ||
        normalized.contains('urgent')) {
      tags.add('warning');
    }
    if (item.actionUrl != null && item.actionUrl!.trim().isNotEmpty) {
      tags.add('action');
    }
    return tags;
  }

  // Accent color heuristic by tags
  Color _accentFor(GuideTip tip) {
    final tags = tip.tags;
    final colors = widget.colors;
    if (tags.contains('warning') || tags.contains('security')) {
      return colors.warning;
    }
    if (tags.contains('success')) return colors.success;
    if (tags.contains('usdc')) return colors.info;
    if (tags.contains('xlm')) return colors.primaryDark;
    return colors.textSecondary;
  }

  LinearGradient _bg(Color base) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [base.withValues(alpha: 0.10), base.withValues(alpha: 0.04)],
  );

  @override
  Widget build(BuildContext context) {
    if (_tips.isEmpty) return const SizedBox.shrink();

    final tip = _tips[_index];
    final base = _accentFor(tip);
    final c = widget.colors;

    final dense = widget.dense;
    final pad =
        widget.padding ??
        (dense
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
    final iconBubble = dense ? 22.0 : 26.0;
    final glyph = dense ? 13.0 : 16.0;
    final gap = dense ? 8.0 : 10.0;

    return GestureDetector(
      onTap: _pickRandomNow, // quick rotate on tap
      onLongPress: () => setState(() => _paused = !_paused), // pause/resume
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: _bg(base),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        padding: pad,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: iconBubble,
              height: iconBubble,
              margin: EdgeInsets.only(right: gap),
              decoration: BoxDecoration(
                color: base.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tip.icon,
                size: glyph,
                color: base.withValues(alpha: 0.95),
              ),
            ),
            // Text (wraps up to maxLines)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
                layoutBuilder: (currentChild, previousChildren) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _TipText(
                  key: ValueKey(tip.id),
                  text: tip.text,
                  color: c.textPrimary,
                  dense: dense,
                  maxLines: widget.allowTwoLines
                      ? widget.maxLines.clamp(1, 4)
                      : 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Text thatâ€™s slim; wraps up to [maxLines] with gentle line height.
class _TipText extends StatelessWidget {
  const _TipText({
    super.key,
    required this.text,
    required this.color,
    required this.dense,
    required this.maxLines,
  });

  final String text;
  final Color color;
  final bool dense;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final baseSize = dense ? 13.0 : 13.5;
    final weight = FontWeight.w400;

    return Text(
      text,
      textAlign: TextAlign.start,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: baseSize,
        fontWeight: weight,
        color: color,
        height: 1.15,
        letterSpacing: 0.1,
      ),
    );
  }
}


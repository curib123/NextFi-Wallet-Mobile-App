import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/profile_setup_modal.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/features/verification_flow/view/verification_flow_screen.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_tier_progress_models.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract class _T {
  static const heroName = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w900,
    letterSpacing: -1.0, height: 1.05,
  );
  static const heroHandle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600,
    letterSpacing: 0.1, height: 1.3,
  );
  static const heroEmail = TextStyle(
    fontSize: 11.5, fontWeight: FontWeight.w400,
    letterSpacing: 0, height: 1.3,
  );
  static const sectionLabel = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w700,
    letterSpacing: 1.3, height: 1.0,
  );
  static const statDisplay = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w900,
    letterSpacing: -1.1, height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const statUnit = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700,
    letterSpacing: -0.2, height: 1.0,
  );
  static const statLabel = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w500,
    letterSpacing: 0, height: 1.3,
  );
  static const rowKey = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w500,
    letterSpacing: 0.1, height: 1.2,
  );
  static const rowVal = TextStyle(
    fontSize: 13.5, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, height: 1.2,
  );
  static const tierDisplay = TextStyle(
    fontSize: 30, fontWeight: FontWeight.w900,
    letterSpacing: -1.3, height: 1.0,
  );
  static const tierSub = TextStyle(
    fontSize: 11.5, fontWeight: FontWeight.w500,
    letterSpacing: 0, height: 1.3,
  );
  static const pill = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w700,
    letterSpacing: 0.2, height: 1.0,
  );
  static const btn = TextStyle(
    fontSize: 13.5, fontWeight: FontWeight.w700,
    letterSpacing: -0.2, height: 1.0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER META
// ─────────────────────────────────────────────────────────────────────────────

class _TierMeta {
  static Color color(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => const Color(0xFFCD7F32),
    MerchantTier.silver   => const Color(0xFF9CA3AF),
    MerchantTier.gold     => const Color(0xFFF59E0B),
    MerchantTier.platinum => const Color(0xFF22D3EE),
    MerchantTier.diamond  => const Color(0xFF818CF8),
  };

  static List<Color> gradient(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => [const Color(0xFFCD7F32), const Color(0xFF7C2D12)],
    MerchantTier.silver   => [const Color(0xFFD1D5DB), const Color(0xFF4B5563)],
    MerchantTier.gold     => [const Color(0xFFFBBF24), const Color(0xFFB45309)],
    MerchantTier.platinum => [const Color(0xFF67E8F9), const Color(0xFF0E7490)],
    MerchantTier.diamond  => [const Color(0xFFA5B4FC), const Color(0xFF4338CA)],
  };

  static IconData icon(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => Icons.shield_outlined,
    MerchantTier.silver   => Icons.workspace_premium_outlined,
    MerchantTier.gold     => Icons.emoji_events_outlined,
    MerchantTier.platinum => Icons.military_tech_outlined,
    MerchantTier.diamond  => Icons.diamond_outlined,
  };

  static String label(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => 'Bronze',
    MerchantTier.silver   => 'Silver',
    MerchantTier.gold     => 'Gold',
    MerchantTier.platinum => 'Platinum',
    MerchantTier.diamond  => 'Diamond',
  };

  static String tagline(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => 'Getting started',
    MerchantTier.silver   => 'Building trust',
    MerchantTier.gold     => 'Top performer',
    MerchantTier.platinum => 'Elite merchant',
    MerchantTier.diamond  => 'Highest tier',
  };

  static int stars(MerchantTier t) => switch (t) {
    MerchantTier.bronze   => 1,
    MerchantTier.silver   => 2,
    MerchantTier.gold     => 3,
    MerchantTier.platinum => 4,
    MerchantTier.diamond  => 5,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _auth           = AuthService();
  final _profileSvc     = ProfileCoreService.I;
  final _verificationSvc = VerificationCoreService.I;
  final _merchantSvc    = MerchantProfileCoreService.I;
  final _dateFmt        = DateFormat('MMM d, yyyy · HH:mm');

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  StreamSubscription<void>? _profileSub;

  bool                       _loading = true;
  String?                    _error;
  User?                      _user;
  ProfileModel?              _profileData;
  VerificationModel?         _verificationData;
  MerchantProfileModel?      _merchantData;
  MerchantTierProgressModel? _tierProgress;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _fade  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _profileSub = ProfileCoreService.changes.listen((_) { if (mounted) _load(); });
    _load();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<T?> _safe<T>(Future<T> Function() fn) async {
    try { return await fn(); } catch (_) { return null; }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final auth = await _auth.isAuthenticated;
      if (!auth) {
        if (!mounted) return;
        setState(() {
          _user = null; _profileData = null; _verificationData = null;
          _merchantData = null; _tierProgress = null; _loading = false;
        });
        _fadeCtrl.forward(from: 0);
        _slideCtrl.forward(from: 0);
        return;
      }
      final results = await Future.wait([
        _safe<User>(() => _auth.currentUser),
        _safe<ProfileModel?>(() => _profileSvc.getMe()),
        _safe<VerificationModel>(() => _verificationSvc.getMe()),
        _safe<MerchantProfileModel?>(() => _merchantSvc.getMe()),
      ]);
      final merchant = results[3] as MerchantProfileModel?;
      final tier = merchant?.isApproved == true
          ? await _safe<MerchantTierProgressModel?>(() => _merchantSvc.getTierProgress())
          : null;
      if (!mounted) return;
      setState(() {
        _user             = results[0] as User?;
        _profileData      = results[1] as ProfileModel?;
        _verificationData = results[2] as VerificationModel?;
        _merchantData     = merchant;
        _tierProgress     = tier;
        _loading          = false;
      });
      _fadeCtrl.forward(from: 0);
      _slideCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openVerification() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VerificationFlowScreen()));
    if (mounted) await _load();
  }

  Future<void> _editProfile() async {
    final changed = await showProfileSetupModal(context, initial: _profileData);
    if (changed == true && mounted) _fadeCtrl.forward(from: 0);
  }

  String _displayName() {
    final p = _profileData; final u = _user;
    if (p?.displayName?.trim().isNotEmpty == true) return p!.displayName!.trim();
    if (u?.name.trim().isNotEmpty == true) return u!.name.trim();
    if (u?.email.trim().isNotEmpty == true) return u!.email.trim();
    return 'Profile';
  }

  String _val(String? v) { final t = v?.trim() ?? ''; return t.isEmpty ? '—' : t; }
  String _valDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d.toLocal());

  bool get _isMerchant => _merchantData?.isApproved == true;

  ({String label, Color color, IconData icon}) _trustUi(AppColor c) {
    final s = _verificationData?.status ??
        ((_profileData?.isVerificationIdentityComplete ?? false)
            ? TrustStatus.ready : TrustStatus.basic);
    return switch (s) {
      TrustStatus.ready     => (label: 'Verified',  color: c.success,       icon: Icons.verified_rounded),
      TrustStatus.reviewing => (label: 'In Review', color: c.warning,       icon: Icons.hourglass_top_rounded),
      TrustStatus.suspended => (label: 'Suspended', color: c.error,         icon: Icons.block_rounded),
      TrustStatus.basic     => (label: 'Basic',     color: c.textSecondary, icon: Icons.shield_outlined),
      _                     => (label: 'Unknown',   color: c.textSecondary, icon: Icons.help_outline_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c  = AppColor.of(context);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: c.background,
      extendBodyBehindAppBar: true,
      appBar: _PAppBar(c: c, onRefresh: _load),
      body: _loading
          ? const PageLoader(label: 'Loading profile...')
          : _error != null
          ? _EmptyState.error(message: _error!, onAction: _load)
          : _user == null
          ? _EmptyState.loggedOut(onAction: _load)
          : FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.primary,
            backgroundColor: c.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.top + kToolbarHeight),
                ),

                // Hero
                SliverToBoxAdapter(
                  child: _HeroCard(
                    user: _user!,
                    profile: _profileData,
                    displayName: _displayName(),
                    tierProgress: _tierProgress,
                    trustUi: _trustUi(c),
                    onEdit: _editProfile,
                  ),
                ),

                // Stats (merchant)
                if (_isMerchant && _tierProgress != null) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _StatStrip(data: _tierProgress!)),
                ],

                // Account
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(
                  child: _SectionLabel(label: 'ACCOUNT', icon: LucideIcons.user, c: c),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: _InfoCard(rows: [
                    _Row(LucideIcons.mail,         'Email',        _val(_user!.email)),
                    _Row(LucideIcons.atSign,       'Username',     _val(_profileData?.username)),
                    _Row(LucideIcons.tag,          'Display Name', _val(_profileData?.displayName)),
                    _Row(LucideIcons.globe2,       'Country',      _val(_profileData?.country)),
                    _Row(LucideIcons.calendarDays, 'Member Since', _valDate(_profileData?.createdAt)),
                    _Row(LucideIcons.refreshCw,    'Last Updated', _valDate(_profileData?.updatedAt), isLast: true),
                  ]),
                ),

                // Verification
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(
                  child: _SectionLabel(label: 'VERIFICATION', icon: LucideIcons.shieldCheck, c: c),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: _VerificationCard(
                    ui: _trustUi(c),
                    verification: _verificationData,
                    onOpen: _openVerification,
                  ),
                ),

                // Merchant tier
                if (_isMerchant && _tierProgress != null) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  SliverToBoxAdapter(
                    child: _SectionLabel(label: 'MERCHANT TIER', icon: LucideIcons.trophy, c: c),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(child: _TierCard(data: _tierProgress!)),
                ],

                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.bottom + 52),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// APP BAR
// ═════════════════════════════════════════════════════════════════════════════

class _PAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PAppBar({required this.c, required this.onRefresh});
  final AppColor c;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: c.background.withValues(alpha: 0.94),
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleSpacing: 20,
    title: Text('Profile', style: TextStyle(
      color: c.textPrimary, fontSize: 18,
      fontWeight: FontWeight.w900, letterSpacing: -0.6,
    )),
    actions: [
      GestureDetector(
        onTap: onRefresh,
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.border),
          ),
          child: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 16),
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// HERO CARD
// ═════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.user,
    required this.profile,
    required this.displayName,
    required this.tierProgress,
    required this.trustUi,
    required this.onEdit,
  });

  final User                               user;
  final ProfileModel?                      profile;
  final String                             displayName;
  final MerchantTierProgressModel?         tierProgress;
  final ({String label, Color color, IconData icon}) trustUi;
  final VoidCallback                       onEdit;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 300),
            () { if (mounted) _ringCtrl.forward(); });
  }

  @override
  void dispose() { _ringCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c      = AppColor.of(context);
    final tier   = widget.tierProgress?.currentTier;
    final accent = tier != null ? _TierMeta.color(tier) : c.primary;
    final grad   = tier != null ? _TierMeta.gradient(tier) : [c.primary, c.primary];
    final handle = widget.profile?.username?.trim().isNotEmpty == true
        ? '@${widget.profile!.username!.trim()}' : null;
    final email  = widget.user.email.trim();
    final country = widget.profile?.country?.trim();
    final ringProgress = widget.tierProgress != null
        ? (widget.tierProgress!.nextTier != null
        ? (widget.tierProgress!.nextTier!.progress.overallPercent.clamp(0.0, 100.0) / 100.0)
        : 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: 0.20), width: 1.5),
              boxShadow: [BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 24, offset: const Offset(0, 8),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(
                children: [
                  // Gradient wash
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            grad[0].withValues(alpha: 0.13),
                            grad[1].withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top color strip
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad),
                      ),
                    ),
                  ),
                  // Decorative radial bloom
                  Positioned(
                    top: -70, right: -70,
                    child: Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          accent.withValues(alpha: 0.10),
                          accent.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar + animated ring
                            AnimatedBuilder(
                              animation: _ringAnim,
                              builder: (_, __) => _Avatar(
                                user: widget.user,
                                gradient: grad,
                                accent: accent,
                                progress: ringProgress != null
                                    ? _ringAnim.value * ringProgress : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.displayName,
                                      style: _T.heroName.copyWith(color: c.textPrimary),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if (handle != null) ...[
                                    const SizedBox(height: 3),
                                    Text(handle,
                                        style: _T.heroHandle.copyWith(color: accent)),
                                  ],
                                  const SizedBox(height: 2),
                                  if (email.isNotEmpty)
                                    Text(email,
                                        style: _T.heroEmail.copyWith(color: c.textSecondary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: accent.withValues(alpha: 0.10)),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            _TrustPill(ui: widget.trustUi, c: c),
                            if (tier != null) _TierPill(tier: tier),
                            if (country != null && country.isNotEmpty)
                              _CountryPill(country: country, c: c),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Edit button
          _TapTarget(
            onTap: widget.onEdit,
            child: Container(
              width: double.infinity, height: 46,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.edit_outlined, size: 14, color: c.textSecondary),
                const SizedBox(width: 7),
                Text('Edit Profile', style: _T.btn.copyWith(color: c.textPrimary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.gradient,
    required this.accent,
    this.progress,
  });
  final User          user;
  final List<Color>   gradient;
  final Color         accent;
  final double?       progress;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return SizedBox(
      width: 74, height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            CustomPaint(
              size: const Size(74, 74),
              painter: _RingPainter(
                progress: progress!,
                color: accent,
                trackColor: accent.withValues(alpha: 0.14),
                strokeWidth: 3.0,
              ),
            ),
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: [BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 14, offset: const Offset(0, 4),
              )],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface),
              padding: const EdgeInsets.all(2),
              child: ClipOval(child: UserAvatarLarge(user: user, colors: c)),
            ),
          ),
          Positioned(
            bottom: 5, right: 5,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.success,
                border: Border.all(color: c.surface, width: 2),
                boxShadow: [BoxShadow(color: c.success.withValues(alpha: 0.4), blurRadius: 5)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });
  final double progress;
  final Color  color;
  final Color  trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = cx - strokeWidth / 2;
    const s  = -math.pi / 2;
    final basePaint = Paint()
      ..strokeWidth = strokeWidth
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        s, math.pi * 2, false, basePaint..color = trackColor);
    if (progress > 0.01) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          s, math.pi * 2 * progress, false, basePaint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.color != color;
}

// ── Chip variants ─────────────────────────────────────────────────────────────

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.ui, required this.c});
  final ({String label, Color color, IconData icon}) ui;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: ui.color, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ui.icon, size: 10, color: c.onPrimary),
      const SizedBox(width: 4),
      Text(ui.label, style: _T.pill.copyWith(color: c.onPrimary)),
    ]),
  );
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.tier});
  final MerchantTier tier;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: _TierMeta.gradient(tier)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_TierMeta.icon(tier), size: 10, color: Colors.white),
      const SizedBox(width: 4),
      Text(_TierMeta.label(tier), style: _T.pill.copyWith(color: Colors.white)),
    ]),
  );
}

class _CountryPill extends StatelessWidget {
  const _CountryPill({required this.country, required this.c});
  final String   country;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.mapPin, size: 9, color: c.textSecondary),
      const SizedBox(width: 4),
      Text(country, style: _T.pill.copyWith(color: c.textSecondary)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// STAT STRIP
// ═════════════════════════════════════════════════════════════════════════════

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.data});
  final MerchantTierProgressModel data;

  @override
  Widget build(BuildContext context) {
    final c   = AppColor.of(context);
    final pct = data.nextTier?.progress.overallPercent ?? 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Expanded(child: _BigStat(
          icon: Icons.trending_up_rounded, iconColor: c.success,
          value: data.metrics.avgOfferSuccessRate.toStringAsFixed(1),
          unit: '%', label: 'Success',
        )),
        const SizedBox(width: 8),
        Expanded(child: _BigStat(
          icon: Icons.star_rounded, iconColor: c.warning,
          value: data.metrics.avgReviewRating.toStringAsFixed(2),
          unit: '', label: 'Rating',
        )),
        const SizedBox(width: 8),
        Expanded(child: _BigStat(
          icon: Icons.keyboard_double_arrow_up_rounded, iconColor: c.primary,
          value: pct.toStringAsFixed(0), unit: '%',
          label: data.nextTier == null ? 'Top Tier' : 'To ${_TierMeta.label(data.nextTier!.tier)}',
        )),
      ]),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
  });
  final IconData icon;
  final Color    iconColor;
  final String   value;
  final String   unit;
  final String   label;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(value,
                  style: _T.statDisplay.copyWith(color: c.textPrimary),
                  maxLines: 1, overflow: TextOverflow.clip)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 1),
                Text(unit, style: _T.statUnit.copyWith(color: c.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: _T.statLabel.copyWith(color: c.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION LABEL
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon, required this.c});
  final String   label;
  final IconData icon;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      Icon(icon, size: 11, color: c.textSecondary.withValues(alpha: 0.5)),
      const SizedBox(width: 6),
      Text(label, style: _T.sectionLabel
          .copyWith(color: c.textSecondary.withValues(alpha: 0.6))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// INFO CARD
// ═════════════════════════════════════════════════════════════════════════════

class _Row {
  const _Row(this.icon, this.key, this.value, {this.isLast = false});
  final IconData icon;
  final String   key;
  final String   value;
  final bool     isLast;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(children: rows.map((r) => _InfoRow(row: r)).toList()),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final c       = AppColor.of(context);
    final isEmpty = row.value == '—';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: c.background, borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(row.icon, size: 14, color: c.textSecondary),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.key, style: _T.rowKey.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 3),
                  Text(row.value, style: _T.rowVal.copyWith(
                    color: isEmpty ? c.textSecondary : c.textPrimary,
                  )),
                ],
              )),
            ],
          ),
        ),
        if (!row.isLast)
          Divider(height: 1, indent: 59, endIndent: 14,
              color: c.border.withValues(alpha: 0.6)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VERIFICATION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.ui,
    required this.verification,
    required this.onOpen,
  });
  final ({String label, Color color, IconData icon}) ui;
  final VerificationModel? verification;
  final VoidCallback        onOpen;

  @override
  Widget build(BuildContext context) {
    final c  = AppColor.of(context);
    final sc = ui.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                border: Border(bottom: BorderSide(color: sc.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(ui.icon, size: 17, color: sc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Status',
                            style: _T.rowKey.copyWith(color: c.textSecondary)),
                        const SizedBox(height: 2),
                        Text(ui.label, style: TextStyle(
                          color: sc, fontSize: 16,
                          fontWeight: FontWeight.w900, letterSpacing: -0.4,
                        )),
                      ],
                    ),
                  ),
                  // Glowing status dot
                  Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      color: sc, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: sc.withValues(alpha: 0.5), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
            _InfoRow(row: _Row(
              LucideIcons.phone, 'Phone Number',
              verification?.phoneNumber?.trim().isNotEmpty == true
                  ? verification!.phoneNumber! : 'Not submitted',
            )),
            Divider(height: 1, indent: 59, endIndent: 14,
                color: c.border.withValues(alpha: 0.6)),
            _InfoRow(row: _Row(
              LucideIcons.calendar, 'Submitted At',
              verification?.submittedAt == null
                  ? 'Not submitted'
                  : DateFormat('MMM d, yyyy · HH:mm')
                  .format(verification!.submittedAt!.toLocal()),
              isLast: true,
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: _PrimaryBtn(
                icon: Icons.verified_user_outlined,
                label: 'Open Verification',
                onTap: onOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TIER CARD
// ═════════════════════════════════════════════════════════════════════════════

class _TierCard extends StatefulWidget {
  const _TierCard({required this.data});
  final MerchantTierProgressModel data;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;
  late final Animation<double>   _barAnim;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 250),
            () { if (mounted) _barCtrl.forward(); });
  }

  @override
  void dispose() { _barCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c      = AppColor.of(context);
    final data   = widget.data;
    final tier   = data.currentTier;
    final next   = data.nextTier;
    final pct    = (next?.progress.overallPercent ?? 100.0).clamp(0.0, 100.0);
    final tc     = _TierMeta.color(tier);
    final tg     = _TierMeta.gradient(tier);
    final nc     = next != null ? _TierMeta.color(next.tier) : tc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tc.withValues(alpha: 0.22), width: 1.5),
          boxShadow: [BoxShadow(
            color: tc.withValues(alpha: 0.10),
            blurRadius: 20, offset: const Offset(0, 6),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Gradient wash
              Positioned(
                top: 0, left: 0, right: 0, height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [tg[0].withValues(alpha: 0.12), tg[1].withValues(alpha: 0.04)],
                    ),
                  ),
                ),
              ),
              // Top strip
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: tg)),
                ),
              ),
              // Decorative bloom
              Positioned(
                top: -60, right: -60,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      tc.withValues(alpha: 0.12),
                      tc.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning
                    if (!data.minimumData.met) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: c.warning.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.warning.withValues(alpha: 0.28)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded, size: 13, color: c.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'At least 1 offer and 1 review needed to rank above Bronze.',
                            style: TextStyle(
                              color: c.warning, fontSize: 12,
                              fontWeight: FontWeight.w600, height: 1.4,
                            ),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Identity row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: tg,
                            ),
                            boxShadow: [BoxShadow(
                              color: tc.withValues(alpha: 0.38),
                              blurRadius: 14, offset: const Offset(0, 4),
                            )],
                          ),
                          child: Icon(_TierMeta.icon(tier), color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Merchant',
                                style: _T.tierSub.copyWith(color: c.textSecondary)),
                            Text(_TierMeta.label(tier),
                                style: _T.tierDisplay.copyWith(color: tc)),
                            Text(_TierMeta.tagline(tier),
                                style: _T.tierSub.copyWith(color: c.textSecondary)),
                          ],
                        )),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_TierMeta.stars(tier), (i) =>
                              Padding(padding: const EdgeInsets.only(left: 2),
                                  child: Icon(Icons.star_rounded, size: 12, color: tc))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: tc.withValues(alpha: 0.12)),
                    const SizedBox(height: 14),

                    // Progress
                    if (next != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress to ${_TierMeta.label(next.tier)}',
                              style: _T.rowKey.copyWith(color: c.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: nc.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
                              color: nc, fontSize: 12,
                              fontWeight: FontWeight.w900, letterSpacing: -0.3,
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _barAnim,
                        builder: (_, __) => _ProgressBar(
                          progress: _barAnim.value * pct / 100,
                          fromColor: tc, toColor: nc,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TierPip(label: _TierMeta.label(tier), color: tc, isCurrent: true),
                          Icon(Icons.arrow_forward_rounded, size: 11, color: c.textSecondary),
                          _TierPip(label: _TierMeta.label(next.tier), color: nc, isCurrent: false),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tc.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tc.withValues(alpha: 0.14)),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.target, size: 13, color: tc),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Need +${next.progress.remainingSuccessRate.toStringAsFixed(1)}% success'
                                ' · +${next.progress.remainingAvgRating.toStringAsFixed(2)} rating',
                            style: _T.rowKey.copyWith(color: c.textSecondary, height: 1.4),
                          )),
                        ]),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tc.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: tc.withValues(alpha: 0.20)),
                        ),
                        child: Row(children: [
                          Icon(Icons.workspace_premium_rounded, size: 18, color: tc),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            "Maximum tier achieved — you're at the top.",
                            style: TextStyle(color: tc, fontSize: 13,
                                fontWeight: FontWeight.w700, height: 1.35),
                          )),
                          const Text('🏆', style: TextStyle(fontSize: 18)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _MetricChip(
                        icon: Icons.trending_up_rounded, label: 'Success',
                        value: '${data.metrics.avgOfferSuccessRate.toStringAsFixed(1)}%',
                        color: tc,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _MetricChip(
                        icon: Icons.star_rounded, label: 'Rating',
                        value: data.metrics.avgReviewRating.toStringAsFixed(2),
                        color: tc,
                      )),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.fromColor, required this.toColor});
  final double progress;
  final Color  fromColor;
  final Color  toColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
    final w = box.maxWidth;
    return Stack(clipBehavior: Clip.none, children: [
      Container(height: 7,
          decoration: BoxDecoration(
            color: fromColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          )),
      Container(
        width: (w * progress).clamp(7.0, w), height: 7,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [fromColor, toColor]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [BoxShadow(
            color: toColor.withValues(alpha: 0.38),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
      ),
      if (progress > 0.04 && progress < 0.96)
        Positioned(
          left: (w * progress).clamp(3.5, w - 7) - 3.5, top: -2.5,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: toColor, width: 2),
              boxShadow: [BoxShadow(color: toColor.withValues(alpha: 0.35), blurRadius: 5)],
            ),
          ),
        ),
    ]);
  });
}

// ─── Tier pip ─────────────────────────────────────────────────────────────────

class _TierPip extends StatelessWidget {
  const _TierPip({required this.label, required this.color, required this.isCurrent});
  final String label;
  final Color  color;
  final bool   isCurrent;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 6, height: 6,
          decoration: BoxDecoration(
            color: isCurrent ? color : color.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          )),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        color: isCurrent ? color : color.withValues(alpha: 0.65),
        fontSize: 10.5, fontWeight: FontWeight.w700,
      )),
    ],
  );
}

// ─── Metric chip ──────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 15,
              fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.0,
            )),
            Text(label, style: _T.statLabel.copyWith(color: c.textSecondary)),
          ],
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAP WRAPPER
// ═════════════════════════════════════════════════════════════════════════════

class _TapTarget extends StatefulWidget {
  const _TapTarget({required this.child, required this.onTap});
  final Widget       child;
  final VoidCallback onTap;

  @override
  State<_TapTarget> createState() => _TapTargetState();
}

class _TapTargetState extends State<_TapTarget> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
    onTapDown:   (_) => setState(() => _down = true),
    onTapUp:     (_) => setState(() => _down = false),
    onTapCancel: ()  => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? 0.976 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: widget.child,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return _TapTarget(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 50,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: c.primary.withValues(alpha: 0.26),
            blurRadius: 14, offset: const Offset(0, 4),
          )],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: c.onPrimary),
          const SizedBox(width: 8),
          Text(label, style: _T.btn.copyWith(color: c.onPrimary)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY / ERROR STATES
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState._({
    required this.stateIcon,
    required this.title,
    required this.body,
    required this.btnLabel,
    required this.filled,
    required this.onAction,
  });

  factory _EmptyState.error({required String message, required VoidCallback onAction}) =>
      _EmptyState._(
        stateIcon: const _StateIcon(icon: Icons.cloud_off_rounded, isError: true),
        title: 'Failed to load', body: message,
        btnLabel: 'Try Again', filled: true, onAction: onAction,
      );

  factory _EmptyState.loggedOut({required VoidCallback onAction}) =>
      _EmptyState._(
        stateIcon: const _StateIcon(icon: Icons.lock_outline_rounded, isError: false),
        title: 'Sign in required', body: 'Please sign in to view your profile.',
        btnLabel: 'Refresh Session', filled: false, onAction: onAction,
      );

  final Widget       stateIcon;
  final String       title;
  final String       body;
  final String       btnLabel;
  final bool         filled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c      = AppColor.of(context);
    final accent = filled ? c.primary : c.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            stateIcon,
            const SizedBox(height: 18),
            Text(title, style: TextStyle(
              color: c.textPrimary, fontSize: 18,
              fontWeight: FontWeight.w900, letterSpacing: -0.5,
            ), textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(body, style: TextStyle(
              color: c.textSecondary, fontSize: 13, height: 1.5,
            ), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: filled ? accent : c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: filled ? null : Border.all(color: accent),
                  boxShadow: filled ? [BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 14, offset: const Offset(0, 4),
                  )] : null,
                ),
                child: Text(btnLabel, style: TextStyle(
                  color: filled ? c.onPrimary : accent,
                  fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.isError});
  final IconData icon;
  final bool     isError;

  @override
  Widget build(BuildContext context) {
    final c     = AppColor.of(context);
    final color = isError ? c.error : c.primary;
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(icon, size: 26, color: color),
    );
  }
}
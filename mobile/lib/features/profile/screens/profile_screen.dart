import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/image_uploader.dart';
import '../../../core/widgets/cs_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/stats_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey        = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _handicapCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user    = ref.read(authProvider).user!;
    _nameCtrl     = TextEditingController(text: user.name);
    _cityCtrl     = TextEditingController(text: user.city ?? '');
    _handicapCtrl = TextEditingController(
      text: user.handicap == 0 ? '0' : user.handicap.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _handicapCtrl.dispose();
    super.dispose();
  }

  bool _uploadingAvatar = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final handicap =
        double.tryParse(_handicapCtrl.text.trim()) ?? 0;
    final ok = await ref.read(authProvider.notifier).updateProfile(
      name:     _nameCtrl.text.trim(),
      handicap: handicap,
      city:     _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
    );
    if (ok && mounted) setState(() => _editing = false);
  }

  Future<void> _pickAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref.read(imageUploaderProvider).pickAndUpload(maxWidth: 800);
      if (!mounted || url == null) return;
      final ok = await ref.read(authProvider.notifier).updateProfile(
            profilePictureUrl: url,
          );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t save profile picture'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              user: user,
              editing: _editing,
              uploadingAvatar: _uploadingAvatar,
              onEditTap: () => setState(() => _editing = true),
              onBackTap: () => context.pop(),
              onAvatarTap: _uploadingAvatar ? null : _pickAvatar,
            ),
          ),

          // ── Content ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: _editing
                  ? _EditForm(
                      formKey: _formKey,
                      nameCtrl: _nameCtrl,
                      cityCtrl: _cityCtrl,
                      handicapCtrl: _handicapCtrl,
                      loading: auth.loading,
                      error: auth.error,
                      onSave: _save,
                      onCancel: () => setState(() => _editing = false),
                    )
                  : _ViewMode(
                      user: user,
                      statsAsync: ref.watch(myStatsProvider),
                      onAdminTap: user.isAdmin
                          ? () => context.push('/admin')
                          : null,
                      onLogout: () => _confirmLogout(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ───────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final bool editing;
  final bool uploadingAvatar;
  final VoidCallback onEditTap;
  final VoidCallback onBackTap;
  final VoidCallback? onAvatarTap;

  const _ProfileHeader({
    required this.user,
    required this.editing,
    required this.uploadingAvatar,
    required this.onEditTap,
    required this.onBackTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: onBackTap,
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 20),
                  ),
                  const Text(
                    'PROFILE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  if (!editing)
                    IconButton(
                      onPressed: onEditTap,
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white70, size: 20),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                            color: const Color(0xFFC9A84C), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (user.profilePictureUrl != null &&
                              (user.profilePictureUrl as String).isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: user.profilePictureUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  user.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 38,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                user.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 38,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9A84C),
                        shape: BoxShape.circle,
                      ),
                      child: uploadingAvatar
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black87))
                          : const Icon(Icons.camera_alt,
                              size: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── View Mode ────────────────────────────────────────────────────────────────
class _ViewMode extends StatelessWidget {
  final dynamic user;
  final AsyncValue<dynamic> statsAsync;
  final VoidCallback? onAdminTap;
  final VoidCallback onLogout;

  const _ViewMode({
    required this.user,
    required this.statsAsync,
    required this.onAdminTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final handicapStr = user.handicap == 0
        ? 'Scratch'
        : user.handicap.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handicap + city cards
        Row(children: [
          Expanded(
            child: _StatCard(
              icon: Icons.sports_golf_rounded,
              label: 'HANDICAP',
              value: handicapStr,
              highlight: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.location_on_outlined,
              label: 'CITY',
              value: user.city ?? '–',
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Career stats
        _SectionLabel('CAREER RECORD'),
        const SizedBox(height: 10),
        statsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1B3D2C)),
            ),
          ),
          error: (e, __) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Stats unavailable — restart the backend.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ]),
          ),
          data: (stats) => _CareerStats(stats: stats),
        ),
        const SizedBox(height: 24),

        if (onAdminTap != null) ...[
          _SectionLabel('ADMIN'),
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin Dashboard',
            color: const Color(0xFF1B3D2C),
            onTap: onAdminTap!,
          ),
          const SizedBox(height: 24),
        ],

        _SectionLabel('ACCOUNT'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: [
            _ListRow(
              icon: Icons.lock_outline,
              label: 'Privacy Policy',
              onTap: () {},
            ),
            _Divider(),
            _ListRow(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () {},
            ),
            _Divider(),
            _ListRow(
              icon: Icons.logout,
              label: 'Sign Out',
              color: AppColors.error,
              onTap: onLogout,
            ),
          ]),
        ),
        const SizedBox(height: 32),

        const Center(
          child: Text(
            'Clubhouse Stakes v1.0.0\nCompetition is skill-based. No gambling.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit Form ────────────────────────────────────────────────────────────────
class _EditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController handicapCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.cityCtrl,
    required this.handicapCtrl,
    required this.loading,
    required this.error,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('PERSONAL INFO'),
          const SizedBox(height: 12),
          TextFormField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: cityCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Handicap text field
          TextFormField(
            controller: handicapCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,2}\.?\d{0,1}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Handicap',
              hintText: '0 = Scratch',
              prefixIcon: Icon(Icons.sports_golf_rounded),
              suffixText: 'HCP',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final d = double.tryParse(v.trim());
              if (d == null || d < 0 || d > 54) {
                return 'Enter 0–54';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          CSButton(
              label: 'Save Changes', loading: loading, onPressed: onSave),
          const SizedBox(height: 10),
          CSButton(
              label: 'Cancel',
              outlined: true,
              onPressed: onCancel),
        ],
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF1B3D2C).withOpacity(0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? const Color(0xFF1B3D2C).withOpacity(0.15)
              : AppColors.divider,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon,
            color: highlight
                ? const Color(0xFF1B3D2C)
                : AppColors.textSecondary,
            size: 20),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: highlight
                  ? const Color(0xFF1B3D2C)
                  : AppColors.textPrimary,
            )),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.textSecondary,
        ),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ListRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          )),
      trailing: Icon(Icons.chevron_right, color: c.withOpacity(0.5)),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 52, endIndent: 0);
}

// ── Career Stats ─────────────────────────────────────────────────────────────
class _CareerStats extends StatelessWidget {
  final dynamic stats;
  const _CareerStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bestScore = stats.bestScore as int?;
    final bestLabel = bestScore != null ? '$bestScore' : '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Trophy row ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _MedalTile(
                    emoji: '🥇',
                    label: 'GOLD',
                    count: stats.golds,
                    color: const Color(0xFFC9A84C),
                  ),
                ),
                Container(width: 1, height: 52, color: AppColors.divider),
                Expanded(
                  child: _MedalTile(
                    emoji: '🥈',
                    label: 'SILVER',
                    count: stats.silvers,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
                Container(width: 1, height: 52, color: AppColors.divider),
                Expanded(
                  child: _MedalTile(
                    emoji: '🥉',
                    label: 'BRONZE',
                    count: stats.bronzes,
                    color: const Color(0xFFCD7F32),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Career Earnings ──
          _StatRow(
            icon: Icons.attach_money_rounded,
            label: 'CAREER EARNINGS',
            value: '\$${stats.careerEarnings.toStringAsFixed(0)}',
            valueColor: const Color(0xFF1B3D2C),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Career Best Score ──
          _StatRow(
            icon: Icons.emoji_events_outlined,
            label: 'CAREER BEST SCORE',
            value: bestLabel,
            valueColor: bestScore != null
                ? const Color(0xFF1B3D2C)
                : AppColors.textSecondary,
            valueSuffix: bestScore != null ? ' gross' : '',
          ),
        ],
      ),
    );
  }
}

class _MedalTile extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;

  const _MedalTile({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final String valueSuffix;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (valueSuffix.isNotEmpty)
                  TextSpan(
                    text: valueSuffix,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: valueColor.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

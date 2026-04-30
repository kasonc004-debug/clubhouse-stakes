import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _cityCtrl;
  late double _handicap;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user  = ref.read(authProvider).user!;
    _nameCtrl   = TextEditingController(text: user.name);
    _cityCtrl   = TextEditingController(text: user.city ?? '');
    _handicap   = user.handicap;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).updateProfile(
      name:     _nameCtrl.text.trim(),
      handicap: _handicap,
      city:     _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
    );
    if (ok) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_editing)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.black87),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_editing) ...[
              Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 24),

            if (_editing) ...[
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('Handicap', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_handicap == 0 ? 'Scratch' : _handicap.toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  Slider(
                    value: _handicap, min: 0, max: 54, divisions: 108,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _handicap = v),
                  ),
                  const SizedBox(height: 24),
                  if (auth.error != null)
                    Text(auth.error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 8),
                  CSButton(label: 'Save Changes', loading: auth.loading, onPressed: _save),
                  const SizedBox(height: 10),
                  CSButton(label: 'Cancel', outlined: true,
                    onPressed: () => setState(() => _editing = false)),
                ]),
              ),
            ] else ...[
              // Stat cards
              Row(children: [
                Expanded(child: _StatCard('Handicap', user.handicap == 0 ? 'Scratch' : user.handicap.toStringAsFixed(1), Icons.sports_golf)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard('City', user.city ?? '–', Icons.location_on_outlined)),
              ]),
              const SizedBox(height: 12),
              if (user.isAdmin)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: CSButton(
                    label: 'Admin Dashboard',
                    icon: Icons.admin_panel_settings,
                    color: AppColors.primaryDark,
                    onPressed: () => context.push('/admin'),
                  ),
                ),
              const SizedBox(height: 20),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    onTap: () => _confirmLogout(context),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('Clubhouse Stakes v1.0.0\n'
                  'Competition is skill-based. No gambling.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
            ],
          ],
        ),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

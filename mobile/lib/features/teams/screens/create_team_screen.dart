import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../players/providers/player_provider.dart';
import '../providers/team_provider.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const CreateTeamScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _nameCtrl   = TextEditingController();
  final _searchCtrl = TextEditingController();

  String          _searchQuery  = '';
  Timer?          _debounce;
  PlayerProfile?  _selectedPartner;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = val.trim());
    });
  }

  void _selectPartner(PlayerProfile p) {
    setState(() {
      _selectedPartner = p;
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  void _clearPartner() {
    setState(() {
      _selectedPartner = null;
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  Future<void> _register() async {
    final team = await ref.read(createTeamProvider.notifier).create(
      tournamentId: widget.tournamentId,
      name:         _nameCtrl.text.trim(),
      partnerId:    _selectedPartner?.id,
    );
    if (team != null && mounted) {
      final msg = _selectedPartner != null
          ? 'Team registered! You and ${_selectedPartner!.name} are in.'
          : 'Team created! Your partner can join from the tournament page.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createTeamProvider);
    final currentUserId = ref.watch(authProvider).user?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF1B3D2C),
            foregroundColor: Colors.white,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Register as a Team',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Add your partner to register both of you at once',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Team name ──────────────────────────────────
                  _SectionLabel('TEAM NAME (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Eagle Squad, The Bogey Boys',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Partner section ────────────────────────────
                  _SectionLabel('YOUR PARTNER'),
                  const SizedBox(height: 4),
                  const Text(
                    'Search for your partner by name. They must already have an account.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedPartner != null)
                    _SelectedPartnerCard(
                      partner: _selectedPartner!,
                      onRemove: _clearPartner,
                    )
                  else ...[
                    // Search field
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PartnerSearchResults(
                      query: _searchQuery,
                      excludeUserId: currentUserId,
                      onSelect: _selectPartner,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── No account info ────────────────────────────
                  _NoAccountBanner(),

                  const SizedBox(height: 32),

                  // ── Error ──────────────────────────────────────
                  if (createState is AsyncError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(createState.error.toString(),
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Register button ────────────────────────────
                  CSButton(
                    label: _selectedPartner != null
                        ? 'Register Team  ·  2 players'
                        : 'Create Team  ·  Add partner later',
                    icon: Icons.how_to_reg_outlined,
                    loading: createState.isLoading,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 12),
                  CSButton(
                    label: 'Cancel',
                    outlined: true,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: AppColors.textSecondary));
}

// ── Selected partner card ─────────────────────────────────────────────────────

class _SelectedPartnerCard extends StatelessWidget {
  final PlayerProfile partner;
  final VoidCallback onRemove;
  const _SelectedPartnerCard({required this.partner, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: AppColors.success, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(partner.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              'HCP ${partner.handicap.toStringAsFixed(1)}'
              '${partner.city != null ? ' · ${partner.city}' : ''}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
          onPressed: onRemove,
          tooltip: 'Remove partner',
        ),
      ]),
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _PartnerSearchResults extends ConsumerWidget {
  final String query;
  final String excludeUserId;
  final ValueChanged<PlayerProfile> onSelect;

  const _PartnerSearchResults({
    required this.query,
    required this.excludeUserId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.length < 2) return const SizedBox.shrink();

    final searchAsync = ref.watch(playerSearchProvider(query));

    return searchAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary))),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (players) {
        final filtered = players.where((p) => p.id != excludeUserId).toList();
        if (filtered.isEmpty) {
          return _NoResultsCard(query: query);
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: filtered.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Column(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.primary.withOpacity(0.12),
                        child: Text(
                          p.name.isNotEmpty
                              ? p.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(
                              'HCP ${p.handicap.toStringAsFixed(1)}'
                              '${p.city != null ? ' · ${p.city}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_outline,
                          color: AppColors.primary, size: 22),
                    ]),
                  ),
                ),
                if (i < filtered.length - 1)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── No results card ───────────────────────────────────────────────────────────

class _NoResultsCard extends StatelessWidget {
  final String query;
  const _NoResultsCard({required this.query});

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
        Row(children: [
          const Icon(Icons.person_search,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No players found for "$query"',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Your partner needs to create a Clubhouse Stakes account first. '
          'Ask them to download the app and sign up, then try again.',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5),
        ),
      ]),
    );
  }
}

// ── No account info banner ────────────────────────────────────────────────────

class _NoAccountBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A84C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFC9A84C).withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💡', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            "Don't see your partner? They need to sign up for Clubhouse Stakes first. "
            "You can still create a solo team now and have them join from the tournament page.",
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../providers/team_provider.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const CreateTeamScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    final team = await ref.read(createTeamProvider.notifier).create(
      tournamentId: widget.tournamentId,
      name:         _nameCtrl.text.trim(),
    );
    if (team != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team created! Share the tournament with your partner.'),
          backgroundColor: AppColors.success));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createTeamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.group_add, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Create Your Team',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'You\'ll be Player 1. Your partner can join using the tournament\'s team list.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Team Name (optional)',
                hintText: 'e.g. Eagle Squad, The Bogey Boys',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
            if (state is AsyncError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(state.error.toString(),
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 32),
            CSButton(
              label: 'Create Team',
              icon: Icons.group_add,
              loading: state.isLoading,
              onPressed: _create,
            ),
            const SizedBox(height: 12),
            CSButton(
              label: 'Cancel',
              outlined: true,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

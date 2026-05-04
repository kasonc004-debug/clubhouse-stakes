import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../../players/providers/player_provider.dart';
import '../providers/clubhouse_provider.dart';

/// Owner's invite-a-member bottom sheet. Lets the owner search by name
/// (existing player) or paste an email (new or existing user).
class InviteMemberSheet extends ConsumerStatefulWidget {
  final String clubhouseId;
  final String clubhouseName;
  const InviteMemberSheet({
    super.key,
    required this.clubhouseId,
    required this.clubhouseName,
  });

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  final _searchCtrl = TextEditingController();
  Timer?  _debounce;
  String  _query = '';
  bool    _busy = false;

  bool get _looksLikeEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(_query.trim());

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _send({String? userId, String? email}) async {
    setState(() => _busy = true);
    try {
      final kind = await ref.read(clubhouseMembershipProvider).invite(
            clubhouseId: widget.clubhouseId,
            userId: userId,
            email: email,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kind == 'email_invite'
            ? 'Email invite sent — they\'ll be added when they sign up.'
            : 'Invite sent.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.person_add_alt_1, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Invite to ${widget.clubhouseName}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Name or email',
                hintText: 'Search a player or paste an email',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            // Email branch
            if (_query.isNotEmpty && _looksLikeEmail) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.mail_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_query,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'If they don\'t have an account, we\'ll email them an invite. '
                    'When they sign up with this email they\'ll be added to your '
                    'clubhouse automatically.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              CSButton(
                label: 'Send invite',
                loading: _busy,
                onPressed: () => _send(email: _query.trim()),
              ),
            ]
            // Name search branch
            else if (_query.length >= 2)
              _PlayerResults(
                query: _query,
                busy: _busy,
                onPick: (id) => _send(userId: id),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Search by name to invite an existing player, or paste an email '
                  'address to invite someone new.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _PlayerResults extends ConsumerWidget {
  final String query;
  final bool busy;
  final void Function(String userId) onPick;
  const _PlayerResults(
      {required this.query, required this.busy, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerSearchProvider(query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 10),
          Text('Searching…',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text('Search failed: $e',
            style: const TextStyle(fontSize: 12, color: AppColors.error)),
      ),
      data: (players) {
        if (players.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'No players found. Paste an email to send an invite.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < players.length && i < 8; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.divider),
                ListTile(
                  dense: true,
                  enabled: !busy,
                  title: Text(players[i].name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'HCP ${players[i].handicap.toStringAsFixed(1)}'
                    '${players[i].city != null ? ' · ${players[i].city}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.send, size: 18),
                  onTap: () => onPick(players[i].id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

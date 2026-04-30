import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/tournament_model.dart';

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;

  const TournamentCard({super.key, required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Green header bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _FormatBadge(format: t.format),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Location
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(DateFormat('EEE, MMM d, yyyy').format(t.date),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(t.courseName != null ? '${t.courseName} · ${t.city}' : t.city,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                  const SizedBox(height: 14),
                  // Fee + Purse row
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Entry Fee',
                          value: '\$${t.signUpFee.toStringAsFixed(0)}',
                          subtitle: 'per ${t.feePer}',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Purse',
                          value: '\$${t.purse.toStringAsFixed(0)}',
                          subtitle: 'total',
                          color: AppColors.gold,
                          highlighted: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Players',
                          value: '${t.playerCount}/${t.maxPlayers}',
                          subtitle: '${t.spotsLeft} left',
                          color: t.isFull ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status chip
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    _StatusChip(status: t.status),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final bool highlighted;

  const _StatBox({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.gold.withOpacity(0.08) : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: highlighted ? Border.all(color: AppColors.gold.withOpacity(0.4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String format;
  const _FormatBadge({required this.format});

  @override
  Widget build(BuildContext context) {
    final label = format == 'fourball' ? 'Four-Ball' : 'Individual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(
        color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'upcoming':  (AppColors.primary, AppColors.primary.withOpacity(0.1)),
      'active':    (AppColors.success, AppColors.success.withOpacity(0.1)),
      'completed': (AppColors.textSecondary, AppColors.textSecondary.withOpacity(0.1)),
    };
    final (fg, bg) = colors[status] ?? (AppColors.textSecondary, AppColors.background);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}

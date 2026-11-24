import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/countdown_digits.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/vault_controller.dart';
import 'locked_chest_page.dart';

class ChestLockedDateModal extends StatefulWidget {
  final CapsuleModel capsule;
  const ChestLockedDateModal({super.key, required this.capsule});

  @override
  State<ChestLockedDateModal> createState() => _ChestLockedDateModalState();
}

class _ChestLockedDateModalState extends State<ChestLockedDateModal> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _compute());
  }

  void _compute() {
    final unlock = widget.capsule.unlockDate;
    if (unlock == null) return;
    final now = DateTime.now();
    if (!unlock.isAfter(now)) {
      context.read<VaultController>().checkDueUnlocks();
    }
    final remaining = unlock.difference(now);
    // The display has no seconds, so redraw only when its minute changes.
    if (_remaining != Duration.zero &&
        remaining.inMinutes == _remaining.inMinutes) {
      return;
    }
    final total = unlock.difference(widget.capsule.createdAt).inSeconds;
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
      _progress = total <= 0
          ? 0
          : (1 - remaining.inSeconds / total).clamp(0.0, 1.0).toDouble();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlock = widget.capsule.unlockDate;
    return LockedChestPage(
      capsule: widget.capsule,
      body: (context, vault, chest) => [
        PixelPanel(
          title: 'OPENS IN',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountdownDigits(_remaining),
              const SizedBox(height: AppSpacing.md),
              PixelProgressBar(value: _progress),
              if (unlock != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  ZingDateUtils.dateTimeLabel(unlock),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.button,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const PixelNote(
          "Nobody can open it early, not even by changing the phone's clock.",
        ),
      ],
    );
  }
}

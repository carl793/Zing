import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/session_controller.dart';
import '../../../core/constants/sprite_options.dart';
import '../../../core/permissions/permission_flows.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_snack_bar.dart';
import '../../../core/widgets/sprite_selector.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SettingsController(
        session: ctx.read<SessionController>(),
        users: ctx.read<UserRepository>(),
        couples: ctx.read<CoupleRepository>(),
        location: ctx.read<LocationService>(),
      ),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _selectedSprite;

  /// The form is filled once, then belongs to the player until saved.
  bool _filled = false;

  bool _bgmOn = AudioService.instance.bgmEnabled;
  bool _sfxOn = AudioService.instance.sfxEnabled;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _fill(SettingsController ctrl) {
    final me = ctrl.me;
    if (_filled || me == null) return;
    _filled = true;
    _nameCtrl.text = me.displayName;
    _cityCtrl.text = me.homeCity;
    _selectedSprite =
        me.avatarSpriteId.isEmpty ? SpriteOptions.fallback : me.avatarSpriteId;
  }

  /// Shows the message a controller action returned, if it failed.
  Future<void> _report(Future<String?> action) async {
    final error = await action;
    if (error != null && mounted) {
      showPixelSnackBar(context, error, color: AppColors.coral);
    }
  }

  Future<void> _save(SettingsController ctrl) async {
    FocusScope.of(context).unfocus();
    final error = await ctrl.saveProfile(
      name: _nameCtrl.text.trim(),
      spriteId: _selectedSprite ?? SpriteOptions.fallback,
      city: _cityCtrl.text.trim(),
      onCityNotFound: () {
        if (!mounted) return;
        showPixelSnackBar(
          context,
          "CITY SAVED, BUT IT COULDN'T BE FOUND ON THE MAP. "
          'TRY "CITY, COUNTRY".',
          color: AppColors.amber,
        );
      },
    );
    if (!mounted) return;
    showPixelSnackBar(
      context,
      error ?? 'SETTINGS SAVED.',
      color: error == null ? AppColors.yellow : AppColors.coral,
    );
  }

  Future<void> _toggleLocation(SettingsController ctrl, bool on) async {
    if (!on) return _report(ctrl.stopSharingLocation());
    final granted =
        await ensureLocationAccess(context, context.read<LocationService>());
    if (granted) await _report(ctrl.shareLocation());
  }

  void _toggleBgm(bool on) {
    setState(() => _bgmOn = on);
    AudioService.instance.setBgmEnabled(on);
  }

  void _toggleSfx(bool on) {
    setState(() => _sfxOn = on);
    AudioService.instance.setSfxEnabled(on);
  }

  Future<void> _unlink(SettingsController ctrl) async {
    final confirmed = await showConfirmDialog(
      context: context,
      message:
          'UNLINK FROM YOUR PARTNER?\n\nAll memories and chests are preserved, '
          'but you will both need to re-pair to reconnect.',
      confirmLabel: '[ YES, UNLINK ]',
      cancelLabel: '[ KEEP LINKED ]',
    );
    if (confirmed) await _report(ctrl.unlink());
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    try {
      await auth.logout();
    } catch (e) {
      debugPrint('Logout failed: $e');
      if (mounted) {
        showPixelSnackBar(context, "COULDN'T LOG OUT. TRY AGAIN.",
            color: AppColors.coral);
      }
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    _fill(ctrl);
    final couple = ctrl.couple;

    if (!_filled) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: ctrl.loadFailed
              ? Text(
                  "COULDN'T LOAD SETTINGS.\nRETRYING...",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.amber),
                )
              : const CircularProgressIndicator(color: AppColors.yellow),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──
              Text(
                'SYSTEM CONFIG',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  fontSize: 15,
                  color: AppColors.cyan,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Profile ──
              _Section(
                title: 'PLAYER PROFILE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISPLAY NAME', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    _InsetTextField(controller: _nameCtrl, hint: 'YOUR NAME'),
                    const SizedBox(height: AppSpacing.md),
                    Text('HERO SPRITE', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    SpriteSelector(
                      selectedId: _selectedSprite ?? SpriteOptions.fallback,
                      onSelected: (sprite) =>
                          setState(() => _selectedSprite = sprite),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Location fallback ──
              _Section(
                title: 'DISTANCE ENGINE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ToggleRow(
                      label: 'SHARE MY LOCATION',
                      value: ctrl.isSharingLocation,
                      onChanged: (on) => _toggleLocation(ctrl, on),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'ONLY YOUR PARTNER SEES IT. TURNING THIS OFF ERASES YOUR '
                      'LAST POSITION.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray,
                        fontSize: 7,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'HOME CITY (LOCATION FALLBACK)',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 6),
                    _InsetTextField(
                      controller: _cityCtrl,
                      hint: 'e.g. MANILA, PHILIPPINES',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'USED WHEN GPS IS OFF. SHOWN AS APPROXIMATE DISTANCE.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Row(
                      label: 'UNIT PREFERENCE',
                      child: Row(
                        children: [
                          _UnitChip(
                            label: 'KM',
                            active: ctrl.unit == 'km',
                            onTap: () => _report(ctrl.setUnit('km')),
                          ),
                          const SizedBox(width: 8),
                          _UnitChip(
                            label: 'MI',
                            active: ctrl.unit == 'mi',
                            onTap: () => _report(ctrl.setUnit('mi')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Audio ──
              _Section(
                title: 'AUDIO & ALERTS',
                child: Column(
                  children: [
                    _ToggleRow(
                      label: '8-BIT BGM',
                      value: _bgmOn,
                      onChanged: _toggleBgm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ToggleRow(
                      label: 'CHIPTUNE SFX',
                      value: _sfxOn,
                      onChanged: _toggleSfx,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ToggleRow(
                      label: 'REUNION COUNTDOWN ALERTS',
                      value: ctrl.alertsOn,
                      onChanged: (on) => _report(ctrl.setAlerts(on)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Room info ──
              if (couple != null)
                _Section(
                  title: 'ROOM INFO',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ROOM ID', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.charcoal,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              couple.pairingCode,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '(REFERENCE ONLY)',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 5,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // ── Save button ──
              PixelButton(
                label: ctrl.saving ? 'SAVING...' : '[ SAVE SETTINGS ]',
                style: PixelButtonStyle.yellow,
                onPressed: ctrl.saving ? null : () => _save(ctrl),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Danger zone ──
              _Section(
                title: 'DANGER ZONE',
                borderColor: AppColors.coral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelButton(
                      label: '[ UNLINK PARTNER ROOM ]',
                      style: PixelButtonStyle.outlineDanger,
                      backgroundColor: AppColors.charcoal,
                      onPressed: () => _unlink(ctrl),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PixelButton(label: '[ LOGOUT ]', onPressed: _logout),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Color borderColor;
  const _Section({
    required this.title,
    required this.child,
    this.borderColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: AppColors.cyan,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InsetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _InsetTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        maxLength: 40,
        style: AppTextStyles.body.copyWith(
          color: AppColors.yellow,
          fontSize: 8,
        ),
        cursorColor: AppColors.cyan,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: AppTextStyles.body.copyWith(
            color: const Color(0xFF555577),
            fontSize: 8,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.cyan,
              fontSize: 7,
            ),
          ),
        ),
        _PixelSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PixelSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PixelSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(AppSfx.tap);
        onChanged(!value);
      },
      child: Container(
        width: 38,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          mainAxisAlignment: value
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              color: value ? AppColors.yellow : AppColors.gray,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _UnitChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.yellow : AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 7,
            color: active ? Colors.black : AppColors.cyan,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.cyan,
            fontSize: 7,
          ),
        ),
        child,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_dialog.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_toast.dart';
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

  final _audio = AudioService.instance;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_redraw);
    _cityCtrl.addListener(_redraw);
  }

  void _redraw() {
    if (mounted && _filled) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _fill(SettingsController ctrl) {
    final me = ctrl.me;
    if (_filled || me == null) return;
    _nameCtrl.text = me.displayName;
    _cityCtrl.text = me.homeCity;
    _selectedSprite = _spriteOf(ctrl);
    _filled = true;
  }

  static String _spriteOf(SettingsController ctrl) {
    final id = ctrl.me?.avatarSpriteId ?? '';
    return id.isEmpty ? SpriteOptions.fallback : id;
  }

  /// Only the profile waits for SAVE; every switch applies at once.
  bool _hasChanges(SettingsController ctrl) =>
      _nameCtrl.text.trim() != ctrl.me?.displayName ||
      _cityCtrl.text.trim() != ctrl.me?.homeCity ||
      _selectedSprite != _spriteOf(ctrl);

  void _undo(SettingsController ctrl) {
    FocusScope.of(context).unfocus();
    setState(() {
      _filled = false;
      _fill(ctrl);
    });
  }

  /// Shows the message a controller action returned, if it failed.
  Future<void> _report(Future<String?> action) async {
    final error = await action;
    if (error != null && mounted) {
      showPixelToast(context, error, color: AppColors.coral);
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
        showPixelToast(
          context,
          "CITY SAVED, BUT IT COULDN'T BE FOUND ON THE MAP. "
          'TRY "CITY, COUNTRY".',
          color: AppColors.amber,
        );
      },
    );
    if (!mounted) return;
    if (error == null) _audio.playSfx(AppSfx.save);
    showPixelToast(
      context,
      error ?? 'PROFILE SAVED.',
      color: error == null ? AppColors.yellow : AppColors.coral,
    );
  }

  Future<void> _toggleLocation(SettingsController ctrl, bool on) async {
    if (!on) return _report(ctrl.stopSharingLocation());
    final granted =
        await ensureLocationAccess(context, context.read<LocationService>());
    if (granted) await _report(ctrl.shareLocation());
  }

  Future<void> _unlink(SettingsController ctrl) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'UNLINK?',
      message: 'Your memories and chests are kept, but you both leave this '
          'room and have to pair again to reconnect.',
      confirmLabel: 'UNLINK',
      cancelLabel: 'STAY LINKED',
    );
    if (confirmed) await _report(ctrl.unlink());
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'LOG OUT?',
      message: 'You stay linked with your partner, and can log back in any '
          'time.',
      confirmLabel: 'LOG OUT',
      confirmIcon: PixelIcons.logout,
      cancelLabel: 'STAY',
      icon: PixelIcons.logout,
    );
    if (!confirmed) return;
    try {
      await auth.logout();
    } catch (e) {
      debugPrint('Logout failed: $e');
      if (mounted) {
        showPixelToast(context, "COULDN'T LOG OUT. TRY AGAIN.",
            color: AppColors.coral);
      }
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  void _copyRoom(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showPixelToast(context, 'ROOM CODE COPIED.');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    _fill(ctrl);

    if (!_filled) {
      return Center(
        child: ctrl.loadFailed
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child:
                    PixelNote.warning("Couldn't load settings. Retrying..."),
              )
            : const PixelLoading(),
      );
    }

    const gap = SizedBox(height: AppSpacing.lg);
    return SafeArea(
      bottom: false,
      child: PixelColumn(
        child: Column(
          children: [
            const PixelScreenTitle(
              title: 'CONFIG',
              icon: PixelIcons.gear,
              tone: PixelTone.cyan,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg + 4, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profile(),
                    gap,
                    _distance(ctrl),
                    gap,
                    _feedback(ctrl),
                    gap,
                    _room(ctrl),
                  ],
                ),
              ),
            ),
            if (_hasChanges(ctrl) || ctrl.saving)
              PixelActionBar(
                child: Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: 'UNDO',
                        style: PixelButtonStyle.neutral,
                        onPressed: ctrl.saving ? null : () => _undo(ctrl),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PixelButton(
                        label: ctrl.saving ? 'SAVING' : 'SAVE',
                        icon: PixelIcons.check,
                        busy: ctrl.saving,
                        onPressed: () => _save(ctrl),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profile() => PixelPanel(
        title: 'PLAYER',
        icon: PixelIcons.user,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelField(
              label: 'DISPLAY NAME',
              hint: 'YOUR NAME',
              controller: _nameCtrl,
              maxLength: 20,
              textColor: AppColors.yellow,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.lg),
            const PixelLabel('HERO'),
            SpriteSelector(
              selectedId: _selectedSprite ?? SpriteOptions.fallback,
              onSelected: (sprite) => setState(() => _selectedSprite = sprite),
            ),
          ],
        ),
      );

  Widget _distance(SettingsController ctrl) => PixelPanel(
        title: 'DISTANCE',
        icon: PixelIcons.pin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSettingRow(
              icon: PixelIcons.pin,
              label: 'SHARE MY LOCATION',
              hint: 'Only your partner sees it. Turning it off erases your '
                  'last position.',
              control: PixelSwitch(
                label: 'Share my location',
                value: ctrl.isSharingLocation,
                onChanged: (on) => _toggleLocation(ctrl, on),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelField(
              label: 'HOME CITY',
              hint: 'MANILA, PHILIPPINES',
              icon: PixelIcons.home,
              controller: _cityCtrl,
              maxLength: 40,
              textColor: AppColors.yellow,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Used while your location is off.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            const PixelLabel('UNIT'),
            PixelSegments(
              labels: const ['KM', 'MILES'],
              selected: ctrl.unit == 'mi' ? 1 : 0,
              onSelected: (i) => _report(ctrl.setUnit(i == 1 ? 'mi' : 'km')),
            ),
          ],
        ),
      );

  Widget _feedback(SettingsController ctrl) => PixelPanel(
        title: 'SOUND & ALERTS',
        icon: PixelIcons.sound,
        child: Column(
          children: [
            PixelSettingRow(
              icon: PixelIcons.music,
              label: 'MUSIC',
              control: PixelSwitch(
                label: 'Music',
                value: _audio.bgmEnabled,
                onChanged: (on) {
                  _audio.setBgmEnabled(on);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PixelSettingRow(
              icon: PixelIcons.sound,
              label: 'SOUND EFFECTS',
              control: PixelSwitch(
                label: 'Sound effects',
                value: _audio.sfxEnabled,
                onChanged: (on) {
                  _audio.setSfxEnabled(on);
                  // The switch itself was silent while they were off.
                  if (on) _audio.playSfx(AppSfx.toggleOn);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PixelSettingRow(
              icon: PixelIcons.vibrate,
              label: 'VIBRATION',
              control: PixelSwitch(
                label: 'Vibration',
                value: _audio.hapticsEnabled,
                onChanged: (on) {
                  _audio.setHapticsEnabled(on);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PixelSettingRow(
              icon: PixelIcons.bell,
              label: 'REUNION ALERTS',
              control: PixelSwitch(
                label: 'Reunion alerts',
                value: ctrl.alertsOn,
                onChanged: (on) => _report(ctrl.setAlerts(on)),
              ),
            ),
          ],
        ),
      );

  Widget _room(SettingsController ctrl) {
    final code = ctrl.couple?.pairingCode ?? '';
    return PixelPanel(
      title: 'ROOM & ACCOUNT',
      icon: PixelIcons.key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code.isNotEmpty) ...[
            const PixelLabel('ROOM CODE, FOR REFERENCE'),
            Row(
              children: [
                Expanded(
                  child: PixelWell(
                    child: Text(
                      code,
                      style: AppTextStyles.subHeader
                          .copyWith(color: AppColors.gray),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PixelIconButton(
                  icon: PixelIcons.copy,
                  label: 'Copy room code',
                  onPressed: () => _copyRoom(code),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          PixelButton(
            label: 'LOG OUT',
            icon: PixelIcons.logout,
            style: PixelButtonStyle.neutral,
            onPressed: _logout,
          ),
          const SizedBox(height: AppSpacing.md),
          PixelButton(
            label: 'UNLINK PARTNER',
            icon: PixelIcons.warning,
            style: PixelButtonStyle.danger,
            onPressed: () => _unlink(ctrl),
          ),
        ],
      ),
    );
  }
}

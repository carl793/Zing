import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/onboarding_progress_bar.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_toast.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../../../data/repositories/pairing_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../controllers/pairing_controller.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
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

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    return ChangeNotifierProvider(
      create: (_) => PairingController(
        context.read<PairingRepository>(),
        context.read<UserRepository>(),
        currentUid: uid,
      ),
      child: _PairingView(onLogout: _logout),
    );
  }
}

class _PairingView extends StatelessWidget {
  final VoidCallback onLogout;
  const _PairingView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();

    if (ctrl.linked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.pairingSuccess);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.night,
      body: PixelBackdrop(
        child: SafeArea(
          child: PixelColumn(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + 4, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: OnboardingProgressBar(currentStep: 3),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpriteIdle(
                        child: SpriteAvatar(spriteId: 'monster_guy', size: 72),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: PixelIcon(
                          PixelIcons.heart,
                          size: 24,
                          color: AppColors.coral,
                          shadow: true,
                        ),
                      ),
                      SpriteIdle(
                        offBeat: true,
                        child: SpriteAvatar(spriteId: 'mecha_rabbit', size: 72),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'FIND PLAYER TWO',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.header,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PixelSegments(
                    labels: const ['CREATE', 'JOIN'],
                    icons: const [PixelIcons.plus, PixelIcons.key],
                    selected: ctrl.tab == PairingTab.create ? 0 : 1,
                    onSelected: (i) => ctrl.switchTab(
                        i == 0 ? PairingTab.create : PairingTab.join),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PixelPanel(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ctrl.tab == PairingTab.create
                        ? const _CreatePanel()
                        : const _JoinPanel(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: PixelLink(
                      label: 'LOG OUT',
                      icon: PixelIcons.logout,
                      color: AppColors.gray,
                      onPressed: onLogout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CREATE PANEL
// ─────────────────────────────────────────────
class _CreatePanel extends StatelessWidget {
  const _CreatePanel();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();
    return switch (ctrl.createState) {
      CreateState.idle => _CreateIdle(ctrl: ctrl),
      CreateState.loading => const PixelLoading(label: 'MAKING A CODE'),
      CreateState.waiting => _CreateWaiting(ctrl: ctrl),
    };
  }
}

class _CreateIdle extends StatelessWidget {
  final PairingController ctrl;
  const _CreateIdle({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Make a 6-digit code and send it to your partner. It works for 24 '
          'hours.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (ctrl.createFailed) ...[
          const PixelNote.error("Couldn't make a code. Check your internet."),
          const SizedBox(height: AppSpacing.lg),
        ],
        PixelButton(
          label: 'MAKE A CODE',
          icon: PixelIcons.plus,
          onPressed: ctrl.generateCode,
        ),
      ],
    );
  }
}

class _CreateWaiting extends StatelessWidget {
  final PairingController ctrl;
  const _CreateWaiting({required this.ctrl});

  void _copy(BuildContext context) {
    if (ctrl.copyCode()) showPixelToast(context, 'CODE COPIED!');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PixelLabel('YOUR CODE'),
        Row(
          children: [
            Expanded(
              child: PixelWell(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ctrl.generatedCode ?? '------',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 24,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PixelIconButton(
              icon: PixelIcons.copy,
              label: 'Copy code',
              tone: PixelTone.yellow,
              size: 54,
              onPressed: () => _copy(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Expires in ${ctrl.countdownDisplay}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const PixelLoader(size: 5, color: AppColors.cyan),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Waiting for your partner to enter it...',
                style: AppTextStyles.caption.copyWith(color: AppColors.cyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PixelLink(
              label: 'NEW CODE',
              icon: PixelIcons.refresh,
              onPressed: ctrl.regenerateCode,
            ),
            PixelLink(
              label: 'CANCEL',
              color: AppColors.coral,
              onPressed: ctrl.cancelRoom,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// JOIN PANEL
// ─────────────────────────────────────────────
class _JoinPanel extends StatefulWidget {
  const _JoinPanel();

  @override
  State<_JoinPanel> createState() => _JoinPanelState();
}

class _JoinPanelState extends State<_JoinPanel> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() {
    if (_code.text.length != 6) return;
    FocusScope.of(context).unfocus();
    context.read<PairingController>().joinRoom(_code.text);
  }

  /// Takes the code out of whatever was copied, e.g. a whole message.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = RegExp(r'\d{3}-?\d{3}').firstMatch(data?.text ?? '')?[0];
    if (!mounted) return;
    if (code == null) {
      showPixelToast(context, 'NO CODE TO PASTE YET.',
          color: AppColors.amber);
    } else {
      _code.text = code.replaceAll('-', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();
    final error = _messageFor(ctrl.joinError);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PixelField(
                label: "YOUR PARTNER'S CODE",
                hint: '6 digits',
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                enabled: !ctrl.joinLoading,
                hasError: error != null,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.header.copyWith(letterSpacing: 4),
                textColor: AppColors.yellow,
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PixelIconButton(
              icon: PixelIcons.copy,
              label: 'Paste code',
              size: 54,
              onPressed: ctrl.joinLoading ? null : _paste,
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.md),
          PixelNote.error(error),
        ],
        const SizedBox(height: AppSpacing.lg),
        PixelButton(
          label: 'CONNECT',
          icon: PixelIcons.heart,
          style: PixelButtonStyle.coral,
          busy: ctrl.joinLoading,
          onPressed: _code.text.length == 6 ? _join : null,
        ),
      ],
    );
  }

  static String? _messageFor(JoinError error) => switch (error) {
        JoinError.notFound =>
          "THAT CODE DOESN'T EXIST. CHECK IT AND TRY AGAIN.",
        JoinError.expired =>
          'THIS CODE HAS EXPIRED. ASK YOUR PARTNER FOR A NEW ONE.',
        JoinError.alreadyLinked =>
          'THIS CODE IS ALREADY LINKED TO ANOTHER COUPLE.',
        JoinError.selfJoin =>
          "THAT'S YOUR OWN CODE! SEND IT TO YOUR PARTNER INSTEAD.",
        JoinError.network => 'NO CONNECTION. CHECK YOUR INTERNET.',
        JoinError.none => null,
      };
}

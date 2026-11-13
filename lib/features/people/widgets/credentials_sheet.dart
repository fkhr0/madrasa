import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/icon_box.dart';
import '../models/account_credentials_model.dart';
import '../../../core/l10n/language.dart';

/// Shows the generated ID and temporary password once, so the administrator can
/// hand them over: copy one, or copy both as a message ready to paste into
/// WhatsApp or an SMS.
Future<void> showCredentialsSheet(
  BuildContext context,
  AccountCredentialsModel credentials, {
  required String title,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CredentialsSheet(credentials: credentials, title: title),
  );
}

class _CredentialsSheet extends StatefulWidget {
  final AccountCredentialsModel credentials;
  final String title;

  const _CredentialsSheet({required this.credentials, required this.title});

  @override
  State<_CredentialsSheet> createState() => _CredentialsSheetState();
}

class _CredentialsSheetState extends State<_CredentialsSheet> {
  /// What was copied last ("id", "password", "both"), shown on its button.
  /// Feedback stays inside the sheet: a snack bar would appear behind it.
  String? _copied;
  bool _copyFailed = false;

  /// The message for "Copy both".
  String get _message {
    final user = widget.credentials.user;
    return tr(
      'Your account for the {0} app\nName: {1}\nSchool ID: {2}\nTemporary password: {3}\nYou will choose your own password when you sign in for the first time.',
      [
        user.schoolName.isEmpty ? 'school' : user.schoolName,
        user.name,
        user.id,
        widget.credentials.temporaryPassword,
      ],
    );
  }

  Future<void> _copy(String key, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      setState(() {
        _copied = key;
        _copyFailed = false;
      });
    } catch (_) {
      // Some browsers block copying on pages opened over plain http.
      setState(() => _copyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.credentials.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: IconBox(
                icon: Icons.verified_user_outlined,
                color: AppColors.success,
                size: 56,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              user.name,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _CopyField(
              label: tr('School ID'),
              value: user.id,
              copied: _copied == 'id',
              onCopy: () => _copy('id', user.id),
            ),
            const SizedBox(height: AppSpacing.md),
            _CopyField(
              label: tr('Temporary password'),
              value: widget.credentials.temporaryPassword,
              copied: _copied == 'password',
              onCopy: () =>
                  _copy('password', widget.credentials.temporaryPassword),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: () => _copy('both', _message),
              icon: Icon(
                _copied == 'both' ? Icons.check : Icons.copy_all_outlined,
              ),
              label: Text(
                _copied == 'both'
                    ? tr('Copied. Paste it in WhatsApp or SMS')
                    : tr('Copy both as a message'),
              ),
            ),
            if (_copyFailed) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr(
                  'This browser didn\'t allow copying. Long-press the ID or password above to select and copy it.',
                ),
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              tr(
                'Give these to {0}. They will be asked to set their own password at the first sign-in. The password is shown only once.',
                [user.firstName],
              ),
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final bool copied;
  final VoidCallback onCopy;

  const _CopyField({
    required this.label,
    required this.value,
    required this.copied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.cardMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                SelectableText(
                  value,
                  style: context.text.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: Icon(
              copied ? Icons.check : Icons.copy_outlined,
              size: 18,
              color: copied ? AppColors.success : null,
            ),
            label: Text(
              copied ? tr('Copied') : tr('Copy'),
              style: TextStyle(color: copied ? AppColors.success : null),
            ),
          ),
        ],
      ),
    );
  }
}

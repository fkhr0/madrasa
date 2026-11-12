import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../institution/models/institution_model.dart';
import '../../institution/providers/institution_provider.dart';
import '../data/faq_data.dart';
import '../../../core/l10n/language.dart';

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffice = ref.watch(currentUserProvider).role == UserRole.admin;
    final school = ref.watch(institutionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Help and support'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          SectionHeader(title: tr('Common questions')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final faq in FaqData.items)
                  Theme(
                    // Removes ExpansionTile's default top/bottom lines.
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        tr(faq.question),
                        style: context.text.titleSmall,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      expandedAlignment: AlignmentDirectional.centerStart
                          .resolve(Directionality.of(context)),
                      children: [
                        Text(tr(faq.answer), style: context.text.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // The office is the school: it doesn't contact itself.
          if (!isOffice && school != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _SchoolContacts(school: school),
          ],
          if (school != null && school.appSupportEmail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            MenuGroup(
              title: tr('A problem with the app?'),
              children: [
                MenuTile(
                  icon: Icons.bug_report_outlined,
                  iconColor: AppColors.subjectPurple,
                  title: tr('Email the app team'),
                  subtitle: school.appSupportEmail,
                  onTap: () => _email(
                    context,
                    school.appSupportEmail,
                    subject: tr('Madrasa app: a problem'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The school's own phone, WhatsApp and email, as the office entered them
/// in School settings. Empty ones are left out.
class _SchoolContacts extends StatelessWidget {
  final InstitutionModel school;

  const _SchoolContacts({required this.school});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      if (school.phone.isNotEmpty)
        MenuTile(
          icon: Icons.phone_outlined,
          iconColor: AppColors.success,
          title: tr('Call the school'),
          subtitle: school.phone,
          onTap: () => callPhone(context, school.phone),
        ),
      if (school.whatsapp.isNotEmpty)
        MenuTile(
          icon: Icons.chat_outlined,
          iconColor: AppColors.success,
          title: tr('WhatsApp the school'),
          subtitle: school.whatsapp,
          onTap: () => _whatsApp(context, school.whatsapp),
        ),
      if (school.email.isNotEmpty)
        MenuTile(
          icon: Icons.mail_outline,
          iconColor: AppColors.info,
          title: tr('Email the school'),
          subtitle: school.email,
          onTap: () => _email(context, school.email),
        ),
    ];

    if (tiles.isEmpty) {
      return AppCard(
        child: Text(
          tr(
            "Your school hasn't added its phone or email yet. Ask at the "
            'school office.',
          ),
          style: context.text.bodyMedium?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      );
    }
    return MenuGroup(title: tr('Contact {0}', [school.name]), children: tiles);
  }
}

Future<void> _email(BuildContext context, String to, {String? subject}) async {
  final opened = await launchUrl(
    Uri(
      scheme: 'mailto',
      path: to,
      query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
    ),
  );
  if (!opened && context.mounted) {
    context.showMessage(tr('Write to {0} from your email app', [to]));
  }
}

/// wa.me wants the number in international form, digits only.
Future<void> _whatsApp(BuildContext context, String number) async {
  var digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  // 0770... (Iraqi local) → 964770...
  if (digits.startsWith('0')) digits = '964${digits.substring(1)}';
  final opened = await launchUrl(
    Uri.parse('https://wa.me/$digits'),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    context.showMessage(tr('WhatsApp {0} from your phone', [number]));
  }
}

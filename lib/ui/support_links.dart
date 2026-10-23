import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import 'account_screen.dart';
import 'app_shell.dart';

/// The website's support and policy pages (compliance story, Nigel
/// 2026-10-23), the same addresses given to App Store Connect and Google
/// Play.
abstract final class SupportLinks {
  static const site = 'https://knifeandaxethrower.com';
  static const email = 'kaat-support@knifeandaxethrower.com';
  static final support = Uri.parse('$site/support');
  static final privacy = Uri.parse('$site/privacy');
  static final terms = Uri.parse('$site/terms');
  static final deleteAccount = Uri.parse('$site/delete-account');
  static final mail = Uri(scheme: 'mailto', path: email, query: 'subject=Thrower%20support');
}

/// Opens a link in the browser or the mail app; false if it couldn't.
/// Tests override [linkOpenerProvider].
typedef LinkOpener = Future<bool> Function(Uri uri);

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// Setup → Help and support: Instructions, Support (email us), the Privacy
/// Policy and Terms of Service, and Delete account (compliance story; as
/// WhereWillWeVisit's support page).
class HelpAndSupportCard extends ConsumerWidget {
  const HelpAndSupportCard({super.key, required this.instructions});

  /// The Instructions tile (Setup builds it).
  final Widget instructions;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await ref.read(linkOpenerProvider)(uri)) return;
    messenger.showSnackBar(SnackBar(
      key: const Key('supportLinkFailed'),
      content: Text("Couldn't open it. It's at ${uri.scheme == 'mailto' ? SupportLinks.email : uri}."),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ListTile link(String key, IconData icon, String title, String subtitle, Uri uri) => ListTile(
          key: Key(key),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open(context, ref, uri),
        );
    return Card(
      child: Column(
        children: [
          instructions,
          const Divider(height: 1),
          link('supportEmail', Icons.mail_outline, 'Support', 'Email us: ${SupportLinks.email}', SupportLinks.mail),
          const Divider(height: 1),
          link('supportHelpPage', Icons.help_outline, 'Help online', 'Common questions', SupportLinks.support),
          const Divider(height: 1),
          link('supportPrivacy', Icons.privacy_tip_outlined, 'Privacy Policy', 'What the app keeps, and where',
              SupportLinks.privacy),
          const Divider(height: 1),
          link('supportTerms', Icons.gavel_outlined, 'Terms of Service', 'Including safety', SupportLinks.terms),
          const Divider(height: 1),
          ListTile(
            key: const Key('supportDeleteAccount'),
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Delete account'),
            subtitle: const Text('Your account and its backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openScreen(context, ref, deleteAccountScreen(accounts: ref.read(authServiceProvider) != null)),
          ),
        ],
      ),
    );
  }
}

/// Where Delete account goes: the Account screen (with Delete account) in a
/// build with accounts; otherwise [NoAccountScreen].
Widget deleteAccountScreen({required bool accounts}) => accounts ? const AccountScreen() : const NoAccountScreen();

/// Delete account in a build without accounts: there's nothing held about
/// you; the sessions are on this phone only.
class NoAccountScreen extends ConsumerWidget {
  const NoAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('There is no account on this phone', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Thrower holds nothing about you: your sessions and player names are kept only on this phone. '
            'To delete your sessions, open History and tap Clear history. Deleting the app removes everything, '
            'player names included.',
            key: Key('noAccountText'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scores you posted to a leaderboard are kept by Apple Game Center under your Game Center nickname. '
            "You can sign out of Game Center, or change your nickname, in the iPhone's Settings.",
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('noAccountWebsite'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Delete Your Account (website)'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await ref.read(linkOpenerProvider)(SupportLinks.deleteAccount)) return;
              messenger.showSnackBar(SnackBar(
                key: const Key('supportLinkFailed'),
                content: Text("Couldn't open it. It's at ${SupportLinks.deleteAccount}."),
              ));
            },
          ),
        ],
      ),
    );
  }
}

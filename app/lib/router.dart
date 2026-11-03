import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/account_page.dart';
import 'pages/campaign_editor_page.dart';
import 'pages/campaigns_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/history_page.dart';
import 'pages/login_page.dart';
import 'pages/recipients_page.dart';
import 'pages/send_console_page.dart';
import 'pages/settings_page.dart';
import 'pages/shell.dart';
import 'pages/users_page.dart';
import 'services/session.dart';

/// Transition douce (fondu + léger glissement) entre les pages.
Page<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(opacity: curved, child: child);
  },
);

GoRouter buildRouter(Session session) => GoRouter(
  initialLocation: '/',
  refreshListenable: session,
  redirect: (context, state) {
    final location = state.matchedLocation;
    final onLogin = location == '/login';
    if (!session.isSignedIn) return onLogin ? null : '/login';
    if (onLogin) return '/';
    // Pages d'administration
    if ((location.startsWith('/users') || location.startsWith('/settings')) && !session.isAdmin) return '/';
    if (location == '/campaigns/new' && !session.canEdit) return '/campaigns';
    return null;
  },
  routes: [
    GoRoute(path: '/login', pageBuilder: (context, state) => _page(state, const LoginPage())),
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _page(state, const DashboardPage())),
        GoRoute(
          path: '/campaigns',
          pageBuilder: (context, state) => _page(state, const CampaignsPage()),
          routes: [
            GoRoute(path: 'new', pageBuilder: (context, state) => _page(state, const CampaignEditorPage())),
            GoRoute(
              path: ':id',
              pageBuilder: (context, state) => _page(state, CampaignEditorPage(campaignId: state.pathParameters['id'])),
            ),
          ],
        ),
        GoRoute(
          path: '/jobs/:id',
          pageBuilder: (context, state) => _page(state, SendConsolePage(jobId: state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/recipients',
          pageBuilder: (context, state) =>
              _page(state, RecipientsPage(initialTable: state.uri.queryParameters['table'])),
        ),
        GoRoute(path: '/history', pageBuilder: (context, state) => _page(state, const HistoryPage())),
        GoRoute(
          path: '/users',
          pageBuilder: (context, state) =>
              _page(state, UsersPage(openCreate: state.uri.queryParameters['new'] == '1')),
        ),
        GoRoute(path: '/settings', pageBuilder: (context, state) => _page(state, const SettingsPage())),
        GoRoute(path: '/account', pageBuilder: (context, state) => _page(state, const AccountPage())),
      ],
    ),
  ],
);

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/session.dart';

class NavDest {
  const NavDest(
    this.path,
    this.label,
    this.icon,
    this.activeIcon, {
    this.minRole = Role.viewer,
    this.admin = false,
    this.keywords = '',
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Role minRole;

  /// Rangée dans la section « Administration ».
  final bool admin;
  final String keywords;
}

const destinations = [
  NavDest(
    '/',
    'Tableau de bord',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard_rounded,
    keywords: 'accueil stats',
  ),
  NavDest('/campaigns', 'Campagnes', Icons.campaign_outlined, Icons.campaign_rounded, keywords: 'emails modeles'),
  NavDest('/recipients', 'Destinataires', Icons.people_alt_outlined, Icons.people_alt_rounded, keywords: 'tables base'),
  NavDest('/history', 'Historique', Icons.history_rounded, Icons.history_rounded, keywords: 'envois journal'),
  NavDest(
    '/users',
    'Utilisateurs',
    Icons.manage_accounts_outlined,
    Icons.manage_accounts_rounded,
    minRole: Role.admin,
    admin: true,
    keywords: 'equipe comptes roles',
  ),
  NavDest(
    '/settings',
    'Paramètres',
    Icons.tune_rounded,
    Icons.tune_rounded,
    minRole: Role.admin,
    admin: true,
    keywords: 'smtp mysql configuration',
  ),
];

List<NavDest> visibleDestinations(Session session) => destinations.where((d) => session.can(d.minRole)).toList();

/// Destination active pour un chemin (la console d'envoi dépend de l'historique).
NavDest? destinationFor(String location) {
  if (location.startsWith('/jobs')) return destinations[3];
  if (location == '/') return destinations.first;
  for (final d in destinations.skip(1)) {
    if (location.startsWith(d.path)) return d;
  }
  return null;
}

String titleFor(String location) {
  if (location == '/campaigns/new') return 'Nouvelle campagne';
  if (location.startsWith('/campaigns/')) return 'Campagne';
  if (location.startsWith('/jobs/')) return 'Console d’envoi';
  if (location.startsWith('/account')) return 'Mon compte';
  return destinationFor(location)?.label ?? 'Mailler Studio';
}

import 'package:battle_master_admin/screens/admin_users_screen.dart';
import 'package:battle_master_admin/screens/coin_add_screen.dart';
import 'package:battle_master_admin/screens/create_tournament_screen.dart';
import 'package:battle_master_admin/screens/delete_tournament_screen.dart';
import 'package:battle_master_admin/screens/manage_tournament_screen.dart';
import 'package:battle_master_admin/screens/payment_requests_screen.dart';
import 'package:battle_master_admin/admin_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:battle_master_admin/screens/admin_contact_us_screen.dart';
import 'package:battle_master_admin/screens/admin_banner_screen.dart';
// 🌟 NAYA IMPORT YAHAN HAI 🌟
import 'package:battle_master_admin/screens/verify_matches_screen.dart';

class DashboardHomeWidget extends StatelessWidget {
  const DashboardHomeWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Dashboard Home"));
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isExpanded = true; 

  // 🌟 SCREENS LIST UPDATE KAR DI GAYI HAI 🌟
  static const List<Widget> _screens = [
    DashboardHomeWidget(),          // 0
    CreateTournamentScreen(),       // 1
    ManageTournamentScreen(),       // 2
    VerifyMatchesScreen(),          // 3 (🌟 NAYI SCREEN YAHAN ADD KI HAI)
    DeleteTournamentScreen(),       // 4
    CoinAddScreen(),                // 5
    PaymentRequestsScreen(),        // 6
    AdminUsersScreen(),             // 7
    AdminSettingsPage(),            // 8
    AdminContactUsScreen(),         // 9
    AdminBannerScreen(),            // 10
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
      ),
      body: Row(
        children: <Widget>[
          if (_isExpanded) ...[
            NavigationRail(
              selectedIndex: _selectedIndex,
              extended: true, 
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: Text('Create Match'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.edit_document),
                  selectedIcon: Icon(Icons.edit_document),
                  label: Text('Manage Match'),
                ),
                // 🌟 NAYA MENU OPTION YAHAN ADD KIYA HAI 🌟
                NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: Text('Verify Matches'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.delete_forever_outlined),
                  selectedIcon: Icon(Icons.delete_forever),
                  label: Text('Delete Match'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.monetization_on_outlined),
                  selectedIcon: Icon(Icons.monetization_on),
                  label: Text('Add Coins'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.payment_outlined),
                  selectedIcon: Icon(Icons.payment),
                  label: Text('Payments'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.contact_support_outlined),
                  selectedIcon: Icon(Icons.contact_support),
                  label: Text('Contact Us'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.image_outlined),
                  selectedIcon: Icon(Icons.image),
                  label: Text('Banners'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
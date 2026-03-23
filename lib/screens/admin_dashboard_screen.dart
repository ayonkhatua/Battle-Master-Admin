import 'package:battle_master_admin/screens/admin_users_screen.dart';
import 'package:battle_master_admin/screens/coin_add_screen.dart';
import 'package:battle_master_admin/screens/create_tournament_screen.dart';
import 'package:battle_master_admin/screens/delete_tournament_screen.dart';
import 'package:battle_master_admin/screens/manage_tournament_screen.dart';
import 'package:battle_master_admin/screens/payment_requests_screen.dart';
import 'package:flutter/material.dart';

// ... (DashboardHomeWidget wahi rahega)
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
  bool _isExpanded = false;

  static const List<Widget> _screens = [
    DashboardHomeWidget(), // 0
    CreateTournamentScreen(), // 1
    ManageTournamentScreen(), // 2
    DeleteTournamentScreen(), // 3
    CoinAddScreen(), // 4
    PaymentRequestsScreen(), // 5 (Naya)
    AdminUsersScreen(), // 6
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
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: _isExpanded,
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
                label: Text('Payments'), // Naya Menu Item
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: Text('Users'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}

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
import 'package:battle_master_admin/screens/verify_matches_screen.dart';
import 'package:battle_master_admin/screens/host_approval_screen.dart'; 
// 🌟 SUPABASE & LOGIN SCREEN IMPORT KIYA LOGOUT KE LIYE 🌟
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:battle_master_admin/screens/admin_login_screen.dart';

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

  static const List<Widget> _screens = [
    DashboardHomeWidget(),          // 0
    CreateTournamentScreen(),       // 1
    ManageTournamentScreen(),       // 2
    VerifyMatchesScreen(),          // 3
    DeleteTournamentScreen(),       // 4
    CoinAddScreen(),                // 5
    PaymentRequestsScreen(),        // 6
    AdminUsersScreen(),             // 7
    HostApprovalScreen(),           // 8 
    AdminSettingsPage(),            // 9
    AdminContactUsScreen(),         // 10
    AdminBannerScreen(),            // 11
  ];

  // 🌟 LOGOUT FUNCTION 🌟
  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        // Supabase se sign out
        await Supabase.instance.client.auth.signOut();
        
        // Login Screen par bhejo aur pichli saari screens hata do
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => const AdminLoginScreen()), 
            (route) => false
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

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
        // 🌟 LOGOUT BUTTON APPBAR MEIN ADD KIYA 🌟
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 10),
        ],
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
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: Text('Host Approvals'),
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
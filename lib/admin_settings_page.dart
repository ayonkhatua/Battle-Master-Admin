import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // State variables
  bool _isMaintenanceMode = false;
  bool _isNewUpdateAvailable = false;
  bool _isLoading = true;

  final TextEditingController _appLinkController = TextEditingController();
  final TextEditingController _appVersionController = TextEditingController();

  @override
  void dispose() {
    _appLinkController.dispose();
    _appVersionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _isMaintenanceMode = data['is_maintenance_on'] ?? false;
          _isNewUpdateAvailable = data['is_update_available'] ?? false;
          _appVersionController.text = data['latest_app_version'] ?? '';
          _appLinkController.text = data['app_link'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Real-time Maintenance Mode Toggle Function
  Future<void> _toggleMaintenanceMode(bool value) async {
    setState(() {
      _isMaintenanceMode = value;
    });

    try {
      await Supabase.instance.client
          .from('app_config')
          .update({'is_maintenance_on': value})
          .eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Maintenance Mode ON ho gaya hai'
                  : 'Maintenance Mode OFF ho gaya hai',
            ),
            backgroundColor: value ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isMaintenanceMode = !value; // Revert switch if error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // App Update details save karne ka function
  Future<void> _saveAppUpdateDetails() async {
    final String link = _appLinkController.text;
    final String version = _appVersionController.text;

    try {
      await Supabase.instance.client
          .from('app_config')
          .update({
            'is_update_available': _isNewUpdateAvailable,
            'app_link': link,
            'latest_app_version': version,
          })
          .eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App Update settings save ho gayi hain!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Match blueprint background
      appBar: AppBar(
        title: const Text(
          'Admin Settings',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Maintenance Mode Section
                  const Text(
                    'System Controls',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: const Color(0xFF1E1E1E), // Match blueprint card
                    elevation: 2,
                    child: SwitchListTile(
                      title: const Text(
                        'Maintenance Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'Isko ON karte hi app users ke liye turant band ho jayegi.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      value: _isMaintenanceMode,
                      onChanged: _toggleMaintenanceMode,
                      activeThumbColor: Colors.red,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 2. App Update Section
                  const Text(
                    'App Update Controls',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: const Color(0xFF1E1E1E),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'New Update Available',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Force update dialog dikhane ke liye isko ON karein',
                              style: TextStyle(color: Colors.grey),
                            ),
                            value: _isNewUpdateAvailable,
                            onChanged: (bool value) {
                              setState(() {
                                _isNewUpdateAvailable = value;
                              });
                            },
                            activeThumbColor: Colors.red,
                            inactiveThumbColor: Colors.grey,
                          ),
                          const Divider(color: Colors.grey),
                          TextField(
                            controller: _appVersionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Latest App Version (e.g., 1.0.5)',
                              labelStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _appLinkController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'App PlayStore / Download Link',
                              labelStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.link, color: Colors.grey),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveAppUpdateDetails,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text('Save Update Info'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

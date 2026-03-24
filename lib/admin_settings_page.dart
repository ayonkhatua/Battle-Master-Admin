import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase use karne ke liye isko uncomment karein

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // State variables
  bool _isMaintenanceMode = false;
  bool _isNewUpdateAvailable = false;

  final TextEditingController _appLinkController = TextEditingController();
  final TextEditingController _appVersionController = TextEditingController();

  @override
  void dispose() {
    _appLinkController.dispose();
    _appVersionController.dispose();
    super.dispose();
  }

  // Real-time Maintenance Mode Toggle Function
  void _toggleMaintenanceMode(bool value) {
    setState(() {
      _isMaintenanceMode = value;
    });

    // TODO: Firebase real-time database ya Firestore update code yahan likhein
    /*
    FirebaseFirestore.instance.collection('app_settings').doc('config').update({
      'maintenance_mode': value,
    });
    */

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

  // App Update details save karne ka function
  void _saveAppUpdateDetails() {
    final String link = _appLinkController.text;
    final String version = _appVersionController.text;

    // TODO: Firebase me update details save karne ka code
    /*
    FirebaseFirestore.instance.collection('app_settings').doc('update_info').set({
      'update_available': _isNewUpdateAvailable,
      'app_link': link,
      'latest_version': version,
    });
    */

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App Update settings save ho gayi hain!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Maintenance Mode Section
            const Text(
              'System Controls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: SwitchListTile(
                title: const Text(
                  'Maintenance Mode',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Isko ON karte hi app users ke liye turant band ho jayegi.',
                ),
                value: _isMaintenanceMode,
                onChanged: _toggleMaintenanceMode,
                activeThumbColor: Colors.red,
              ),
            ),
            const SizedBox(height: 30),

            // 2. App Update Section
            const Text(
              'App Update Controls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('New Update Available'),
                      subtitle: const Text(
                        'Force update dialog dikhane ke liye isko ON karein',
                      ),
                      value: _isNewUpdateAvailable,
                      onChanged: (bool value) {
                        setState(() {
                          _isNewUpdateAvailable = value;
                        });
                      },
                    ),
                    const Divider(),
                    TextField(
                      controller: _appVersionController,
                      decoration: const InputDecoration(
                        labelText: 'Latest App Version (e.g., 1.0.5)',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _appLinkController,
                      decoration: const InputDecoration(
                        labelText: 'App PlayStore / Download Link',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAppUpdateDetails,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Update Info'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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

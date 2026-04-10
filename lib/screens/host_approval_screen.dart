import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HostApprovalScreen extends StatefulWidget {
  const HostApprovalScreen({super.key});

  @override
  _HostApprovalScreenState createState() => _HostApprovalScreenState();
}

class _HostApprovalScreenState extends State<HostApprovalScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hosts = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchHosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 📥 Fetch all hosts from database
  Future<void> _fetchHosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('host_profiles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _hosts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching hosts: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to load hosts: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🔄 Update Host Status (Approve / Reject)
  Future<void> _updateStatus(String hostId, String newStatus) async {
    // Confirmation Dialog
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1e293b),
        title: Text("Confirm Action", style: const TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to mark this host as '$newStatus'?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("YES", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // Show loading indicator in dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFfacc15))),
      );

      // Update in Supabase
      await Supabase.instance.client
          .from('host_profiles')
          .update({'status': newStatus})
          .eq('id', hostId);

      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Host marked as $newStatus"), backgroundColor: Colors.green),
      );
      
      _fetchHosts(); // Refresh the list

    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Update failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1e293b),
        title: const Text("Host Approvals", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFfacc15),
          labelColor: const Color(0xFFfacc15),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Waiting"),
            Tab(text: "Approved"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFfacc15)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHostList('waiting'),
                _buildHostList('approved'),
                _buildHostList('rejected'),
              ],
            ),
    );
  }

  // 📝 Build List based on Status Tab
  Widget _buildHostList(String statusFilter) {
    final filteredHosts = _hosts.where((h) => h['status'] == statusFilter).toList();

    if (filteredHosts.isEmpty) {
      return Center(
        child: Text("No $statusFilter hosts found.", style: const TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredHosts.length,
      itemBuilder: (context, index) {
        final host = filteredHosts[index];
        return _buildHostCard(host);
      },
    );
  }

  // 💳 Host Card UI
  Widget _buildHostCard(Map<String, dynamic> host) {
    DateTime createdAt = DateTime.tryParse(host['created_at'].toString())?.toLocal() ?? DateTime.now();
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
    String status = host['status'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1e293b),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Email & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person, color: Color(0xFF94a3b8), size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host['email'] ?? 'No Email', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Applied: $formattedDate", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          
          const Divider(color: Color(0xFF374151), height: 30),

          // Row 2: Details (Balances & UPI)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem("Available", "🪙 ${host['available_balance']}", Colors.greenAccent),
              _buildDetailItem("Pending", "⏳ ${host['pending_balance']}", Colors.orangeAccent),
              _buildDetailItem("UPI ID", host['upi_id']?.toString().isNotEmpty == true ? host['upi_id'] : "Not set", Colors.white),
            ],
          ),

          // Row 3: Action Buttons
          if (status == 'waiting') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.2), side: const BorderSide(color: Colors.redAccent)),
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    label: const Text("REJECT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onPressed: () => _updateStatus(host['id'], 'rejected'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.2), side: const BorderSide(color: Colors.green)),
                    icon: const Icon(Icons.check, color: Colors.green, size: 18),
                    label: const Text("APPROVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    onPressed: () => _updateStatus(host['id'], 'approved'),
                  ),
                ),
              ],
            ),
          ] else if (status == 'approved') ...[
            const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.block, color: Colors.redAccent, size: 16),
                label: const Text("Revoke Approval (Reject)", style: TextStyle(color: Colors.redAccent)),
                onPressed: () => _updateStatus(host['id'], 'rejected'),
              ),
            )
          ] else if (status == 'rejected') ...[
             const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                label: const Text("Approve Host", style: TextStyle(color: Colors.green)),
                onPressed: () => _updateStatus(host['id'], 'approved'),
              ),
            )
          ]
        ],
      ),
    );
  }

  // Helper: Status Badge
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'approved':
        bgColor = Colors.green.withOpacity(0.2);
        textColor = Colors.greenAccent;
        text = "APPROVED";
        break;
      case 'rejected':
        bgColor = Colors.red.withOpacity(0.2);
        textColor = Colors.redAccent;
        text = "REJECTED";
        break;
      default:
        bgColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orangeAccent;
        text = "WAITING";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // Helper: Detail Item (Bal/UPI)
  Widget _buildDetailItem(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
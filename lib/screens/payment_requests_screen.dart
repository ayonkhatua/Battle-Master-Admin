import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PaymentRequestsScreen extends StatefulWidget {
  const PaymentRequestsScreen({super.key});

  @override
  State<PaymentRequestsScreen> createState() => _PaymentRequestsScreenState();
}

class _PaymentRequestsScreenState extends State<PaymentRequestsScreen> {
  // ValueNotifier for manual refresh
  final ValueNotifier<int> _requestListRefresher = ValueNotifier<int>(0);

  final TextEditingController _upiController = TextEditingController();
  bool _isLoadingUpi = true;
  bool _isSavingUpi = false;

  @override
  void initState() {
    super.initState();
    _fetchUpiId();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _requestListRefresher.dispose();
    super.dispose();
  }

  // Fetch existing UPI ID from the database
  Future<void> _fetchUpiId() async {
    try {
      final data = await Supabase.instance.client
          .from('app_config')
          .select('upi_id')
          .eq('id', 1)
          .maybeSingle();

      if (data != null && data['upi_id'] != null) {
        _upiController.text = data['upi_id'];
      }
    } catch (e) {
      debugPrint('Error fetching UPI: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUpi = false;
        });
      }
    }
  }

  // Save or update the UPI ID in the database
  Future<void> _updateUpiId() async {
    setState(() {
      _isSavingUpi = true;
    });

    try {
      final upi = _upiController.text.trim();

      final existingData = await Supabase.instance.client
          .from('app_config')
          .select('id')
          .eq('id', 1)
          .maybeSingle();

      if (existingData == null) {
        await Supabase.instance.client.from('app_config').insert({
          'id': 1,
          'upi_id': upi,
        });
      } else {
        await Supabase.instance.client
            .from('app_config')
            .update({'upi_id': upi})
            .eq('id', 1);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ UPI ID updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUpi = false;
        });
      }
    }
  }

  // Fetch pending credit requests along with user details
  Future<List<Map<String, dynamic>>> _fetchPendingCredits() async {
    final response = await Supabase.instance.client
        .from('transactions')
        .select('id, amount, status, created_at, users(username, email)')
        .eq('type', 'credit')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Call the stored procedure to approve or reject
  Future<void> _handleRequest(int txId, String action) async {
    if (!mounted) return;

    try {
      final result = await Supabase.instance.client.rpc(
        'approve_reject_credit',
        params: {'p_tx_id': txId, 'p_action': action},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.toString()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Refresh the list
    _requestListRefresher.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Wallet Credit Requests'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildUpiBox(),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _requestListRefresher,
              builder: (context, _, __) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchPendingCredits(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No pending credit requests found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final requests = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final user = request['users']; // Nested user object
                        final formattedDate = DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(DateTime.parse(request['created_at']));

                        return Card(
                          color: const Color(0xFF1E1E1E),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User: ${user?['username'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Email: ${user?['email'] ?? 'N/A'}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                Text.rich(
                                  TextSpan(
                                    text: 'Amount: ',
                                    style: const TextStyle(color: Colors.white),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: '₹${request['amount']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Requested At: $formattedDate',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _handleRequest(
                                        request['id'],
                                        'reject',
                                      ),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[800],
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => _handleRequest(
                                        request['id'],
                                        'approve',
                                      ),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiBox() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin UPI ID (App Users Will Pay Here)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter UPI ID (e.g., name@okaxis)',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoadingUpi || _isSavingUpi
                          ? null
                          : _updateUpiId,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSavingUpi
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SAVE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

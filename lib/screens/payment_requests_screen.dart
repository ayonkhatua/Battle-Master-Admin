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

  @override
  void dispose() {
    _requestListRefresher.dispose();
    super.dispose();
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
      final result = await Supabase.instance.client.rpc('approve_reject_credit', params: {
        'p_tx_id': txId,
        'p_action': action,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.toString()),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $errorMsg'),
        backgroundColor: Colors.red,
      ));
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
      body: ValueListenableBuilder<int>(
        valueListenable: _requestListRefresher,
        builder: (context, _, __) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchPendingCredits(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending credit requests found.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final requests = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final user = request['users']; // Nested user object
                  final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                      .format(DateTime.parse(request['created_at']));

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User: ${user?['username'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('Email: ${user?['email'] ?? 'N/A'}'),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              text: 'Amount: ',
                              children: <TextSpan>[
                                TextSpan(
                                  text: '₹${request['amount']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          Text('Requested At: $formattedDate'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _handleRequest(request['id'], 'reject'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _handleRequest(request['id'], 'approve'),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
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
    );
  }
}
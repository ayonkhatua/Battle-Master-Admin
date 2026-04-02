import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PaymentRequestsScreen extends StatefulWidget {
  const PaymentRequestsScreen({super.key});

  @override
  State<PaymentRequestsScreen> createState() => _PaymentRequestsScreenState();
}

class _PaymentRequestsScreenState extends State<PaymentRequestsScreen> {
  // ValueNotifiers for manual & auto refresh
  final ValueNotifier<int> _depositRefresher = ValueNotifier<int>(0);
  final ValueNotifier<int> _withdrawRefresher = ValueNotifier<int>(0);

  final TextEditingController _upiController = TextEditingController();
  bool _isLoadingUpi = true;
  bool _isSavingUpi = false;

  late final RealtimeChannel _txnChannel;

  @override
  void initState() {
    super.initState();
    _fetchUpiId();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _txnChannel = Supabase.instance.client.channel('public:transactions');
    _txnChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            _depositRefresher.value++;
            _withdrawRefresher.value++;
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_txnChannel);
    _upiController.dispose();
    _depositRefresher.dispose();
    _withdrawRefresher.dispose();
    super.dispose();
  }

  // --- UPI ID FETCH & SAVE ---
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
      if (mounted) setState(() => _isLoadingUpi = false);
    }
  }

  Future<void> _updateUpiId() async {
    setState(() => _isSavingUpi = true);
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

      _showSnackBar('✅ UPI ID updated successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingUpi = false);
    }
  }

  // --- FETCH DATA LOGIC ---
  Future<List<Map<String, dynamic>>> _fetchRequests(List<String> types) async {
    final response = await Supabase.instance.client
        .from('transactions')
        .select(
          'id, amount, status, created_at, txn_ref, user_id, users(username, email)',
        )
        .inFilter('type', types)
        .eq('status', 'pending')
        .order('created_at', ascending: true); // FIFO Queue

    return List<Map<String, dynamic>>.from(response);
  }

  // --- HANDLE ADD COIN (DEPOSIT) ---
  // 🌟 NAYA FIX: Ab humein pura request map mil raha hai calculation ke liye
  Future<void> _handleDeposit(Map<String, dynamic> request, String action) async {
    try {
      final txId = request['id'];
      final userId = request['user_id'];
      final amount = request['amount'] ?? 0;

      // 1. Transaction status update karo
      await Supabase.instance.client
          .from('transactions')
          .update({'status': action})
          .eq('id', txId);

      // 2. Agar Accept kiya hai, toh user ko paise do!
      if (action == 'approved') {
        // User ka purana balance mangwao
        final userData = await Supabase.instance.client
            .from('users')
            .select('wallet_balance, deposited')
            .eq('id', userId)
            .single();

        int currentBalance = userData['wallet_balance'] ?? 0;
        int currentDeposited = userData['deposited'] ?? 0;

        // Paise Plus (+) karke wapas save kar do
        await Supabase.instance.client.from('users').update({
          'wallet_balance': currentBalance + amount,
          'deposited': currentDeposited + amount,
        }).eq('id', userId);
      }

      String actionText = action == 'approved' ? 'Approved & Coins Added' : 'Rejected';
      _showSnackBar("✅ Deposit $actionText successfully!", Colors.green);
    } catch (e) {
      _showSnackBar('❌ Error: ${e.toString()}', Colors.red);
    }
    _depositRefresher.value++;
  }

  // --- HANDLE WITHDRAWAL ---
  // 🌟 NAYA FIX: Withdraw accept/reject logic
  Future<void> _handleWithdraw(Map<String, dynamic> request, String action) async {
    try {
      final txId = request['id'];
      final userId = request['user_id'];
      final amount = request['amount'] ?? 0;

      // 1. Transaction status update karo
      await Supabase.instance.client
          .from('transactions')
          .update({'status': action})
          .eq('id', txId);

      // User ka current data mangwa lo
      final userData = await Supabase.instance.client
          .from('users')
          .select('wallet_balance, total_withdrawn')
          .eq('id', userId)
          .single();

      // 2. Agar Admin ne Reject (Cancel) kar diya, toh paise Refund karo
      if (action == 'rejected') {
        int currentBalance = userData['wallet_balance'] ?? 0;
        await Supabase.instance.client.from('users').update({
          'wallet_balance': currentBalance + amount, // Paise wapas de diye
        }).eq('id', userId);
      } 
      // 3. Agar Approve kiya, toh bas Record mein likh do ki usne kitna nikal liya (History)
      else if (action == 'approved') {
        int currentWithdrawn = userData['total_withdrawn'] ?? 0;
        await Supabase.instance.client.from('users').update({
          'total_withdrawn': currentWithdrawn + amount,
        }).eq('id', userId);
      }

      _showSnackBar(
        action == 'approved'
            ? "💸 Payment marked as PAID!"
            : "❌ Request Rejected (Refunded to Wallet)",
        action == 'approved' ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar('❌ Error: ${e.toString()}', Colors.red);
    }
    _withdrawRefresher.value++;
  }

  void _showSnackBar(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        appBar: AppBar(
          title: const Text(
            'TRANSACTION REQUESTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF0F172A),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            indicatorWeight: 3,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "ADD COIN (IN)"),
              Tab(text: "WITHDRAW (OUT)"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildUpiBox(),
                Expanded(
                  child: _buildListWidget(
                    ['deposit', 'credit'],
                    _depositRefresher,
                    _handleDeposit,
                  ),
                ),
              ],
            ),
            _buildListWidget(['withdraw'], _withdrawRefresher, _handleWithdraw),
          ],
        ),
      ),
    );
  }

  // 🌟 NAYA FIX: actionHandler ab ID ki jagah pura 'request' object bhej raha hai
  Widget _buildListWidget(
    List<String> types,
    ValueNotifier<int> refresher,
    Function(Map<String, dynamic>, String) actionHandler,
  ) {
    bool isDeposit = types.contains('deposit');

    return ValueListenableBuilder<int>(
      valueListenable: refresher,
      builder: (context, _, __) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRequests(types),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  isDeposit
                      ? 'No pending coin requests. 🎉'
                      : 'No pending withdraw requests. 🎉',
                  style: const TextStyle(fontSize: 16, color: Colors.white54),
                ),
              );
            }

            final requests = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final user = request['users'];

                final formattedDate = DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format(DateTime.parse(request['created_at']).toLocal());
                final txnRef = request['txn_ref'] ?? 'N/A';
                final amount = request['amount']?.toString() ?? '0';

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDeposit
                          ? Colors.blueAccent.withOpacity(0.3)
                          : Colors.redAccent.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isDeposit
                                        ? Icons.person_add
                                        : Icons.account_balance_wallet,
                                    color: isDeposit
                                        ? Colors.blueAccent
                                        : Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      user?['username']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'UNKNOWN USER',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amberAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on,
                                    color: Colors.amberAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDeposit ? '+ $amount' : '- $amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: isDeposit
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 25),
                        _buildDetailRow(
                          Icons.email,
                          'Email:',
                          user?['email'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          isDeposit ? Icons.receipt_long : Icons.payment,
                          isDeposit
                              ? 'User Txn ID (UTR):'
                              : 'Pay to this UPI/No:',
                          txnRef,
                          isHighlight: true,
                          highlightColor: isDeposit
                              ? Colors.amberAccent
                              : Colors.greenAccent,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.access_time,
                          'Date:',
                          formattedDate,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              icon: Icons.close,
                              label: "REJECT",
                              color: Colors.redAccent,
                              onTap: () => actionHandler(request, 'rejected'),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              icon: Icons.check,
                              label: isDeposit ? "APPROVE" : "MARK AS PAID",
                              color: Colors.greenAccent,
                              onTap: () => actionHandler(request, 'approved'),
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
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
    Color highlightColor = Colors.amberAccent,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isHighlight ? highlightColor : Colors.white,
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildUpiBox() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App UPI ID (Where users send money)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _upiController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'admin@upi',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.blueAccent,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoadingUpi || _isSavingUpi
                      ? null
                      : _updateUpiId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSavingUpi
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
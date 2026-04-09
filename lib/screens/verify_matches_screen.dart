import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifyMatchesScreen extends StatefulWidget {
  const VerifyMatchesScreen({super.key});

  @override
  State<VerifyMatchesScreen> createState() => _VerifyMatchesScreenState();
}

class _VerifyMatchesScreenState extends State<VerifyMatchesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingMatches = [];
  double? _lastUsedReward; // 🌟 Last entered value ko store karne ke liye

  @override
  void initState() {
    super.initState();
    _loadLastReward(); // Load saved value on start
    _fetchPendingApprovals();
  }

  // 🌟 NAYA LOGIC: SAVED VALUE LOAD KARO 🌟
  Future<void> _loadLastReward() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUsedReward = prefs.getDouble('last_admin_reward');
    });
  }

  // 🌟 1. FETCH UNAPPROVED COMPLETED MATCHES 🌟
  Future<void> _fetchPendingApprovals() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('tournaments')
          .select('*, host_profiles(email)')
          .eq('status', 'completed')
          .eq('admin_approved', false)
          .not('host_id', 'is', null)
          .order('end_time', ascending: false);

      if (mounted) {
        setState(() {
          _pendingMatches = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error loading matches: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 2. APPROVE MATCH & PAY HOST LOGIC 🌟
  Future<void> _approveAndPayHost(Map<String, dynamic> match, double rewardAmount) async {
    setState(() => _isLoading = true);
    try {
      final tid = match['id'];
      final hid = match['host_id'];

      await Supabase.instance.client
          .from('tournaments')
          .update({'admin_approved': true})
          .eq('id', tid);

      final profile = await Supabase.instance.client
          .from('host_profiles')
          .select('available_balance')
          .eq('id', hid)
          .single();
      
      double currentBalance = (profile['available_balance'] ?? 0).toDouble();

      await Supabase.instance.client
          .from('host_profiles')
          .update({'available_balance': currentBalance + rewardAmount})
          .eq('id', hid);

      // (SQL Policy set hone par ye ab fail nahi hoga)
      await Supabase.instance.client
          .from('host_transactions')
          .insert({
            'host_id': hid,
            'amount': rewardAmount,
            'transaction_type': 'reward',
            'status': 'available',
            'match_id': tid
          });

      // 🌟 NAYA LOGIC: SAVE THE VALUE FOR NEXT TIME 🌟
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_admin_reward', rewardAmount);
      _lastUsedReward = rewardAmount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Match Approved & Host Paid!'), backgroundColor: Colors.green),
        );
        _fetchPendingApprovals(); // Refresh list to remove the match
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error approving: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 REJECT FAKE MATCH 🌟
  Future<void> _rejectMatch(int tid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Reject Match?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to reject this match? The host will NOT receive any coins, and the match will be cancelled.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, REJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'status': 'cancelled', 
            'admin_approved': true, 
          })
          .eq('id', tid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚫 Match Rejected! Host gets 0 coins.'), backgroundColor: Colors.redAccent),
        );
        _fetchPendingApprovals(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error rejecting match: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 3. SHOW REVIEW DIALOG 🌟
  void _showApprovalDialog(Map<String, dynamic> match) {
    final String hostEmail = match['host_profiles']?['email'] ?? 'Unknown Host';
    
    int entryFee = match['entry_fee'] ?? 0;
    int filled = match['filled'] ?? 0;
    int prizePool = match['prize_pool'] ?? 0;
    int totalCollection = entryFee * filled;
    int estimatedProfit = totalCollection - prizePool;

    // 🌟 SMART DEFAULT CALCULATION 🌟
    // Agar pichli baar koi value save ki thi, toh wo dikhao. 
    // Warna profit ka 40% dikhao.
    double defaultReward = _lastUsedReward ?? (estimatedProfit > 0 ? (estimatedProfit * 0.40) : 0.0);
    final rewardController = TextEditingController(text: defaultReward.toStringAsFixed(0)); // Decimal hatane ke liye

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Approve Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tournament: ${match['title']} (#${match['id']})', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Host: $hostEmail', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: 24),
              
              Text('💰 Total Collected: 🪙$totalCollection', style: const TextStyle(color: Colors.grey)),
              Text('🏆 Distributed Prize: 🪙$prizePool', style: const TextStyle(color: Colors.grey)),
              Text('📈 Estimated App Profit: 🪙$estimatedProfit', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 20),
              const Text('Set Host Commission (Reward)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: rewardController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. 50',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.monetization_on, color: Colors.orangeAccent),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastUsedReward != null ? 'Using your last saved amount.' : 'Suggested 40% of profit.', 
                style: const TextStyle(color: Colors.grey, fontSize: 12)
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () {
              final reward = double.tryParse(rewardController.text.trim());
              if (reward == null || reward < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid reward amount.')));
                return;
              }
              Navigator.pop(context);
              _approveAndPayHost(match, reward);
            },
            child: const Text('APPROVE & PAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("VERIFY MATCHES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.greenAccent),
            onPressed: _fetchPendingApprovals,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _pendingMatches.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _pendingMatches.length,
                  itemBuilder: (context, index) {
                    final match = _pendingMatches[index];
                    return _buildMatchApprovalCard(match);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text("No Pending Approvals", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("All completed matches have been verified.", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMatchApprovalCard(Map<String, dynamic> match) {
    final String hostEmail = match['host_profiles']?['email'] ?? 'Unknown Host';
    DateTime? endTime;
    if (match['end_time'] != null) {
      endTime = DateTime.parse(match['end_time']).toLocal();
    }
    final String formattedDate = endTime != null ? DateFormat('dd MMM, hh:mm a').format(endTime) : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${match['title']} (#${match['id']})',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('NEEDS REVIEW', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text('Host: $hostEmail', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text('Finished: $formattedDate', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          
          const Divider(color: Colors.white10, height: 24),
          
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () => _rejectMatch(match['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                  label: const Text('REJECT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _showApprovalDialog(match),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('REVIEW & APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
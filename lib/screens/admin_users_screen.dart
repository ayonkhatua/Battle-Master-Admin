import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ValueNotifier<int> _userListRefresher = ValueNotifier<int>(0);
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
        setState(() {
          _searchQuery = '';
          _userListRefresher.value++;
        });
      }
    });

    // Realtime Listener: Automatically refresh on database changes
    _channel = Supabase.instance.client
        .channel('public:users')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (payload) {
              _userListRefresher.value++;
            })
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _userListRefresher.dispose();
    Supabase.instance.client.removeChannel(_channel);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    var queryBuilder = Supabase.instance.client.from('users').select('*');

    if (_searchQuery.isNotEmpty) {
      // Fix: Correct Supabase `.or` syntax
      queryBuilder = queryBuilder.or(
        'username.ilike.%$_searchQuery%,mobile.ilike.%$_searchQuery%,email.ilike.%$_searchQuery%'
      );
    }

    final response = await queryBuilder.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _updateUserStatus(String userId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'status': newStatus}).eq('id', userId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ User status updated successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      final errorMsg = e is PostgrestException ? e.message : e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $errorMsg'),
          backgroundColor: Colors.red,
        ));
      }
    }
    _userListRefresher.value++;
  }

  void _onSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _userListRefresher.value++;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👥 Manage Users',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            
            // --- Search Section ---
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Search Users',
                          hintText: 'Search by username, email, or mobile...',
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56, // Match TextField height
                      child: ElevatedButton.icon(
                        onPressed: _onSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('SEARCH', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- User List ---
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _userListRefresher,
              builder: (context, _, __) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.red));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No users found.', style: TextStyle(color: Colors.grey, fontSize: 18)),
                      );
                    }

                    final users = snapshot.data!;
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final bool isActive = user['status'] == 'active';
                        final wallet = user['wallet_balance'] ?? 0;

                        return _buildUserCard(user, isActive, wallet);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isActive, dynamic wallet) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red[900]?.withOpacity(0.3),
              radius: 28,
              child: const Icon(Icons.person, color: Colors.redAccent, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'] ?? 'No Username',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${user['email'] ?? 'N/A'} | Mobile: ${user['mobile'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IGN: ${user['ign'] ?? 'N/A'} | Wallet: $wallet 🪙',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'BLOCKED',
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _updateUserStatus(user['id'], isActive ? 'blocked' : 'active'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.red[800] : Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                  label: Text(isActive ? 'BLOCK USER' : 'ACTIVATE USER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
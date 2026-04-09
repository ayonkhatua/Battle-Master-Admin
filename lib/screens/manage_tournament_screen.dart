import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantState {
  final Map<String, dynamic> participantData;
  final TextEditingController killsController;
  final TextEditingController coinsController;
  bool isWinner;

  ParticipantState(this.participantData)
    : killsController = TextEditingController(text: '0'),
      coinsController = TextEditingController(text: '0'),
      isWinner = false;

  String get ign =>
      participantData['user_ign'] ?? participantData['users']?['ign'] ?? 'N/A';

  String get userId => participantData['user_id'].toString();
}

class ManageTournamentScreen extends StatefulWidget {
  const ManageTournamentScreen({super.key});

  @override
  State<ManageTournamentScreen> createState() => _ManageTournamentScreenState();
}

class _ManageTournamentScreenState extends State<ManageTournamentScreen> {
  final _searchController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _roomPassController = TextEditingController();

  Map<String, dynamic>? _tournament;
  List<ParticipantState> _participants = [];
  String? _assignedHostEmail; // Host ka email dikhane ke liye
  bool _isLoading = false;
  String _message = "";

  // 🌟 ADMIN POWER: Load ANY Tournament 🌟
  Future<void> _loadTournament() async {
    final tid = int.tryParse(_searchController.text);
    if (tid == null) {
      setState(() => _message = "⚠️ Enter a valid Tournament ID");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
      _tournament = null;
      _participants = [];
      _assignedHostEmail = null;
    });

    try {
      // Fetch Tournament Details
      final tResponse = await Supabase.instance.client
          .from('tournaments')
          .select()
          .eq('id', tid)
          .single();

      // Fetch Participants
      final pResponse = await Supabase.instance.client
          .from('user_tournaments')
          .select('*, users(ign)')
          .eq('tournament_id', tid);

      // Check if a Host is assigned
      String? hostEmail;
      if (tResponse['host_id'] != null) {
        try {
          final hResponse = await Supabase.instance.client
              .from('host_profiles')
              .select('email')
              .eq('id', tResponse['host_id'])
              .single();
          hostEmail = hResponse['email'];
        } catch (_) {
          hostEmail = "Host Info Unavailable";
        }
      }

      setState(() {
        _tournament = tResponse;
        _assignedHostEmail = hostEmail;
        _participants = (pResponse as List).map((p) => ParticipantState(p)).toList();
        _roomIdController.text = _tournament!['room_id'] ?? '';
        _roomPassController.text = _tournament!['room_password'] ?? '';
      });
    } catch (e) {
      setState(() => _message = "❌ Error finding tournament: Maybe ID is wrong?");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 ADMIN POWER: Remove Assigned Host (Transfer Mode) 🌟
  Future<void> _removeHost() async {
    if (_tournament == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('⚠️ Warning', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove the current host? This will make the match available for others to claim again.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Remove Host')
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() { _isLoading = true; _message = "🔄 Removing host..."; });
    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({'host_id': null})
          .eq('id', _tournament!['id']);
      
      setState(() {
        _assignedHostEmail = null;
        _tournament!['host_id'] = null;
        _message = "✅ Host removed. Match is now open for claiming.";
      });
    } catch (e) {
      setState(() => _message = "❌ Error removing host: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Admin Room Update
  Future<void> _setRoomDetails() async {
    if (_tournament == null) return;
    setState(() { _isLoading = true; _message = "🔄 Updating room..."; });
    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'room_id': _roomIdController.text.trim(),
            'room_password': _roomPassController.text.trim(),
          })
          .eq('id', _tournament!['id']);
      setState(() => _message = "✅ Room details updated!");
    } catch (e) {
      setState(() => _message = "❌ Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Admin Force Save Results (Emergency Override)
  Future<void> _saveResults() async {
    if (_tournament == null) return;
    final tid = _tournament!['id'];
    setState(() { _isLoading = true; _message = "🔄 Force saving results..."; });

    try {
      Map<String, Map<String, dynamic>> consolidatedResults = {};

      for (var p in _participants) {
        String uId = p.userId;
        int currentKills = int.tryParse(p.killsController.text) ?? 0;
        int currentCoins = int.tryParse(p.coinsController.text) ?? 0;
        bool isWinner = p.isWinner;

        if (consolidatedResults.containsKey(uId)) {
          consolidatedResults[uId]!['kills'] += currentKills;
          consolidatedResults[uId]!['winnings'] += currentCoins;
          if (isWinner) consolidatedResults[uId]!['is_winner'] = true;
        } else {
          consolidatedResults[uId] = {
            'tournament_id': tid,
            'user_id': uId,
            'kills': currentKills,
            'winnings': currentCoins,
            'is_winner': isWinner,
          };
        }
      }

      final resultsToUpsert = consolidatedResults.values.toList();
      if(resultsToUpsert.isNotEmpty) {
        await Supabase.instance.client.from('game_results').upsert(resultsToUpsert, onConflict: 'tournament_id, user_id');
      }

      final winners = _participants.where((p) => p.isWinner).map((p) => p.ign).toSet().toList();
      final winnerNames = winners.isNotEmpty ? winners.join(", ") : "No Winner";

      await Supabase.instance.client
          .from('tournaments')
          .update({
            'status': 'completed',
            'winner': winnerNames,
            'end_time': DateTime.now().toIso8601String(),
          })
          .eq('id', tid);

      await _updateStatistics(tid, consolidatedResults);

      setState(() => _message = "🏆 Admin Override: Results saved successfully!");
    } catch (e) {
      setState(() => _message = "❌ Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatistics(int tid, Map<String, Map<String, dynamic>> consolidatedResults) async {
    final entryFeeString = _tournament!['entry_fee']?.toString() ?? '0';
    final entryFee = double.tryParse(entryFeeString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final title = _tournament!['title'];

    final statsToUpsert = consolidatedResults.values.map((res) {
      return {
        'user_id': res['user_id'],
        'tournament_id': tid,
        'title': title,
        'paid': entryFee.toInt(),
        'won': res['winnings'],
      };
    }).toList();

    if (statsToUpsert.isNotEmpty) {
      await Supabase.instance.client.from('statistics').upsert(statsToUpsert, onConflict: 'user_id, tournament_id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.redAccent, size: 32),
                const SizedBox(width: 12),
                Text(
                  'GOD MODE: Manage',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
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
                          labelText: 'Global Tournament ID',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadTournament,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('FETCH DATA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.red)),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.startsWith('❌') || _message.startsWith('⚠️') ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

            // 🌟 ADMIN SPECIFIC: Host Status Panel 🌟
            if (_tournament != null && !_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _assignedHostEmail != null ? Colors.indigo.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  border: Border.all(color: _assignedHostEmail != null ? Colors.indigoAccent : Colors.orangeAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _assignedHostEmail != null ? Icons.person : Icons.person_off, 
                      color: _assignedHostEmail != null ? Colors.indigoAccent : Colors.orangeAccent
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _assignedHostEmail != null ? 'CLAIMED BY HOST' : 'OPEN / UNCLAIMED',
                            style: TextStyle(color: _assignedHostEmail != null ? Colors.indigoAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _assignedHostEmail ?? 'No host has booked this match yet.',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    if (_assignedHostEmail != null)
                      ElevatedButton(
                        onPressed: _removeHost,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
                        child: const Text('KICK HOST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'TOURNAMENT: ${_tournament!['title']} (#${_tournament!['id']})',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildRoomBox(),
              const SizedBox(height: 20),
              _buildParticipantsTable(),
              const SizedBox(height: 20),
              
              // Admin Force Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  label: const Text('ADMIN FORCE COMPLETE MATCH', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomBox() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Override', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _roomIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Room ID', labelStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _roomPassController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password', labelStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _setRoomDetails,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                icon: const Icon(Icons.update, color: Colors.white, size: 18),
                label: const Text('FORCE UPDATE', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTable() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Player Editing (Admin)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingTextStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white),
                columns: const [
                  DataColumn(label: Text('IGN')),
                  DataColumn(label: Text('Kills')),
                  DataColumn(label: Text('Coins')),
                  DataColumn(label: Text('Win')),
                ],
                rows: _participants.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(Text(p.ign)),
                      DataCell(SizedBox(width: 60, child: TextField(controller: p.killsController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0xFF2A2A2A))))),
                      DataCell(SizedBox(width: 80, child: TextField(controller: p.coinsController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0xFF2A2A2A))))),
                      DataCell(Checkbox(value: p.isWinner, activeColor: Colors.red, checkColor: Colors.white, onChanged: (val) => setState(() => p.isWinner = val ?? false))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
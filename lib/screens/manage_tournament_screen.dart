import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantState {
  final Map<String, dynamic> participantData;
  final TextEditingController killsController;
  final TextEditingController coinsController;
  bool isWinner;

  ParticipantState(this.participantData)
    : killsController = TextEditingController(
        text: (participantData['kills'] ?? 0).toString(),
      ),
      coinsController = TextEditingController(
        text: (participantData['coins_won'] ?? 0).toString(),
      ),
      isWinner = false;

  String get ign =>
      participantData['users']?['ign'] ?? participantData['ign'] ?? 'N/A';
  int get joinId => participantData['id'];
  int get userId => participantData['user_id'];
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
  bool _isLoading = false;
  String _message = "";

  Future<void> _loadTournament() async {
    final tid = int.tryParse(_searchController.text);
    if (tid == null) {
      setState(() => _message = "⚠️ Please enter a valid Tournament ID.");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
      _tournament = null;
      _participants = [];
    });

    try {
      final tResponse = await Supabase.instance.client
          .from('tournaments')
          .select()
          .eq('id', tid)
          .single();
      final pResponse = await Supabase.instance.client
          .from('user_tournaments')
          .select('*, users(ign)')
          .eq('tournament_id', tid)
          .order('id', ascending: true);

      setState(() {
        _tournament = tResponse;
        _participants = pResponse.map((p) => ParticipantState(p)).toList();
        _roomIdController.text = _tournament!['room_id'] ?? '';
        _roomPassController.text = _tournament!['room_password'] ?? '';
      });
    } catch (e) {
      setState(() => _message = "❌ Error loading tournament: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setRoomDetails() async {
    if (_tournament == null) return;
    setState(() {
      _isLoading = true;
      _message = "🔄 Updating room details...";
    });

    try {
      await Supabase.instance.client
          .from('tournaments')
          .update({
            'room_id': _roomIdController.text.trim(),
            'room_password': _roomPassController.text.trim(),
          })
          .eq('id', _tournament!['id']);

      setState(() => _message = "✅ Room details updated successfully!");
    } catch (e) {
      setState(() => _message = "❌ Error updating room: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveResults() async {
    if (_tournament == null) return;
    final tid = _tournament!['id'];
    setState(() {
      _isLoading = true;
      _message = "🔄 Saving results...";
    });

    try {
      // Step 1: Upsert results for all participants
      final resultsToUpsert = _participants
          .map(
            (p) => {
              'tournament_id': tid,
              'participant_id': p.userId,
              'ign': p.ign,
              'kills': int.tryParse(p.killsController.text) ?? 0,
              'won': int.tryParse(p.coinsController.text) ?? 0,
              'winner': p.isWinner ? 1 : 0,
            },
          )
          .toList();

      await Supabase.instance.client
          .from('results')
          .upsert(
            resultsToUpsert,
            onConflict: 'tournament_id, participant_id, ign',
          );

      // Step 2: Update tournament status and winner names
      final winners = _participants
          .where((p) => p.isWinner)
          .map((p) => p.ign)
          .toList();
      final winnerNames = winners.join(", ");

      await Supabase.instance.client
          .from('tournaments')
          .update({
            'status': 'completed',
            'winner': winnerNames,
            'end_time': DateTime.now().toIso8601String(),
          })
          .eq('id', tid);

      // Step 3: Calculate and upsert statistics (PHP logic)
      await _updateStatistics(tid);

      setState(
        () => _message = "🏆 Results saved successfully! Winners: $winnerNames",
      );
    } on PostgrestException catch (e) {
      setState(() => _message = "❌ Database Error: ${e.message}");
    } catch (e) {
      setState(
        () => _message = "❌ An unexpected error occurred: ${e.toString()}",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PHP code se statistics update karne wali logic
  Future<void> _updateStatistics(int tid) async {
    final entryFeeString = _tournament!['entry_fee']?.toString() ?? '0';
    final entryFee =
        double.tryParse(entryFeeString.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    final title = _tournament!['title'];
    final startTime = _tournament!['time'];

    // Fetch results data to aggregate
    final resultsData = await Supabase.instance.client
        .from('results')
        .select('participant_id, won')
        .eq('tournament_id', tid);

    // Group by user_id in Dart
    final Map<int, Map<String, dynamic>> userStats = {};
    for (var row in resultsData) {
      final userId = row['participant_id'] as int;
      final won = (row['won'] ?? 0) as num;

      if (userStats.containsKey(userId)) {
        userStats[userId]!['ign_count'] += 1;
        userStats[userId]!['total_won'] += won;
      } else {
        userStats[userId] = {'ign_count': 1, 'total_won': won.toDouble()};
      }
    }

    // Prepare data for statistics upsert
    final statsToUpsert = [];
    userStats.forEach((userId, stats) {
      statsToUpsert.add({
        'user_id': userId,
        'tournament_id': tid,
        'title': title,
        'start_time': startTime,
        'paid': entryFee * stats['ign_count'],
        'won': stats['total_won'],
      });
    });

    if (statsToUpsert.isNotEmpty) {
      await Supabase.instance.client
          .from('statistics')
          .upsert(statsToUpsert, onConflict: 'user_id, tournament_id');
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
            Text(
              '⚙️ Manage Tournament',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // --- Search Section ---
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tournament ID',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                            Icons.numbers,
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
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadTournament,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'LOAD DATA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Message & Loading state ---
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.red)),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.startsWith('❌')
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

            // --- Tournament Details Section ---
            if (_tournament != null && !_isLoading) ...[
              Text(
                'TOURNAMENT: ${_tournament!['title']} (#${_tournament!['id']})',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              _buildRoomBox(),
              const SizedBox(height: 20),
              _buildParticipantsTable(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'SAVE RESULTS & COMPLETE TOURNAMENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
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
            const Text(
              'Room Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roomIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Room ID',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.meeting_room,
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
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _roomPassController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock, color: Colors.grey),
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
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 56, // matches general text field height
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setRoomDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.update),
                    label: const Text(
                      'UPDATE ROOM',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildParticipantsTable() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participants & Results',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 30,
                headingTextStyle: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                dataTextStyle: const TextStyle(color: Colors.white),
                columns: const [
                  DataColumn(label: Text('IGN')),
                  DataColumn(label: Text('Kills')),
                  DataColumn(label: Text('Coins Won')),
                  DataColumn(label: Text('Winner')),
                ],
                rows: _participants.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(Text(p.ign)),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: p.killsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.all(12),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: p.coinsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.all(12),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Checkbox(
                          value: p.isWinner,
                          activeColor: Colors.red,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              p.isWinner = val ?? false;
                            });
                          },
                        ),
                      ),
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

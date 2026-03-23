import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteTournamentScreen extends StatefulWidget {
  const DeleteTournamentScreen({super.key});

  @override
  State<DeleteTournamentScreen> createState() => _DeleteTournamentScreenState();
}

class _DeleteTournamentScreenState extends State<DeleteTournamentScreen> {
  final _tidController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  Future<void> _deleteTournament() async {
    final tid = int.tryParse(_tidController.text);
    if (tid == null) {
      setState(() {
        _message = '❌ Please enter a valid Tournament ID.';
      });
      return;
    }

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Tournament #$tid?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // First, check if tournament exists
      final tournament = await Supabase.instance.client
          .from('tournaments')
          .select('id, title')
          .eq('id', tid)
          .maybeSingle();

      if (tournament == null) {
        setState(() {
          _message = '❌ Tournament #$tid not found.';
          _isLoading = false;
        });
        return;
      }

      // If using cascading deletes in Supabase, this next step is not needed.
      // But for safety, we do it, just like the PHP code.
      await Supabase.instance.client
          .from('user_tournaments')
          .delete()
          .eq('tournament_id', tid);

      // Also delete from results and statistics
      await Supabase.instance.client
          .from('results')
          .delete()
          .eq('tournament_id', tid);
      await Supabase.instance.client
          .from('statistics')
          .delete()
          .eq('tournament_id', tid);

      // Finally, delete the tournament itself
      await Supabase.instance.client.from('tournaments').delete().eq('id', tid);

      setState(() {
        _message =
            "✅ Tournament #$tid (${tournament['title']}) and all its data deleted successfully!";
        _tidController.clear();
      });
    } on PostgrestException catch (e) {
      setState(() {
        _message = '❌ Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _message = '❌ An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: const Color(0xFF1E1E1E), // Blueprint Card Color
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Colors.redAccent,
                  width: 1,
                ), // Subtle warning border
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DELETE TOURNAMENT',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This action is irreversible. All associated data (participants, results, statistics) will be permanently deleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _tidController,
                      keyboardType: TextInputType.number,
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
                    ),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.red)
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _deleteTournament,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text(
                            'PERMANENTLY DELETE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _message.startsWith('✅')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _message.startsWith('✅')
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _message.startsWith('✅')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _message.startsWith('✅')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _message,
                                style: TextStyle(
                                  color: _message.startsWith('✅')
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

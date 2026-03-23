import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Controllers & Variables
  final _titleController = TextEditingController();
  String? _mode;
  DateTime? _time;
  final _imageController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _perKillController = TextEditingController();
  final _entryFeeController = TextEditingController();
  String? _type;
  final _versionController = TextEditingController();
  final _mapController = TextEditingController();
  final _slotsController = TextEditingController();

  // PHP code se liye gaye options
  final List<String> _modeOptions = [
    'Battle Royale',
    'Clash Squad',
    'Lone Wolf',
    'BR Survival',
    'HS Clash Squad',
    'HS Lone Wolf',
    'Daily Special',
    'Mega Special',
    'Grand Special',
  ];
  final List<String> _typeOptions = ['Solo', 'Duo', 'Squad'];

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (time == null) return;

    setState(() {
      _time = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _createTournament() async {
    if (_formKey.currentState!.validate()) {
      if (_time == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a time.')));
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await Supabase.instance.client.from('tournaments').insert({
          'title': _titleController.text,
          'mode': _mode,
          'time': _time!.toIso8601String(),
          'image_url': _imageController.text,
          'prize_pool': _prizePoolController.text,
          'per_kill': _perKillController.text,
          'entry_fee': _entryFeeController.text,
          'type': _type,
          'version': _versionController.text,
          'map': _mapController.text,
          'slots': int.parse(_slotsController.text),
          'filled': 0, // PHP code ke mutabik
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tournament created successfully in $_mode!'),
          ),
        );
        _formKey.currentState!.reset();
        _titleController.clear();
        _imageController.clear();
        _prizePoolController.clear();
        _perKillController.clear();
        _entryFeeController.clear();
        _versionController.clear();
        _mapController.clear();
        _slotsController.clear();
        setState(() {
          _time = null;
          _mode = null;
          _type = null;
        });
      } on PostgrestException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.message}')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ An unexpected error occurred: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Tournament',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: _mode,
                hint: const Text('-- Select Mode --'),
                decoration: const InputDecoration(labelText: 'Mode'),
                items: _modeOptions
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _mode = v),
                validator: (v) => v == null ? 'Mode is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Time'),
                  child: Text(
                    _time == null
                        ? 'Select Time'
                        : DateFormat('yyyy-MM-dd HH:mm').format(_time!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(labelText: 'Image URL'),
                validator: (v) => v!.isEmpty ? 'Image URL is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _prizePoolController,
                decoration: const InputDecoration(labelText: 'Prize Pool'),
                validator: (v) => v!.isEmpty ? 'Prize Pool is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _perKillController,
                decoration: const InputDecoration(labelText: 'Per Kill'),
                validator: (v) => v!.isEmpty ? 'Per Kill is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _entryFeeController,
                decoration: const InputDecoration(labelText: 'Entry Fee'),
                validator: (v) => v!.isEmpty ? 'Entry Fee is required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _type,
                hint: const Text('-- Select Type --'),
                decoration: const InputDecoration(labelText: 'Type'),
                items: _typeOptions
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v),
                validator: (v) => v == null ? 'Type is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _versionController,
                decoration: const InputDecoration(labelText: 'Version'),
                validator: (v) => v!.isEmpty ? 'Version is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _mapController,
                decoration: const InputDecoration(labelText: 'Map'),
                validator: (v) => v!.isEmpty ? 'Map is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _slotsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Slots'),
                validator: (v) => v!.isEmpty ? 'Slots are required' : null,
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _createTournament,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Create Tournament'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

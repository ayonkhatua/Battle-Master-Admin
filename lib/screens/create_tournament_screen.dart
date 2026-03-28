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
  final _slotsController = TextEditingController();
  
  // 🌟 NAYA CONTROLLER: Prize Distribution Details ke liye 🌟
  final _prizeDescriptionController = TextEditingController();

  String? _version;
  String? _map;

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
  final List<String> _versionOptions = ['TPP']; 
  final List<String> _mapOptions = ['Bermuda', 'IRON CAGE'];

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time.'))
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final utcTime = _time!.toUtc().toIso8601String();

        await Supabase.instance.client.from('tournaments').insert({
          'title': _titleController.text,
          'mode': _mode,
          'time': utcTime,
          'image_url': _imageController.text,
          'prize_pool': _prizePoolController.text,
          'per_kill': _perKillController.text,
          'entry_fee': _entryFeeController.text,
          'type': _type,
          'version': _version, 
          'map': _map,         
          'slots': int.parse(_slotsController.text),
          'filled': 0, 
          // 🌟 DATABASE ENTRY: Prize Description yahan save hoga 🌟
          'prize_description': _prizeDescriptionController.text.trim().isNotEmpty 
                               ? _prizeDescriptionController.text.trim() 
                               : null,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Tournament created successfully in $_mode!')),
          );
        }
        
        // Form Clear Logic
        _formKey.currentState!.reset();
        _titleController.clear();
        _imageController.clear();
        _prizePoolController.clear();
        _perKillController.clear();
        _entryFeeController.clear();
        _slotsController.clear();
        _prizeDescriptionController.clear(); // Isko bhi clear karna zaroori hai
        
        setState(() {
          _time = null;
          _mode = null;
          _type = null;
          _version = null;
          _map = null;
        });
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.message}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ An unexpected error occurred: $e')));
        }
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
      appBar: AppBar(
        title: const Text("Create Tournament"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Match Details',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: _mode,
                hint: const Text('-- Select Mode --', style: TextStyle(color: Colors.white54)),
                decoration: const InputDecoration(labelText: 'Game Mode', filled: true, fillColor: Color(0xFF1e293b)),
                dropdownColor: const Color(0xFF1e293b),
                style: const TextStyle(color: Colors.white),
                items: _modeOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _mode = v),
                validator: (v) => v == null ? 'Mode is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Match Title', filled: true, fillColor: Color(0xFF1e293b)),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Match Time', filled: true, fillColor: Color(0xFF1e293b)),
                  child: Text(
                    _time == null
                        ? 'Select Date & Time'
                        : DateFormat('yyyy-MM-dd hh:mm a').format(_time!),
                    style: TextStyle(color: _time == null ? Colors.white54 : Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _imageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Image URL', filled: true, fillColor: Color(0xFF1e293b)),
                validator: (v) => v!.isEmpty ? 'Image URL is required' : null,
              ),
              const SizedBox(height: 16),

              // --- Grid for Numbers ---
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prizePoolController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Total Prize (🪙)', filled: true, fillColor: Color(0xFF1e293b)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _perKillController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Per Kill (🪙)', filled: true, fillColor: Color(0xFF1e293b)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🌟 NAYA FIELD: Prize Distribution Details 🌟
              TextFormField(
                controller: _prizeDescriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4, // Multi-line input allow karega
                decoration: const InputDecoration(
                  labelText: 'Prize Distribution Details (For Popup)', 
                  hintText: 'Example:\n1st Team: 20 Coins (5/Player)\n2nd Team: 10 Coins\nTop Fragger: 5 Coins',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true, 
                  fillColor: Color(0xFF1e293b),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _entryFeeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Entry Fee (🪙)', filled: true, fillColor: Color(0xFF1e293b)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _slotsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Total Slots', filled: true, fillColor: Color(0xFF1e293b)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      hint: const Text('-- Type --', style: TextStyle(color: Colors.white54)),
                      decoration: const InputDecoration(labelText: 'Type', filled: true, fillColor: Color(0xFF1e293b)),
                      dropdownColor: const Color(0xFF1e293b),
                      style: const TextStyle(color: Colors.white),
                      items: _typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _type = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _version,
                      hint: const Text('-- Version --', style: TextStyle(color: Colors.white54)),
                      decoration: const InputDecoration(labelText: 'Version', filled: true, fillColor: Color(0xFF1e293b)),
                      dropdownColor: const Color(0xFF1e293b),
                      style: const TextStyle(color: Colors.white),
                      items: _versionOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _version = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _map,
                hint: const Text('-- Select Map --', style: TextStyle(color: Colors.white54)),
                decoration: const InputDecoration(labelText: 'Map', filled: true, fillColor: Color(0xFF1e293b)),
                dropdownColor: const Color(0xFF1e293b),
                style: const TextStyle(color: Colors.white),
                items: _mapOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _map = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ElevatedButton(
                      onPressed: _createTournament,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CREATE TOURNAMENT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
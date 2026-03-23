import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoinAddScreen extends StatefulWidget {
  const CoinAddScreen({super.key});

  @override
  State<CoinAddScreen> createState() => _CoinAddScreenState();
}

class _CoinAddScreenState extends State<CoinAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedBucket = 'deposited';
  bool _isLoading = false;
  String _message = '';
  bool _isError = false;

  Future<void> _addCoins() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
      _isError = false;
    });

    final identifier = _identifierController.text;
    final amount = int.tryParse(_amountController.text);
    final note = _noteController.text;

    try {
      // Step 1: Find the user by username or mobile
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('id, username')
          .or('username.eq.$identifier,mobile.eq.$identifier')
          .maybeSingle();

      if (userResponse == null) {
        throw 'User not found with that username or mobile.';
      }

      final userId = userResponse['id'];
      final userName = userResponse['username'];

      // Step 2: Call the RPC function
      await Supabase.instance.client.rpc(
        'admin_add_coins',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_bucket': _selectedBucket,
          'p_note': note,
        },
      );

      // Success
      setState(() {
        _message = '✅ Successfully added $amount coins to user $userName.';
        _isError = false;
        _formKey.currentState?.reset();
        _identifierController.clear();
        _amountController.clear();
        _noteController.clear();
        _selectedBucket = 'deposited';
      });
    } catch (e) {
      // Handle errors
      final errorMessage = e is PostgrestException ? e.message : e.toString();
      setState(() {
        _message = '❌ Operation failed: $errorMessage';
        _isError = true;
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
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amberAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'ADD COINS',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Credit coins to a user account instantly.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      if (_message.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isError
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isError ? Colors.red : Colors.green,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isError ? Icons.error : Icons.check_circle,
                                color: _isError ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _message,
                                  style: TextStyle(
                                    color: _isError
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildTextField(
                        controller: _identifierController,
                        label: 'Username or Mobile',
                        icon: Icons.person,
                        validator: (v) =>
                            v!.isEmpty ? 'This field is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _amountController,
                        label: 'Amount (integer coins)',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.isEmpty) return 'Amount is required';
                          if (int.tryParse(v) == null || int.parse(v) <= 0)
                            return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedBucket,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Credit Bucket',
                          labelStyle: const TextStyle(color: Colors.grey),
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
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'deposited',
                            child: Text('Deposited'),
                          ),
                          DropdownMenuItem(
                            value: 'winning',
                            child: Text('Winning'),
                          ),
                          DropdownMenuItem(
                            value: 'bonus',
                            child: Text('Bonus'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedBucket = v!),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _noteController,
                        label: 'Note (optional)',
                        icon: Icons.note,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.red,
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _addCoins,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text(
                                  'ADD COINS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
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
      validator: validator,
    );
  }
}

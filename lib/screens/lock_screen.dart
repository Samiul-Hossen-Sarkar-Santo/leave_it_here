import 'package:flutter/material.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.onPinUnlock,
    required this.onBiometricUnlock,
    required this.showBiometric,
  });

  final Future<bool> Function(String pin) onPinUnlock;
  final Future<String?> Function() onBiometricUnlock;
  final bool showBiometric;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPin() async {
    setState(() {
      _working = true;
      _error = null;
    });

    final ok = await widget.onPinUnlock(_pinController.text.trim());

    if (!mounted) {
      return;
    }

    setState(() {
      _working = false;
      if (!ok) {
        _error = 'Incorrect PIN';
      }
    });
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _working = true;
      _error = null;
    });

    final errorMessage = await widget.onBiometricUnlock();

    if (!mounted) {
      return;
    }

    setState(() {
      _working = false;
      if (errorMessage != null) {
        _error = errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App Locked', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Unlock to access your journal and reflections.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _unlockWithPin(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _working ? null : _unlockWithPin,
                          child: const Text('Unlock with PIN'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.showBiometric) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _unlockWithBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Use biometrics'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

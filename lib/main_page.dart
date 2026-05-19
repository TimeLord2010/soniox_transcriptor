import 'package:flutter/cupertino.dart';

import 'local_repository.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final savedKey = LocalRepository.getApiKey();
    if (savedKey != null) {
      setState(() {
        _controller.text = savedKey;
      });
    }
  }

  Future<void> _saveApiKey() async {
    await LocalRepository.setApiKey(
      _controller.text.isEmpty ? null : _controller.text,
    );
    // Optionally show a confirmation
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('API key saved.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Vit transcriptor'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _controller,
                placeholder: 'Enter API key',
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 12.0,
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _saveApiKey,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

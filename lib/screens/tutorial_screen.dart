import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    required this.onDone,
    this.showSkip = true,
    this.popOnDone = true,
  });

  final Future<void> Function() onDone;
  final bool showSkip;
  final bool popOnDone;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _steps = [
    (
      title: 'Welcome to Leave It Here',
      body:
          'Write entries, mark breakdowns, and track wins from your day in one place.',
      icon: Icons.waving_hand_outlined,
    ),
    (
      title: 'Add new entries',
      body:
          'Use the top Add new entries card. Inside editor, you can add wins, mark breakdown, and save.',
      icon: Icons.edit_note,
    ),
    (
      title: 'Review and reflect',
      body:
          'Browse past entries in list or grid view, then open details to review or edit unless locked.',
      icon: Icons.auto_stories_outlined,
    ),
    (
      title: 'Lock forever option',
      body:
          'You can permanently lock an entry. Locked entries hide edit actions and stay immutable.',
      icon: Icons.lock_outline,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial'),
        actions: [
          if (widget.showSkip && !isLast)
            TextButton(
              onPressed: _finish,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _steps.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(step.icon, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.body,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentPage == 0
                        ? null
                        : () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                            );
                          },
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isLast
                        ? _finish
                        : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                            );
                          },
                    child: Text(isLast ? 'Start using app' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    await widget.onDone();
    if (!widget.popOnDone || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

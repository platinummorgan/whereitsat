import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  void _finish() {
    Hive.box('settings').put('onboardingSeen', true);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final slides = [
      _buildSlide(
        icon: Icons.lightbulb_outline,
        title: 'Your memory, but organized.',
        text: 'Track who has your stuff and where you put it.',
        showSkip: true,
      ),
      _buildSlide(
        icon: Icons.lock_outline,
        title: 'Private by design.',
        text: 'No accounts. No tracking. Data stays on this device.',
      ),
      _buildSlide(
        icon: Icons.photo_camera,
        title: 'Photos + reminders.',
        text: "Snap a spot and set a due date. We'll nudge you.",
        showGetStarted: true,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => slides[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  margin: const EdgeInsets.all(4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? Colors.blue : Colors.grey[300],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_page < slides.length - 1)
              ElevatedButton(
                child: const Text('Next'),
                onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({required IconData icon, required String title, required String text, bool showSkip = false, bool showGetStarted = false}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.blue),
          const SizedBox(height: 32),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          if (showSkip)
            TextButton(
              onPressed: _finish,
              child: const Text('Skip'),
            ),
          if (showGetStarted)
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Get Started'),
            ),
        ],
      ),
    );
  }
}

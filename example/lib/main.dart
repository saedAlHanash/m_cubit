import 'package:flutter/material.dart';
import 'package:m_cubit/m_cubit.dart';

class TimerExampleScreen extends StatefulWidget {
  const TimerExampleScreen({Key? key}) : super(key: key);

  @override
  State<TimerExampleScreen> createState() => _TimerExampleScreenState();
}

class _TimerExampleScreenState extends State<TimerExampleScreen> {
  final TimerController _countdownController = TimerController(
    configuration:  TimerConfiguration(
      mode: TimerMode.countdown,
      initialDuration: Duration(minutes: 1, seconds: 30),
      onComplete: () => debugPrint('Countdown complete!'),
    ),
  );

  final TimerController _stopwatchController = TimerController(
    configuration: const TimerConfiguration(
      mode: TimerMode.stopwatch,
    ),
  );

  @override
  void dispose() {
    _countdownController.dispose();
    _stopwatchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer Widget Examples'),
        elevation: 2.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Simple Countdown Timer'),
            const SizedBox(height: 16.0),
            TimerWidget(
              configuration: _countdownController.configuration,
              builder: (context, state, controller) {
                return Column(
                  children: [
                    Text(
                      state.formattedTime,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: controller.start,
                          child: const Text('Start'),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: controller.pause,
                          child: const Text('Pause'),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: controller.resume,
                          child: const Text('Resume'),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: controller.reset,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32.0),
            
            _buildSectionTitle('Advanced Countdown Timer'),
            const SizedBox(height: 16.0),
             AdvancedTimerWidget(
              configuration: TimerConfiguration(
                mode: TimerMode.countdown,
                initialDuration: Duration(seconds: 45),
                autoStart: true,
              ),
              progressStyle: ProgressStyle.circular,

              primaryColor: Colors.teal,
            ),
            
            const SizedBox(height: 32.0),
            
            _buildSectionTitle('Advanced Stopwatch'),
            const SizedBox(height: 16.0),
            AdvancedTimerWidget(
              configuration: const TimerConfiguration(
                mode: TimerMode.stopwatch,
              ),
              showLaps: true,
              primaryColor: Colors.indigo,
              secondaryColor: Colors.purple,
              buttonStyle: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
              ),
            ),
            
            const SizedBox(height: 32.0),

            _buildSectionTitle('Segmented Countdown Timer'),
            const SizedBox(height: 16.0),
            const AdvancedTimerWidget(
              configuration: TimerConfiguration(
                mode: TimerMode.countdown,
                initialDuration: Duration(minutes: 2),
              ),
              progressStyle: ProgressStyle.segmented,

              primaryColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'timer_models.dart';
import 'timer_controller.dart';

class TimerWidget extends StatefulWidget {
  final TimerConfiguration configuration;
  final Widget Function(BuildContext context, TimerStateData stateData, TimerController controller)? builder;
  final bool showProgress;
  final bool showLaps;
  final Color? primaryColor;
  final Color? backgroundColor;
  final TextStyle? timeTextStyle;
  final ButtonStyle? buttonStyle;

  const TimerWidget({
    Key? key,
    this.configuration = const TimerConfiguration(),
    this.builder,
    this.showProgress = true,
    this.showLaps = false,
    this.primaryColor,
    this.backgroundColor,
    this.timeTextStyle,
    this.buttonStyle,
  }) : super(key: key);

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late TimerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TimerController(configuration: widget.configuration);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return widget.builder!(context, _controller.stateData, _controller);
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final stateData = _controller.stateData;
        final theme = Theme.of(context);
        
        final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
        final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surface;
        final timeTextStyle = widget.timeTextStyle ?? 
          theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          );

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer Display
              _buildTimerDisplay(stateData, timeTextStyle),
              
              const SizedBox(height: 16.0),
              
              // Progress Bar (for countdown mode)
              if (widget.showProgress && stateData.mode == TimerMode.countdown)
                _buildProgressBar(stateData, primaryColor),
              
              if (widget.showProgress && stateData.mode == TimerMode.countdown)
                const SizedBox(height: 16.0),
              
              // Control Buttons
              _buildControls(stateData, primaryColor),
              
              // Lap Times (for stopwatch mode)
              if (widget.showLaps && stateData.mode == TimerMode.stopwatch && stateData.lapTimes.isNotEmpty)
                _buildLapTimes(stateData, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerDisplay(TimerStateData stateData, TextStyle? timeTextStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: _getStateColor(stateData.state),
          width: 2.0,
        ),
      ),
      child: Text(
        stateData.formattedTime,
        style: timeTextStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProgressBar(TimerStateData stateData, Color primaryColor) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: stateData.progress ?? 0.0,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          minHeight: 8.0,
        ),
        const SizedBox(height: 4.0),
        Text(
          '${((stateData.progress ?? 0.0) * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(TimerStateData stateData, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (stateData.state == TimerState.idle || stateData.state == TimerState.paused)
          _buildControlButton(
            icon: Icons.play_arrow,
            label: 'Start',
            onPressed: stateData.state == TimerState.paused ? _controller.resume : _controller.start,
            color: Colors.green,
          ),
        
        if (stateData.state == TimerState.running)
          _buildControlButton(
            icon: Icons.pause,
            label: 'Pause',
            onPressed: _controller.pause,
            color: Colors.orange,
          ),
        
        const SizedBox(width: 16.0),
        
        _buildControlButton(
          icon: Icons.stop,
          label: 'Reset',
          onPressed: _controller.reset,
          color: Colors.red,
        ),
        
        if (stateData.mode == TimerMode.stopwatch && stateData.state == TimerState.running)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildControlButton(
              icon: Icons.flag,
              label: 'Lap',
              onPressed: _controller.recordLap,
              color: Colors.blue,
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.0),
      label: Text(label),
      style: widget.buttonStyle?.copyWith(
        backgroundColor: WidgetStateProperty.all(color),
        foregroundColor: WidgetStateProperty.all(Colors.white),
      ) ?? ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  Widget _buildLapTimes(TimerStateData stateData, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lap Times',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          SizedBox(
            height: 100.0,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: stateData.lapTimes.length,
              itemBuilder: (context, index) {
                final lap = stateData.lapTimes[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lap ${lap.lapNumber}'),
                      Text(_formatLapTime(lap.time)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatLapTime(Duration duration) {
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 10;

    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
    }
  }

  Color _getStateColor(TimerState state) {
    switch (state) {
      case TimerState.running:
        return Colors.green;
      case TimerState.paused:
        return Colors.orange;
      case TimerState.completed:
        return Colors.red;
      case TimerState.idle:
      default:
        return Colors.grey;
    }
  }
}
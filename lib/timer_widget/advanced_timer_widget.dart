import 'package:flutter/material.dart';
import 'timer_models.dart';
import 'timer_controller.dart';

class AdvancedTimerWidget extends StatefulWidget {
  final TimerConfiguration configuration;
  final bool showProgress;
  final bool showLaps;
  final bool showModeIndicator;
  final bool enableAnimations;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? backgroundColor;
  final TextStyle? timeTextStyle;
  final ButtonStyle? buttonStyle;
  final double? size;
  final ProgressStyle progressStyle;
  final AnimationStyle animationStyle;

  const AdvancedTimerWidget({
    Key? key,
    this.configuration = const TimerConfiguration(),
    this.showProgress = true,
    this.showLaps = false,
    this.showModeIndicator = true,
    this.enableAnimations = true,
    this.primaryColor,
    this.secondaryColor,
    this.backgroundColor,
    this.timeTextStyle,
    this.buttonStyle,
    this.size,
    this.progressStyle = ProgressStyle.circular,
    this.animationStyle = AnimationStyle.scale,
  }) : super(key: key);

  @override
  State<AdvancedTimerWidget> createState() => _AdvancedTimerWidgetState();
}

enum ProgressStyle { linear, circular, segmented }
enum AnimationStyle { scale, fade, slide }

class _AdvancedTimerWidgetState extends State<AdvancedTimerWidget>
    with SingleTickerProviderStateMixin {
  late TimerController _controller;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TimerController(configuration: widget.configuration);
    
    if (widget.enableAnimations) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      
      _fadeAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, -0.1),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final stateData = _controller.stateData;
        final theme = Theme.of(context);
        
        final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
        final secondaryColor = widget.secondaryColor ?? theme.colorScheme.secondary;
        final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surface;
        
        return AnimatedContainer(
          duration: widget.enableAnimations ? const Duration(milliseconds: 300) : Duration.zero,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: _getStateColor(stateData.state).withOpacity(0.2),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
                spreadRadius: 2.0,
              ),
            ],
            border: Border.all(
              color: _getStateColor(stateData.state).withOpacity(0.3),
              width: 2.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode Indicator
              if (widget.showModeIndicator)
                _buildModeIndicator(stateData.mode, primaryColor, secondaryColor),
              
              const SizedBox(height: 16.0),
              
              // Timer Display with Animation
              _buildAnimatedTimerDisplay(stateData, primaryColor),
              
              const SizedBox(height: 20.0),
              
              // Progress Indicator
              if (widget.showProgress)
                _buildProgressIndicator(stateData, primaryColor, secondaryColor),
              
              if (widget.showProgress)
                const SizedBox(height: 20.0),
              
              // Control Buttons
              _buildAdvancedControls(stateData, primaryColor, secondaryColor),
              
              // Lap Times
              if (widget.showLaps && stateData.mode == TimerMode.stopwatch && stateData.lapTimes.isNotEmpty)
                _buildAdvancedLapTimes(stateData, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeIndicator(TimerMode mode, Color primaryColor, Color secondaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: mode == TimerMode.countdown ? primaryColor.withOpacity(0.1) : secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: mode == TimerMode.countdown ? primaryColor : secondaryColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mode == TimerMode.countdown ? Icons.hourglass_top : Icons.timer,
            size: 16.0,
            color: mode == TimerMode.countdown ? primaryColor : secondaryColor,
          ),
          const SizedBox(width: 4.0),
          Text(
            mode == TimerMode.countdown ? 'Countdown' : 'Stopwatch',
            style: TextStyle(
              color: mode == TimerMode.countdown ? primaryColor : secondaryColor,
              fontWeight: FontWeight.w500,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTimerDisplay(TimerStateData stateData, Color primaryColor) {
    final timeText = stateData.formattedTime;
    
    Widget timeDisplay = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStateColor(stateData.state).withOpacity(0.1),
            _getStateColor(stateData.state).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: _getStateColor(stateData.state).withOpacity(0.3),
          width: 2.0,
        ),
      ),
      child: Text(
        timeText,
        style: widget.timeTextStyle ?? TextStyle(
          fontSize: widget.size ?? 48.0,
          fontWeight: FontWeight.bold,
          color: _getStateColor(stateData.state),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        textAlign: TextAlign.center,
      ),
    );

    if (widget.enableAnimations && stateData.state == TimerState.running) {
      _animationController.repeat(reverse: true);
      
      switch (widget.animationStyle) {
        case AnimationStyle.scale:
          return ScaleTransition(
            scale: _scaleAnimation,
            child: timeDisplay,
          );
        case AnimationStyle.fade:
          return FadeTransition(
            opacity: _fadeAnimation,
            child: timeDisplay,
          );
        case AnimationStyle.slide:
          return SlideTransition(
            position: _slideAnimation,
            child: timeDisplay,
          );
      }
    } else {
      _animationController.stop();
      return timeDisplay;
    }
  }

  Widget _buildProgressIndicator(TimerStateData stateData, Color primaryColor, Color secondaryColor) {
    if (stateData.mode == TimerMode.stopwatch) return const SizedBox.shrink();
    
    switch (widget.progressStyle) {
      case ProgressStyle.linear:
        return _buildLinearProgress(stateData, primaryColor);
      case ProgressStyle.circular:
        return _buildCircularProgress(stateData, primaryColor);
      case ProgressStyle.segmented:
        return _buildSegmentedProgress(stateData, primaryColor, secondaryColor);
    }
  }

  Widget _buildLinearProgress(TimerStateData stateData, Color primaryColor) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: LinearProgressIndicator(
            value: stateData.progress ?? 0.0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            minHeight: 12.0,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          '${((stateData.progress ?? 0.0) * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(TimerStateData stateData, Color primaryColor) {
    return SizedBox(
      width: 80.0,
      height: 80.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: stateData.progress ?? 0.0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            strokeWidth: 6.0,
          ),
          Text(
            '${((stateData.progress ?? 0.0) * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedProgress(TimerStateData stateData, Color primaryColor, Color secondaryColor) {
    const segments = 10;
    final filledSegments = ((stateData.progress ?? 0.0) * segments).round();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(segments, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: index < filledSegments ? primaryColor : secondaryColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4.0),
          ),
        );
      }),
    );
  }

  Widget _buildAdvancedControls(TimerStateData stateData, Color primaryColor, Color secondaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: stateData.state == TimerState.running ? Icons.pause : Icons.play_arrow,
          label: stateData.state == TimerState.running ? 'Pause' : 'Start',
          onPressed: _getPlayPauseAction(stateData.state),
          color: stateData.state == TimerState.running ? Colors.orange : Colors.green,
          isPrimary: true,
        ),
        
        const SizedBox(width: 16.0),
        
        _buildControlButton(
          icon: Icons.stop,
          label: 'Reset',
          onPressed: _controller.reset,
          color: Colors.red,
          isPrimary: false,
        ),
        
        if (stateData.mode == TimerMode.stopwatch && stateData.state == TimerState.running)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildControlButton(
              icon: Icons.flag,
              label: 'Lap',
              onPressed: _controller.recordLap,
              color: Colors.blue,
              isPrimary: false,
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
    required bool isPrimary,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20.0),
        label: Text(label),
        style: widget.buttonStyle?.copyWith(
          backgroundColor: WidgetStateProperty.all(color),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
          elevation: WidgetStateProperty.all(isPrimary ? 4.0 : 2.0),
        ) ?? ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          elevation: isPrimary ? 4.0 : 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedLapTimes(TimerStateData stateData, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: theme.colorScheme.primary, size: 20.0),
              const SizedBox(width: 8.0),
              Text(
                'Lap Times',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            height: 120.0,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: stateData.lapTimes.length,
              itemBuilder: (context, index) {
                final lap = stateData.lapTimes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2.0),
                  elevation: 1.0,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${lap.lapNumber}',
                        style: const TextStyle(color: Colors.white, fontSize: 12.0),
                      ),
                      radius: 16.0,
                    ),
                    title: Text(_formatLapTime(lap.time)),
                    trailing: index == 0 
                        ? const Text('Latest')
                        : Text('+${_formatTimeDifference(lap.time, stateData.lapTimes[index - 1].time)}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback _getPlayPauseAction(TimerState state) {
    switch (state) {
      case TimerState.running:
        return _controller.pause;
      case TimerState.paused:
      case TimerState.idle:
      case TimerState.completed:
        return state == TimerState.paused ? _controller.resume : _controller.start;
    }
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

  String _formatTimeDifference(Duration current, Duration previous) {
    final diff = current - previous;
    return _formatLapTime(diff);
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
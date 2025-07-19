import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PumpkinLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? message;

  const PumpkinLoadingIndicator({
    Key? key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
    this.message,
  }) : super(key: key);

  @override
  State<PumpkinLoadingIndicator> createState() => _PumpkinLoadingIndicatorState();
}

class _PumpkinLoadingIndicatorState extends State<PumpkinLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    strokeWidth: widget.strokeWidth,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.color ?? PumpkinColors.orange,
                    ),
                    backgroundColor: (widget.color ?? PumpkinColors.orange).withOpacity(0.2),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class PumpkinShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const PumpkinShimmerLoading({
    Key? key,
    required this.child,
    required this.isLoading,
    this.baseColor,
    this.highlightColor,
  }) : super(key: key);

  @override
  State<PumpkinShimmerLoading> createState() => _PumpkinShimmerLoadingState();
}

class _PumpkinShimmerLoadingState extends State<PumpkinShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    ));
    
    if (widget.isLoading) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(PumpkinShimmerLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _shimmerController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor ?? Colors.grey.shade300,
                widget.highlightColor ?? PumpkinColors.orange.withOpacity(0.3),
                widget.baseColor ?? Colors.grey.shade300,
              ],
              stops: [
                0.0,
                0.5 + _shimmerAnimation.value * 0.5,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class PumpkinSkeletonCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const PumpkinSkeletonCard({
    Key? key,
    required this.height,
    this.width,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PumpkinShimmerLoading(
      isLoading: true,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class PumpkinBiteCardSkeleton extends StatelessWidget {
  const PumpkinBiteCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header skeleton
          PumpkinShimmerLoading(
            isLoading: true,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade200],
                ),
              ),
            ),
          ),
          
          // Thumbnail skeleton
          const PumpkinSkeletonCard(
            height: 200,
            borderRadius: BorderRadius.zero,
          ),
          
          // Content skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PumpkinShimmerLoading(
                  isLoading: true,
                  child: Container(
                    height: 24,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PumpkinShimmerLoading(
                  isLoading: true,
                  child: Container(
                    height: 16,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PumpkinShimmerLoading(
                  isLoading: true,
                  child: Container(
                    height: 16,
                    width: MediaQuery.of(context).size.width * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PumpkinShimmerLoading(
                      isLoading: true,
                      child: Container(
                        height: 16,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const Spacer(),
                    PumpkinShimmerLoading(
                      isLoading: true,
                      child: Container(
                        height: 36,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PumpkinCatchUpCardSkeleton extends StatelessWidget {
  const PumpkinCatchUpCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail skeleton
            const PumpkinSkeletonCard(
              height: 60,
              width: 60,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            
            const SizedBox(width: 12),
            
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PumpkinShimmerLoading(
                    isLoading: true,
                    child: Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PumpkinShimmerLoading(
                        isLoading: true,
                        child: Container(
                          height: 12,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PumpkinShimmerLoading(
                        isLoading: true,
                        child: Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Play button skeleton
            PumpkinShimmerLoading(
              isLoading: true,
              child: Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PumpkinLoadingPage extends StatelessWidget {
  final String message;

  const PumpkinLoadingPage({
    Key? key,
    this.message = 'Loading your content...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: PumpkinLoadingIndicator(
          size: 60,
          message: message,
        ),
      ),
    );
  }
}
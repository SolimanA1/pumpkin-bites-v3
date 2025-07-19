import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'loading_widgets.dart';

class EnhancedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final int maxRetries;
  final Duration retryDelay;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BorderRadius? borderRadius;

  const EnhancedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.color,
    this.colorBlendMode,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<EnhancedNetworkImage> createState() => _EnhancedNetworkImageState();
}

class _EnhancedNetworkImageState extends State<EnhancedNetworkImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _currentImageUrl = widget.imageUrl;
    _loadImage();
  }

  @override
  void didUpdateWidget(EnhancedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _currentImageUrl = widget.imageUrl;
      _resetState();
      _loadImage();
    }
  }

  void _resetState() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _retryCount = 0;
    });
    _fadeController.reset();
  }

  void _loadImage() {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }
    // Image loading is handled by the Image.network widget
    // The state is managed through the onLoadCompleted callback
  }

  void _onImageLoaded() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
      _fadeController.forward();
    }
  }

  void _onImageError(Object error, StackTrace? stackTrace) {
    if (mounted) {
      if (_retryCount < widget.maxRetries) {
        _retryCount++;
        // Retry after delay
        Future.delayed(widget.retryDelay, () {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            // The Image.network widget will automatically retry
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: widget.borderRadius,
          ),
          child: Center(
            child: PumpkinLoadingIndicator(
              size: widget.height != null && widget.height! < 100 ? 20 : 30,
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: widget.borderRadius,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: widget.height != null && widget.height! < 100 ? 24 : 48,
                color: Colors.grey.shade400,
              ),
              if (widget.height == null || widget.height! >= 100) ...[
                const SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_retryCount >= widget.maxRetries) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      _retryCount = 0;
                      _resetState();
                      _loadImage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PumpkinColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: PumpkinColors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: PumpkinColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
  }

  Widget _buildImage() {
    final imageWidget = Image.network(
      _currentImageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          _onImageLoaded();
          return child;
        }
        
        if (frame == null) {
          return _buildPlaceholder();
        } else {
          _onImageLoaded();
          return FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          );
        }
      },
      errorBuilder: (context, error, stackTrace) {
        _onImageError(error, stackTrace);
        return _buildErrorWidget();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return _buildPlaceholder();
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return _buildImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

class PumpkinBiteImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final bool isLocked;
  final VoidCallback? onTap;

  const PumpkinBiteImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.isLocked = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          EnhancedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            color: isLocked ? Colors.grey : null,
            colorBlendMode: isLocked ? BlendMode.saturation : null,
            borderRadius: BorderRadius.circular(8),
            errorWidget: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PumpkinColors.orange.withOpacity(0.1),
                    PumpkinColors.lightOrange.withOpacity(0.1),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: height != null && height! < 100 ? 32 : 48,
                    color: PumpkinColors.orange.withOpacity(0.7),
                  ),
                  if (height == null || height! >= 100) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Audio Content',
                      style: TextStyle(
                        color: PumpkinColors.orange.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ImageWithRetry extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;

  const ImageWithRetry({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  }) : super(key: key);

  @override
  State<ImageWithRetry> createState() => _ImageWithRetryState();
}

class _ImageWithRetryState extends State<ImageWithRetry> {
  late String _imageKey;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _imageKey = widget.imageUrl;
  }

  @override
  void didUpdateWidget(ImageWithRetry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageKey = widget.imageUrl;
      _hasError = false;
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _imageKey = '${widget.imageUrl}?retry=${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedNetworkImage(
      imageUrl: _imageKey,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: widget.loadingBuilder?.call(context),
      errorWidget: widget.errorBuilder?.call(context, 'Failed to load image') ??
          GestureDetector(
            onTap: _retry,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.refresh,
                    color: PumpkinColors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to retry',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
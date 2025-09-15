import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/home_controller.dart';
import '../../core/service_locator.dart';
import '../../models/bite_model.dart';
import '../../widgets/subscription_gate.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => getIt<HomeController>(),
      child: const _HomeScreenView(),
    );
  }
}

class _HomeScreenView extends StatelessWidget {
  const _HomeScreenView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F3),
          appBar: AppBar(
            title: Image.asset(
              'assets/images/logo/pumpkin_bites_logo_transparent.png',
              height: 150,
              fit: BoxFit.contain,
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFFFFF8F3),
            elevation: 2,
            shadowColor: const Color(0xFF8B0000).withOpacity(0.1),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  // TODO: Implement notifications
                },
              ),
            ],
          ),
          body: _buildBody(context, controller),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, HomeController controller) {
    if (controller.isLoading) {
      return _LoadingIndicatorWidget(message: controller.loadingMessage);
    }
    
    if (controller.hasError) {
      return _ErrorMessageWidget(
        message: controller.errorMessage,
        onRetry: () => controller.refreshContent(),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => controller.refreshContent(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const TrialStatusWidget(),
          _buildTodaysBiteSection(context, controller),
          _buildCatchUpBitesSection(context, controller),
        ],
      ),
    );
  }

  Widget _buildTodaysBiteSection(BuildContext context, HomeController controller) {
    if (controller.todaysBite == null) {
      return const SizedBox.shrink();
    }

    final bite = controller.todaysBite!;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.wb_sunny,
                  color: Color(0xFF8B0000),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Today's Bite",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[300],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: bite.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: bite.thumbnailUrl,
                            fit: BoxFit.cover,
                            color: controller.isTodaysBiteUnlocked ? null : Colors.grey,
                            colorBlendMode: controller.isTodaysBiteUnlocked ? null : BlendMode.saturation,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          )
                        : const Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bite.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B0000),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bite.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Unlock status or play button
                      if (!controller.isTodaysBiteUnlocked)
                        _CountdownTimer(
                          nextUnlockTime: controller.nextUnlockTime,
                          onUnlock: () => controller.onUnlockEvent(),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => controller.onBiteTapped(bite),
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text('Listen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000),
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatchUpBitesSection(BuildContext context, HomeController controller) {
    if (controller.catchUpBites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.queue_music,
                  color: Color(0xFF8B0000),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Catch Up (${controller.catchUpBites.length})",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          
          // List of bites
          ...controller.catchUpBites.map((bite) => _buildBiteCard(context, bite, controller)),
        ],
      ),
    );
  }

  Widget _buildBiteCard(BuildContext context, BiteModel bite, HomeController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bite.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: bite.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.image, color: Colors.grey),
                    errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
        ),
        title: Text(
          bite.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B0000),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          bite.description,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          onPressed: () => controller.onBiteTapped(bite),
          icon: const Icon(
            Icons.play_circle_filled,
            color: Color(0xFF8B0000),
            size: 32,
          ),
        ),
        onTap: () => controller.onBiteTapped(bite),
      ),
    );
  }
}

// Reusable widgets
class _LoadingIndicatorWidget extends StatelessWidget {
  final String message;
  
  const _LoadingIndicatorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const _ErrorMessageWidget({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFF8B0000),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime? nextUnlockTime;
  final VoidCallback? onUnlock;
  
  const _CountdownTimer({this.nextUnlockTime, this.onUnlock});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nextUnlockTime == null) {
      return const Text('Available soon');
    }

    final now = DateTime.now();
    final difference = widget.nextUnlockTime!.difference(now);

    if (difference.isNegative) {
      widget.onUnlock?.call();
      return const Text('Ready to unlock!');
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Unlocks in ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B0000),
        ),
      ),
    );
  }
}
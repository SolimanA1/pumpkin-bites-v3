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

class _HomeScreenView extends StatefulWidget {
  const _HomeScreenView({Key? key}) : super(key: key);

  @override
  State<_HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<_HomeScreenView> {
  Timer? _countdownTimer;
  Duration _timeUntilUnlock = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final controller = Provider.of<HomeController>(context, listen: false);
      final nextUnlockTime = controller.nextUnlockTime;

      if (nextUnlockTime != null) {
        final now = DateTime.now();
        final remaining = nextUnlockTime.difference(now);

        if (remaining.isNegative) {
          setState(() {
            _timeUntilUnlock = Duration.zero;
          });
          controller.refreshContent();
        } else {
          setState(() {
            _timeUntilUnlock = remaining;
          });
        }
      }
    });
  }

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
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B0000),
        ),
      );
    }

    if (controller.hasError) {
      return Center(
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
              controller.errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8B0000),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: controller.refreshContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshContent,
      color: const Color(0xFF8B0000),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodaysBiteSection(controller),
            _buildFreshBitesWaitingSection(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysBiteSection(HomeController controller) {
    final bite = controller.todaysBite;
    final isUnlocked = controller.isTodaysBiteUnlocked;

    // Use empty widget if no bite
    if (bite == null) {
      return const _EmptyTodaysBiteWidget();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Main content
          InkWell(
            onTap: isUnlocked ? () => _navigateToPlayer(bite) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with unlock status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUnlocked
                          ? [const Color(0xFF8B0000), const Color(0xFFB71C1C)]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DAY',
                          style: TextStyle(
                            color: isUnlocked
                                ? const Color(0xFF8B0000)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bite.dayNumber.toString(),
                          style: TextStyle(
                            color: isUnlocked
                                ? const Color(0xFF8B0000)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(),
                          if (!isUnlocked && _timeUntilUnlock.inSeconds > 0)
                            Text(
                              'Unlocks in ${_formatDuration(_timeUntilUnlock)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Thumbnail with lock overlay
                AspectRatio(
                  aspectRatio: 16 / 10, // Slightly taller as requested
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      bite.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: bite.thumbnailUrl,
                              fit: BoxFit.cover,
                              color: isUnlocked ? null : Colors.grey,
                              colorBlendMode: isUnlocked ? null : BlendMode.saturation,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8B0000),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),

                      // Lock overlay
                      if (!isUnlocked)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                if (_timeUntilUnlock.inSeconds > 0)
                                  Text(
                                    'Unlocks in\n${_formatDuration(_timeUntilUnlock)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // "NEW" badge for unlocked content
                      if (isUnlocked)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B0000),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bite.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: isUnlocked ? Colors.black : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: isUnlocked
                                ? const Color(0xFF8B0000)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${bite.duration} min',
                            style: TextStyle(
                              color: isUnlocked
                                  ? const Color(0xFF8B0000)
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: isUnlocked ? () => _navigateToPlayer(bite) : null,
                            icon: Icon(isUnlocked ? Icons.play_circle_filled : Icons.lock),
                            label: Text(isUnlocked ? 'Listen Now' : 'Locked'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isUnlocked
                                  ? const Color(0xFF8B0000)
                                  : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
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
          ),
        ],
      ),
    );
  }

  Widget _buildFreshBitesWaitingSection(HomeController controller) {
    final catchUpBites = controller.catchUpBites;

    if (catchUpBites.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no catch-up bites
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🍂 Fresh Bites Waiting',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Catch up on ${catchUpBites.length} missed ${catchUpBites.length == 1 ? 'bite' : 'bites'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _navigateToLibrary,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF8B0000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220, // Fixed height for horizontal scrolling
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: catchUpBites.length,
            itemBuilder: (context, index) {
              final bite = catchUpBites[index];
              return _buildCatchUpBiteCard(bite);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCatchUpBiteCard(BiteModel bite) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _navigateToPlayer(bite),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: bite.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF8B0000),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 32,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bite.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${bite.duration} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPlayer(BiteModel bite) {
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  void _navigateToLibrary() {
    Navigator.of(context).pushNamed('/library');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

// Empty widget for when no today's bite is available
class _EmptyTodaysBiteWidget extends StatelessWidget {
  const _EmptyTodaysBiteWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.coffee,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No fresh bite today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back tomorrow for a new bite!',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
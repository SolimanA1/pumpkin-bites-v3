import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../models/bite_model.dart';

class InstagramStoryGenerator extends StatelessWidget {
  final BiteModel bite;
  final String personalComment;
  final int snippetDuration;
  final ScreenshotController screenshotController;

  const InstagramStoryGenerator({
    Key? key,
    required this.bite,
    required this.personalComment,
    required this.snippetDuration,
    required this.screenshotController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building InstagramStoryGenerator widget');
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(1080, 1920),
        devicePixelRatio: 2.0,
        textScaler: TextScaler.linear(1.0),
        platformBrightness: Brightness.light,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        alwaysUse24HourFormat: false,
        accessibleNavigation: false,
        invertColors: false,
        highContrast: false,
        disableAnimations: false,
        boldText: false,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Screenshot(
          controller: screenshotController,
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Container(
              width: 1080, // Instagram story width
              height: 1920, // Instagram story height
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B0000), // Deep wine
                    Color(0xFFB71C1C), // Secondary wine
                    Color(0xFF6D0000), // Muted wine
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40.0, 120.0, 40.0, 100.0), // Custom safe padding
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better distribution
                    children: [
                      // Top section - App branding
                      _buildTopSection(),
                      
                      // Middle section - Bite content  
                      _buildMiddleSection(),
                      
                      // Bottom section - Call to action
                      _buildBottomSection(),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        // App logo/icon placeholder
        Container(
          width: 60, // Reduced from 80
          height: 60, // Reduced from 80
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.headphones,
            size: 40,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PUMPKIN BITES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bite thumbnail and title
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bite thumbnail placeholder (simplified for screenshot)
              Container(
                width: 80, // Reduced from 100  
                height: 80, // Reduced from 100
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Color(0xFF8B0000),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                bite.title,
                style: const TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 24, // Reduced from 28
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DAY ${bite.dayNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Audio waveform visualization
              Container(
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.graphic_eq,
                      color: Color(0xFF8B0000),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(20, (index) => 
                              Container(
                                width: 3,
                                height: (15 + (index % 4) * 8).toDouble(),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B0000),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Color(0xFF8B0000),
                          size: 20,
                        ),
                        Text(
                          '${snippetDuration}s',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
        
        // Personal comment if provided
        if (personalComment.isNotEmpty) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Personal Note',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  personalComment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.category,
                color: Color(0xFF8B0000),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                bite.category,
                style: const TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Call to action
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Listen to the full bite',
                style: TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Download Pumpkin Bites App',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'pumpkinbites.app',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
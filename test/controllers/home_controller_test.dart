import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/controllers/home_controller.dart';
import '../../lib/repositories/content_repository.dart';
import '../../lib/services/user_progression_service.dart';
import '../../lib/services/subscription_service.dart';
import '../../lib/models/bite_model.dart';
import '../../lib/core/service_locator.dart';

// Generate mocks
@GenerateMocks([ContentRepository, UserProgressionService, SubscriptionService])
import 'home_controller_test.mocks.dart';

void main() {
  group('HomeController Tests', () {
    late HomeController controller;
    late MockContentRepository mockContentRepository;
    late MockUserProgressionService mockProgressionService;
    late MockSubscriptionService mockSubscriptionService;

    setUp(() {
      // Reset service locator
      getIt.reset();

      // Create mocks
      mockContentRepository = MockContentRepository();
      mockProgressionService = MockUserProgressionService();
      mockSubscriptionService = MockSubscriptionService();

      // Register mocks
      getIt.registerSingleton<ContentRepository>(mockContentRepository);
      getIt.registerSingleton<UserProgressionService>(mockProgressionService);
      getIt.registerSingleton<SubscriptionService>(mockSubscriptionService);

      // Setup default mock behaviors
      when(mockProgressionService.checkTrialExpiration())
          .thenAnswer((_) async => {});
      when(mockSubscriptionService.subscriptionStatusStream)
          .thenAnswer((_) => Stream.value(true));
    });

    tearDown(() {
      controller.dispose();
      getIt.reset();
    });

    group('loadContent', () {
      test('should load content successfully', () async {
        // Arrange
        final todaysBite = BiteModel(
          id: 'today-bite',
          title: 'Today\'s Bite',
          description: 'Today\'s Description',
          audioUrl: 'https://example.com/today.mp3',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          authorName: 'Test Author',
          date: DateTime.now(),
          isPremium: false,
          dayNumber: 1,
          category: 'Psychology',
          duration: 180,
        );

        final catchUpBites = [
          BiteModel(
            id: 'catchup-1',
            title: 'Catch Up 1',
            description: 'Catch Up Description',
            audioUrl: 'https://example.com/catchup1.mp3',
            thumbnailUrl: 'https://example.com/thumb1.jpg',
            authorName: 'Test Author 1',
            date: DateTime.now(),
            isPremium: false,
            dayNumber: 2,
            category: 'Philosophy',
            duration: 185,
          ),
        ];

        when(mockContentRepository.getTodaysBite())
            .thenAnswer((_) async => todaysBite);
        when(mockContentRepository.getCatchUpBites())
            .thenAnswer((_) async => catchUpBites);
        when(mockProgressionService.getCurrentDay())
            .thenAnswer((_) async => 1);
        when(mockProgressionService.shouldUnlockNextBite())
            .thenAnswer((_) async => true);

        // Act
        controller = HomeController();
        await Future.delayed(Duration(milliseconds: 100)); // Wait for initialization

        // Assert
        expect(controller.state, equals(HomeScreenState.loaded));
        expect(controller.todaysBite, equals(todaysBite));
        expect(controller.catchUpBites, equals(catchUpBites));
        expect(controller.errorMessage, isEmpty);
      });

      test('should handle loading error gracefully', () async {
        // Arrange
        when(mockContentRepository.getTodaysBite())
            .thenThrow(Exception('Network error'));
        when(mockContentRepository.getCatchUpBites())
            .thenAnswer((_) async => <BiteModel>[]);

        // Act
        controller = HomeController();
        await Future.delayed(Duration(milliseconds: 100)); // Wait for initialization

        // Assert
        expect(controller.state, equals(HomeScreenState.error));
        expect(controller.errorMessage, isNotEmpty);
        expect(controller.todaysBite, isNull);
      });
    });

    group('onBiteTapped', () {
      test('should handle bite tap when user has access', () async {
        // Arrange
        final bite = BiteModel(
          id: 'test-bite',
          title: 'Test Bite',
          description: 'Test Description',
          audioUrl: 'https://example.com/test.mp3',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          authorName: 'Test Author',
          date: DateTime.now(),
          isPremium: false,
          dayNumber: 1,
          category: 'Psychology',
          duration: 180,
        );

        when(mockContentRepository.hasUserAccessToBite(bite.id))
            .thenAnswer((_) async => true);
        when(mockContentRepository.markBiteAsOpened(bite.id))
            .thenAnswer((_) async => {});
        when(mockContentRepository.trackBitePlay(bite.id))
            .thenAnswer((_) async => {});

        controller = HomeController();

        // Act
        await controller.onBiteTapped(bite);

        // Assert
        verify(mockContentRepository.hasUserAccessToBite(bite.id)).called(1);
        verify(mockContentRepository.markBiteAsOpened(bite.id)).called(1);
        verify(mockContentRepository.trackBitePlay(bite.id)).called(1);
      });

      test('should not mark bite as opened when user has no access', () async {
        // Arrange
        final bite = BiteModel(
          id: 'test-bite',
          title: 'Test Bite',
          description: 'Test Description',
          audioUrl: 'https://example.com/test.mp3',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          authorName: 'Test Author',
          date: DateTime.now(),
          isPremium: false,
          dayNumber: 1,
          category: 'Psychology',
          duration: 180,
        );

        when(mockContentRepository.hasUserAccessToBite(bite.id))
            .thenAnswer((_) async => false);

        controller = HomeController();

        // Act
        await controller.onBiteTapped(bite);

        // Assert
        verify(mockContentRepository.hasUserAccessToBite(bite.id)).called(1);
        verifyNever(mockContentRepository.markBiteAsOpened(bite.id));
        verifyNever(mockContentRepository.trackBitePlay(bite.id));
      });
    });

    group('refreshContent', () {
      test('should refresh content and update state', () async {
        // Arrange
        when(mockContentRepository.getTodaysBite())
            .thenAnswer((_) async => null);
        when(mockContentRepository.getCatchUpBites())
            .thenAnswer((_) async => <BiteModel>[]);

        controller = HomeController();
        await Future.delayed(Duration(milliseconds: 100));

        // Act
        await controller.refreshContent();

        // Assert
        expect(controller.state, equals(HomeScreenState.loaded));
        verify(mockContentRepository.getTodaysBite()).called(2); // Initial + refresh
        verify(mockContentRepository.getCatchUpBites()).called(2); // Initial + refresh
      });
    });
  });
}
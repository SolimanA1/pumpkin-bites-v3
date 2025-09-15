import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/repositories/content_repository_impl.dart';
import '../../lib/services/content_service.dart';
import '../../lib/services/user_progression_service.dart';
import '../../lib/models/bite_model.dart';
import '../../lib/core/service_locator.dart';

// Generate mocks
@GenerateMocks([ContentService, UserProgressionService])
import 'content_repository_test.mocks.dart';

void main() {
  group('ContentRepositoryImpl Tests', () {
    late ContentRepositoryImpl repository;
    late MockContentService mockContentService;
    late MockUserProgressionService mockProgressionService;

    setUp(() {
      // Reset service locator
      if (getIt.isRegistered<ContentService>()) {
        getIt.unregister<ContentService>();
      }
      if (getIt.isRegistered<UserProgressionService>()) {
        getIt.unregister<UserProgressionService>();
      }

      // Create mocks
      mockContentService = MockContentService();
      mockProgressionService = MockUserProgressionService();

      // Register mocks
      getIt.registerSingleton<ContentService>(mockContentService);
      getIt.registerSingleton<UserProgressionService>(mockProgressionService);

      // Create repository
      repository = ContentRepositoryImpl();
    });

    tearDown(() {
      getIt.reset();
    });

    group('getTodaysBite', () {
      test('should return today\'s bite when available', () async {
        // Arrange
        final expectedBite = BiteModel(
          id: 'test-bite-1',
          title: 'Test Bite',
          description: 'Test Description',
          audioUrl: 'https://example.com/audio.mp3',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          authorName: 'Test Author',
          date: DateTime.now(),
          isPremium: false,
          dayNumber: 1,
          category: 'Psychology',
          duration: 180,
        );

        when(mockContentService.getTodaysBite())
            .thenAnswer((_) async => expectedBite);

        // Act
        final result = await repository.getTodaysBite();

        // Assert
        expect(result, equals(expectedBite));
        verify(mockContentService.getTodaysBite()).called(1);
      });

      test('should return null when no bite available', () async {
        // Arrange
        when(mockContentService.getTodaysBite())
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getTodaysBite();

        // Assert
        expect(result, isNull);
        verify(mockContentService.getTodaysBite()).called(1);
      });

      test('should throw exception when service fails', () async {
        // Arrange
        when(mockContentService.getTodaysBite())
            .thenThrow(Exception('Service error'));

        // Act & Assert
        expect(
          () async => await repository.getTodaysBite(),
          throwsException,
        );
      });
    });

    group('getCatchUpBites', () {
      test('should return list of catch-up bites', () async {
        // Arrange
        final expectedBites = [
          BiteModel(
            id: 'bite-1',
            title: 'Bite 1',
            description: 'Description 1',
            audioUrl: 'https://example.com/audio1.mp3',
            thumbnailUrl: 'https://example.com/thumb1.jpg',
            authorName: 'Author 1',
            date: DateTime.now(),
            isPremium: false,
            dayNumber: 1,
            category: 'Psychology',
            duration: 180,
          ),
          BiteModel(
            id: 'bite-2',
            title: 'Bite 2',
            description: 'Description 2',
            audioUrl: 'https://example.com/audio2.mp3',
            thumbnailUrl: 'https://example.com/thumb2.jpg',
            authorName: 'Author 2',
            date: DateTime.now(),
            isPremium: false,
            dayNumber: 2,
            category: 'Philosophy',
            duration: 190,
          ),
        ];

        when(mockContentService.getCatchUpBites())
            .thenAnswer((_) async => expectedBites);

        // Act
        final result = await repository.getCatchUpBites();

        // Assert
        expect(result, equals(expectedBites));
        expect(result.length, equals(2));
        verify(mockContentService.getCatchUpBites()).called(1);
      });

      test('should return empty list when no catch-up bites', () async {
        // Arrange
        when(mockContentService.getCatchUpBites())
            .thenAnswer((_) async => <BiteModel>[]);

        // Act
        final result = await repository.getCatchUpBites();

        // Assert
        expect(result, isEmpty);
        verify(mockContentService.getCatchUpBites()).called(1);
      });
    });

    group('markBiteAsOpened', () {
      test('should mark bite as opened successfully', () async {
        // Arrange
        const biteId = 'test-bite-1';
        when(mockContentService.markBiteAsOpened(biteId))
            .thenAnswer((_) async => {});

        // Act
        await repository.markBiteAsOpened(biteId);

        // Assert
        verify(mockContentService.markBiteAsOpened(biteId)).called(1);
      });

      test('should throw exception when marking fails', () async {
        // Arrange
        const biteId = 'test-bite-1';
        when(mockContentService.markBiteAsOpened(biteId))
            .thenThrow(Exception('Failed to mark bite'));

        // Act & Assert
        expect(
          () async => await repository.markBiteAsOpened(biteId),
          throwsException,
        );
      });
    });

    group('getCommentCount', () {
      test('should return 0 as fallback (method not implemented yet)', () async {
        // Arrange
        const biteId = 'test-bite-1';
        const expectedCount = 0; // Always returns 0 as fallback

        // Act
        final result1 = await repository.getCommentCount(biteId);
        final result2 = await repository.getCommentCount(biteId);

        // Assert
        expect(result1, equals(expectedCount));
        expect(result2, equals(expectedCount));
        // No service calls since method is not implemented
      });
    });
  });
}
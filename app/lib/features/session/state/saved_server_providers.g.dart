// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_server_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(savedServerRepository)
final savedServerRepositoryProvider = SavedServerRepositoryProvider._();

final class SavedServerRepositoryProvider
    extends
        $FunctionalProvider<
          SavedServerRepository,
          SavedServerRepository,
          SavedServerRepository
        >
    with $Provider<SavedServerRepository> {
  SavedServerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedServerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedServerRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedServerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedServerRepository create(Ref ref) {
    return savedServerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedServerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedServerRepository>(value),
    );
  }
}

String _$savedServerRepositoryHash() =>
    r'007df689ad8d00e393741d048657d7bee0b4bfcc';

@ProviderFor(SavedServerController)
final savedServerControllerProvider = SavedServerControllerProvider._();

final class SavedServerControllerProvider
    extends $AsyncNotifierProvider<SavedServerController, String?> {
  SavedServerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedServerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedServerControllerHash();

  @$internal
  @override
  SavedServerController create() => SavedServerController();
}

String _$savedServerControllerHash() =>
    r'3d772db92505c64f0a6d79d9632f400c10148eda';

abstract class _$SavedServerController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rooms_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(roomsRepository)
final roomsRepositoryProvider = RoomsRepositoryProvider._();

final class RoomsRepositoryProvider
    extends
        $FunctionalProvider<RoomsRepository, RoomsRepository, RoomsRepository>
    with $Provider<RoomsRepository> {
  RoomsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomsRepositoryHash();

  @$internal
  @override
  $ProviderElement<RoomsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomsRepository create(Ref ref) {
    return roomsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomsRepository>(value),
    );
  }
}

String _$roomsRepositoryHash() => r'aa20c77a2919cf4c30bfe4de550f363eab7b95c1';

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

final class SyncServiceProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  SyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'syncServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return syncService(ref);
  }
}

String _$syncServiceHash() => r'071ae6c1fb0b795d0fca8ae41a4e66c08b31216a';

@ProviderFor(rooms)
final roomsProvider = RoomsProvider._();

final class RoomsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoomSummary>>,
          List<RoomSummary>,
          Stream<List<RoomSummary>>
        >
    with
        $FutureModifier<List<RoomSummary>>,
        $StreamProvider<List<RoomSummary>> {
  RoomsProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'roomsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomsHash();

  @$internal
  @override
  $StreamProviderElement<List<RoomSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoomSummary>> create(Ref ref) {
    return rooms(ref);
  }
}

String _$roomsHash() => r'f22ff34f5e58d2bacdeb9bf5c295d1abaf8420ab';

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusProvider._();

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'syncStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'5a9d4f2b0009955211861c000e7ff9c36e459015';

@ProviderFor(SelectedRoomId)
final selectedRoomIdProvider = SelectedRoomIdProvider._();

final class SelectedRoomIdProvider
    extends $NotifierProvider<SelectedRoomId, String?> {
  SelectedRoomIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedRoomIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedRoomIdHash();

  @$internal
  @override
  SelectedRoomId create() => SelectedRoomId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedRoomIdHash() => r'2652ed8ce23b7d6a2671fbce7af0488fc51869f0';

abstract class _$SelectedRoomId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(selectedRoom)
final selectedRoomProvider = SelectedRoomProvider._();

final class SelectedRoomProvider
    extends $FunctionalProvider<RoomSummary?, RoomSummary?, RoomSummary?>
    with $Provider<RoomSummary?> {
  SelectedRoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedRoomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedRoomHash();

  @$internal
  @override
  $ProviderElement<RoomSummary?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomSummary? create(Ref ref) {
    return selectedRoom(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomSummary? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomSummary?>(value),
    );
  }
}

String _$selectedRoomHash() => r'92ea00b3fac0ec2fca3c669aeadb088ce7c3b4e7';

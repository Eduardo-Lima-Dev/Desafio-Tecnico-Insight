// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encryption_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(encryptionRepository)
final encryptionRepositoryProvider = EncryptionRepositoryProvider._();

final class EncryptionRepositoryProvider
    extends
        $FunctionalProvider<
          EncryptionRepository,
          EncryptionRepository,
          EncryptionRepository
        >
    with $Provider<EncryptionRepository> {
  EncryptionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'encryptionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$encryptionRepositoryHash();

  @$internal
  @override
  $ProviderElement<EncryptionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EncryptionRepository create(Ref ref) {
    return encryptionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EncryptionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EncryptionRepository>(value),
    );
  }
}

String _$encryptionRepositoryHash() =>
    r'd029cd107b12f7fbc0b22b4c8badb8d3da78e094';

@ProviderFor(recoveryStatus)
final recoveryStatusProvider = RecoveryStatusProvider._();

final class RecoveryStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecoveryStatus>,
          RecoveryStatus,
          Stream<RecoveryStatus>
        >
    with $FutureModifier<RecoveryStatus>, $StreamProvider<RecoveryStatus> {
  RecoveryStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'recoveryStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveryStatusHash();

  @$internal
  @override
  $StreamProviderElement<RecoveryStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RecoveryStatus> create(Ref ref) {
    return recoveryStatus(ref);
  }
}

String _$recoveryStatusHash() => r'7834be99bcd8ce9eef8a18c6f0c1aa834c488b19';

@ProviderFor(RecoveryActions)
final recoveryActionsProvider = RecoveryActionsProvider._();

final class RecoveryActionsProvider
    extends $AsyncNotifierProvider<RecoveryActions, void> {
  RecoveryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recoveryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveryActionsHash();

  @$internal
  @override
  RecoveryActions create() => RecoveryActions();
}

String _$recoveryActionsHash() => r'0637283584c7dbda8dad3a705ee88b79e751c0ad';

abstract class _$RecoveryActions extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(conversationsRepository)
final conversationsRepositoryProvider = ConversationsRepositoryProvider._();

final class ConversationsRepositoryProvider
    extends
        $FunctionalProvider<
          ConversationsRepository,
          ConversationsRepository,
          ConversationsRepository
        >
    with $Provider<ConversationsRepository> {
  ConversationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConversationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationsRepository create(Ref ref) {
    return conversationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationsRepository>(value),
    );
  }
}

String _$conversationsRepositoryHash() =>
    r'b7467ca6f55e6f9909c2003892a86755e8cfbe44';

@ProviderFor(invites)
final invitesProvider = InvitesProvider._();

final class InvitesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoomInvite>>,
          List<RoomInvite>,
          Stream<List<RoomInvite>>
        >
    with $FutureModifier<List<RoomInvite>>, $StreamProvider<List<RoomInvite>> {
  InvitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'invitesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invitesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoomInvite>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoomInvite>> create(Ref ref) {
    return invites(ref);
  }
}

String _$invitesHash() => r'76d0981f899bca3b72c3a882d484a7f3508d6d63';

@ProviderFor(ConversationCreator)
final conversationCreatorProvider = ConversationCreatorProvider._();

final class ConversationCreatorProvider
    extends $AsyncNotifierProvider<ConversationCreator, void> {
  ConversationCreatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationCreatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationCreatorHash();

  @$internal
  @override
  ConversationCreator create() => ConversationCreator();
}

String _$conversationCreatorHash() =>
    r'c58c765967df8be560abc72943c09d4958175ddd';

abstract class _$ConversationCreator extends $AsyncNotifier<void> {
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

@ProviderFor(InviteActions)
final inviteActionsProvider = InviteActionsProvider._();

final class InviteActionsProvider
    extends $AsyncNotifierProvider<InviteActions, void> {
  InviteActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteActionsHash();

  @$internal
  @override
  InviteActions create() => InviteActions();
}

String _$inviteActionsHash() => r'ae32b150ae0d3f2629c88cd943630d4a6d5a0781';

abstract class _$InviteActions extends $AsyncNotifier<void> {
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

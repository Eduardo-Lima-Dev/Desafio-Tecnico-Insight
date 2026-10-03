enum ConversationFailure implements Exception {
  invalidUser,
  selfConversation,
  userNotFound,
  sessionExpired,
  unknown,
}

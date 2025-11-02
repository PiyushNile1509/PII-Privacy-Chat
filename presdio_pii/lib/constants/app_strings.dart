class AppStrings {
  static const String appTitle = 'PII Privacy Handler';
  static const String appName = 'PII Privacy Chat';
  static const String appTagline = 'Secure • Private • Protected';
  
  static const String privacyProtectionTitle = 'PII Privacy Protection';
  static const String protectionStepsMessage = 'Your messages are protected through 4 secure steps';
  static const String protectionStepsEmoji = '📝 Input → 🔒 Masked → 💡 AI Response → ✅ Reconstructed';
  
  static const String messageInputHint = 'Message PII Privacy Chat...';
  static const String processingMessage = 'Processing with PII Protection...';
  
  static const String stepDetect = 'Detect';
  static const String stepMask = 'Mask';
  static const String stepProcess = 'Process';
  static const String stepRespond = 'Respond';
  
  static const String connectionIssueTitle = 'Connection Issue';
  static const String connectionIssueMessage = 'Unable to connect to server. Please check your internet connection and try again.';
  static const String buttonOk = 'OK';
  
  static const String messageDetailsTitle = 'Message Details';
  static const String originalMessage = 'Original Message';
  static const String anonymizedText = 'Anonymized Text / LLM Prompt';
  static const String aiResponse = 'AI Response';
  static const String reconstructedText = 'Reconstructed Text';
  
  static const String privacyScore = 'Privacy Score';
  static const String processingTime = 'Processing Time';
  static const String timestamp = 'Timestamp';
  static const String copiedToClipboard = 'Copied to clipboard';
  static const String noContentAvailable = 'No content available';
  
  static const String chatHistory = 'Chat History';
  static const String clearHistory = 'Clear History';
  static const String clearHistoryConfirm = 'Are you sure you want to clear all chat history? This action cannot be undone.';
  static const String buttonCancel = 'Cancel';
  static const String buttonClear = 'Clear';
  static const String historyClearedSuccess = 'History cleared successfully';
  static const String noChatHistory = 'No chat history yet.\nStart a conversation to see your messages here.';
  
  static const String noChatsYet = 'No chats yet';
  static const String startNewConversation = 'Start a new conversation to begin';
  static const String updatedPrefix = 'Updated ';
  
  static const String deleteChat = 'Delete Chat';
  static const String deleteChatConfirm = 'Are you sure you want to delete';
  static const String buttonDelete = 'Delete';
  
  static const String renameChat = 'Rename Chat';
  static const String enterNewName = 'Enter new name';
  static const String buttonRename = 'Rename';
  static const String chatRenamedSuccess = 'Chat renamed successfully';
  
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String daysAgoSuffix = 'd ago';
  
  static const String piiMasked = 'PII Masked';
  static const String piiProtectedVersion = 'PII Protected Version:';
  
  static const String errorPrefix = 'Error: ';
  static const String errorCreatingChat = 'Error creating chat: ';
  static const String errorDeletingChat = 'Error deleting chat: ';
  static const String errorRenamingChat = 'Error renaming chat: ';
  static const String errorClearingHistory = 'Error clearing history: ';
  
  static const String newChat = 'New Chat';
  
  static String privacyScoreWithValue(double score) => 'Privacy Score: ${score.toStringAsFixed(1)}%';
  static String processingTimeWithValue(double time) => 'Processing Time: ${time.toStringAsFixed(2)}s';
  static String privacyWithValue(double score) => 'Privacy: ${score.toStringAsFixed(0)}%';
  static String processingTimeShort(double time) => '${time.toStringAsFixed(1)}s';
  static String chatHistoryCount(int count) => 'Chat History ($count)';
  static String deleteChatConfirmWithTitle(String title) => 'Are you sure you want to delete "$title"?';
  static String daysAgo(int days) => '${days}d ago';
  static String dateFormat(int day, int month) => '$day/$month';
  static String fullDateFormat(int day, int month, int year) => '$day/$month/$year';
}

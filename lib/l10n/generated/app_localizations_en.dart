// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GitNote';

  @override
  String get notes => 'Notes';

  @override
  String get search => 'Search';

  @override
  String get repository => 'Repository';

  @override
  String get settings => 'Settings';

  @override
  String get versionLabel => 'v0.1.0';

  @override
  String get untitledNote => 'Untitled note';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get newNote => 'New note';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

  @override
  String get syncToRemote => 'Sync to remote';

  @override
  String get manageTags => 'Manage tags';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get enterTitle => 'Enter a title...';

  @override
  String get addTag => 'Add tag';

  @override
  String get addTagButton => '+ Tag';

  @override
  String get enterTagName => 'Enter a tag name';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get startWriting => 'Start writing... (Markdown supported)';

  @override
  String wordCountFooter(int count, String time) {
    return '$count chars · $time';
  }

  @override
  String get configureGitFirst => 'Please configure Git first';

  @override
  String get syncSuccess => 'Sync complete';

  @override
  String syncFailedMessage(String error) {
    return 'Sync failed: $error';
  }

  @override
  String deleteFailedMessage(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get markdownReady => 'Markdown content is ready to export';

  @override
  String get confirmDelete => 'Confirm delete';

  @override
  String confirmDeleteNote(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get all => 'All';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get createFirstNote => 'Tap + to create your first note';

  @override
  String get pin => 'Pin';

  @override
  String get localStatus => 'Local';

  @override
  String get conflictStatus => 'Conflict';

  @override
  String get noContent => 'No content';

  @override
  String get sortByUpdated => 'Recently updated';

  @override
  String get sortByCreated => 'Created time';

  @override
  String get sortByTitle => 'Title';

  @override
  String get syncInProgress => 'Syncing...';

  @override
  String get syncFailedShort => 'Sync failed';

  @override
  String lastSyncedAt(String date) {
    return 'Last synced: $date';
  }

  @override
  String get neverSynced => 'Not synced yet';

  @override
  String get repositoryManagement => 'Repository';

  @override
  String get notConnected => 'Not connected';

  @override
  String get connected => 'Connected';

  @override
  String get configureGitPlatformInSettings =>
      'Configure your Git platform in Settings';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get syncStats => 'Sync stats';

  @override
  String get syncLogs => 'Sync logs';

  @override
  String get pullRemote => 'Pull remote';

  @override
  String get pushLocal => 'Push local';

  @override
  String get fullSync => 'Full sync';

  @override
  String get repositorySettings => 'Repository settings';

  @override
  String get totalNotes => 'Total notes';

  @override
  String get unsyncedNotes => 'Unsynced';

  @override
  String get syncedNotes => 'Synced';

  @override
  String get conflicts => 'Conflicts';

  @override
  String get noSyncLogs => 'No sync logs yet';

  @override
  String pulledRemoteNotes(int count) {
    return 'Pulled $count remote notes successfully';
  }

  @override
  String pushSummary(int successCount, int totalCount) {
    return 'Pushed $successCount/$totalCount notes successfully';
  }

  @override
  String fullSyncSummary(int count) {
    return 'Full sync finished, pulled $count remote notes';
  }

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get enterKeywordToSearch => 'Enter keywords to search notes';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clear => 'Clear';

  @override
  String get noSearchResults => 'No matching notes found';

  @override
  String searchResultsCount(int count) {
    return '$count results';
  }

  @override
  String get gitPlatformConfig => 'Git platform';

  @override
  String get platform => 'Platform';

  @override
  String get accessToken => 'Access Token';

  @override
  String get enterToken => 'Enter token';

  @override
  String get ownerOrOrg => 'Owner / Org';

  @override
  String get ownerHint => 'e.g. username';

  @override
  String get repoName => 'Repository';

  @override
  String get repoHint => 'e.g. my-notes';

  @override
  String get branch => 'Branch';

  @override
  String get branchHint => 'Default: main';

  @override
  String get notesDirectory => 'Notes directory';

  @override
  String get notesDirectoryHint => 'Default: notes';

  @override
  String get testConnection => 'Test connection';

  @override
  String get connectedShort => 'Connected';

  @override
  String get saveConfig => 'Save config';

  @override
  String get syncSettings => 'Sync settings';

  @override
  String get autoSync => 'Auto sync';

  @override
  String get autoSyncDescription => 'Pull remote notes on app launch';

  @override
  String get autoPush => 'Auto push while editing';

  @override
  String get autoPushDescription => 'Push changes after saving notes';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get clearAllData => 'Clear all data';

  @override
  String get choosePlatform => 'Choose platform';

  @override
  String get saved => 'Saved';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get warning => 'Warning';

  @override
  String get clearAllConfirm => 'Clear all local data? This cannot be undone.';

  @override
  String get cleared => 'Cleared';

  @override
  String get loading => 'Loading...';

  @override
  String get tokenHelpTitle => 'Access Token Help';

  @override
  String get tokenHelpButton => 'How to get an Access Token';

  @override
  String get tokenHelpIntro =>
      'GitNote needs an access token to read and update your configured notes repository. Prefer granting access only to the notes repository, and treat the token like a password.';

  @override
  String get githubTokenTitle => 'GitHub';

  @override
  String get githubTokenStep1 =>
      'Open GitHub, click your profile picture in the upper-right corner, then open Settings.';

  @override
  String get githubTokenStep2 =>
      'Open Developer settings > Personal access tokens > Fine-grained tokens.';

  @override
  String get githubTokenStep3 =>
      'Click Generate new token, then fill in Token name and Expiration.';

  @override
  String get githubTokenStep4 =>
      'For Repository access, select the repository GitNote will use.';

  @override
  String get githubTokenStep5 =>
      'Under Repository permissions, set Contents to Read and write, then generate and copy the token.';

  @override
  String get githubClassicTokenTip =>
      'If you use a classic token, select the repo scope. A fine-grained token is better when GitNote only needs one notes repository.';

  @override
  String get githubTokenOfficialEntrance =>
      'Official entry: https://github.com/settings/personal-access-tokens';

  @override
  String get giteeTokenTitle => 'Gitee';

  @override
  String get giteeTokenStep1 =>
      'Open Gitee, click your profile picture in the upper-right corner, then open Settings.';

  @override
  String get giteeTokenStep2 =>
      'Open Security settings > Personal access tokens, then click Generate new token.';

  @override
  String get giteeTokenStep3 =>
      'Fill in a token description and choose a suitable expiration time.';

  @override
  String get giteeTokenStep4 =>
      'Select the project permission so GitNote can read, create, and update files in the notes repository.';

  @override
  String get giteeTokenStep5 =>
      'Click Submit, complete password verification, then copy the generated personal token.';

  @override
  String get giteeTokenTip =>
      'The Gitee personal token is the Access Token to paste here. If the repository belongs to an organization, make sure your account can access it.';

  @override
  String get giteeTokenOfficialEntrance =>
      'Official entry: https://gitee.com/profile/personal_access_tokens';

  @override
  String get tokenSafetyTitle => 'Save and paste';

  @override
  String get tokenSafetyBody =>
      'Tokens are usually shown in full only once, so copy and save yours immediately. Do not put it in public notes, screenshots, or commits. If it may have leaked, delete the old token and generate a new one.';

  @override
  String get tokenPasteTip =>
      'After copying it, return to Settings, paste it into Access Token, save the configuration, and test the connection.';

  @override
  String get reminder => 'Assistant';

  @override
  String get reminders => 'Assistants';

  @override
  String get addReminder => 'Add Assistant';

  @override
  String get editReminder => 'Edit Assistant';

  @override
  String get reminderTitle => 'Title';

  @override
  String get reminderTime => 'Reminder Time';

  @override
  String get reminderRepeat => 'Repeat';

  @override
  String get reminderEnabled => 'Enabled';

  @override
  String get reminderNone => 'None';

  @override
  String get reminderDaily => 'Daily';

  @override
  String get reminderWeekly => 'Weekly';

  @override
  String get reminderMonthly => 'Monthly';

  @override
  String get reminderWeekdays => 'Weekdays';

  @override
  String get reminderInterval => 'Interval';

  @override
  String reminderIntervalEvery(String duration) {
    return 'Every $duration';
  }

  @override
  String durationHours(int count) {
    return '$count hr';
  }

  @override
  String durationMinutes(int count) {
    return '$count min';
  }

  @override
  String get reminderIntervalHoursLabel => 'Hours';

  @override
  String get reminderIntervalMinutesLabel => 'Minutes';

  @override
  String get reminderIntervalHint =>
      'Starts timing when saved, then repeats at the chosen interval';

  @override
  String get reminderCustom => 'Custom';

  @override
  String get noRemindersYet => 'No assistants yet';

  @override
  String get createFirstReminder =>
      'Tap + in the top-right corner to create your first assistant';

  @override
  String get deleteReminder => 'Delete Assistant';

  @override
  String confirmDeleteReminder(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get reminderSaved => 'Assistant saved';

  @override
  String get enterReminderTitle => 'Enter a title...';

  @override
  String get selectTime => 'Select time';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'OK';

  @override
  String get windowSettings => 'Window';

  @override
  String get closeButtonAction => 'When closing the main window';

  @override
  String get closeActionAsk => 'Ask every time';

  @override
  String get closeActionMinimize => 'Minimize to system tray';

  @override
  String get closeActionExit => 'Exit the app';

  @override
  String get closeDialogTitle => 'Close GitNote';

  @override
  String get closeDialogMessage =>
      'Choose what happens when you click the close button:';

  @override
  String get closeDialogRemember => 'Don\'t ask again (changeable in Settings)';

  @override
  String get trayShowWindow => 'Show GitNote';

  @override
  String get trayExit => 'Exit';

  @override
  String get openInNewWindow => 'Open in new window';

  @override
  String get noteDetachedTooltip => 'Opened in a separate window';

  @override
  String get noteDetachedBanner =>
      'This note is being edited in a separate window and is read-only here';

  @override
  String get focusNoteWindow => 'Focus window';

  @override
  String noteWindowWordCount(int count) {
    return '$count chars';
  }

  @override
  String get noteWindowPinToTop => 'Keep on top';

  @override
  String get noteWindowUnpinFromTop => 'Stop keeping on top';

  @override
  String get noteWindowOpacity => 'Window opacity';

  @override
  String noteWindowOpacityValue(int percent) {
    return '$percent%';
  }

  @override
  String get noteWindowUnreachable =>
      'Cannot reach the main window; edits are not being saved';
}

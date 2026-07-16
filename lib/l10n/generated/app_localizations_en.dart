// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'casual';

  @override
  String get notes => 'Notes';

  @override
  String get search => 'Search';

  @override
  String get repository => 'Repository';

  @override
  String get plan => 'Plan';

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
  String get openMarkdownFile => 'Open Markdown file';

  @override
  String get markdownEditOnly => 'Edit only';

  @override
  String get markdownSplitView => 'Split edit and preview';

  @override
  String get markdownPreviewOnly => 'Preview only';

  @override
  String get showMarkdownToolbar => 'Show formatting toolbar';

  @override
  String get hideMarkdownToolbar => 'Hide formatting toolbar';

  @override
  String get enterMarkdownFocus => 'Full-screen edit/preview';

  @override
  String get exitMarkdownFocus => 'Exit full-screen edit/preview';

  @override
  String get saveMarkdownFile => 'Save (Ctrl+S)';

  @override
  String get externalMarkdownReadOnly =>
      'External Markdown files are opened read-only on this platform. Edit and save the original file on Windows desktop.';

  @override
  String get externalMarkdownContentHint => 'Markdown content';

  @override
  String get externalMarkdownSaved => 'Saved to the original Markdown file';

  @override
  String externalMarkdownSaveFailed(String error) {
    return 'Could not save the Markdown file: $error';
  }

  @override
  String externalMarkdownOpenFailed(String error) {
    return 'Could not open the Markdown file: $error';
  }

  @override
  String get discardUnsavedChangesTitle => 'Discard unsaved changes?';

  @override
  String get discardExternalMarkdownMessage =>
      'This external Markdown file has not been saved to your computer.';

  @override
  String get continueEditing => 'Keep editing';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get missingExternalMarkdown => 'No Markdown file was selected';

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
  String get repositoryManagementDescription =>
      'Sync notes and review sync stats and logs';

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
  String get syncConflictTitle => 'Sync Conflict';

  @override
  String get syncConflictLocalTime => 'Local version';

  @override
  String get syncConflictRemoteTime => 'Remote version';

  @override
  String get syncConflictTimeUnknown => 'Unknown';

  @override
  String get syncConflictDescription =>
      'Both local and remote versions have been modified. Please choose which version to keep.';

  @override
  String get syncConflictKeepLocal => 'Keep Local';

  @override
  String get syncConflictTakeRemote => 'Use Remote';

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
  String get gitPlatformConfigDescription =>
      'Configure GitHub or Gitee connection details';

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
  String get checkForUpdate => 'Check for updates';

  @override
  String get checkingForUpdate => 'Checking for updates...';

  @override
  String get updateAvailable => 'New version available';

  @override
  String get upToDate => 'You are on the latest version';

  @override
  String updateNewVersion(String version) {
    return 'Version $version';
  }

  @override
  String updateCurrentVersion(String version) {
    return 'Current version $version';
  }

  @override
  String get updateReleaseNotes => 'Release notes';

  @override
  String get updateDownloadInstall => 'Download & install';

  @override
  String get updateDownloading => 'Downloading...';

  @override
  String get updateInstallNow => 'Install now';

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get updateLater => 'Later';

  @override
  String get updateWindowsZipHint =>
      'After download, extract the archive and replace the existing app files.';

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
      'casual needs an access token to read and update your configured notes repository. Prefer granting access only to the notes repository, and treat the token like a password.';

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
      'For Repository access, select the repository casual will use.';

  @override
  String get githubTokenStep5 =>
      'Under Repository permissions, set Contents to Read and write, then generate and copy the token.';

  @override
  String get githubClassicTokenTip =>
      'If you use a classic token, select the repo scope. A fine-grained token is better when casual only needs one notes repository.';

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
      'Select the project permission so casual can read, create, and update files in the notes repository.';

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
      'After copying it, return to Git platform, paste it into Access Token, save the configuration, and test the connection.';

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
  String reminderSaveFailed(String error) {
    return 'Failed to save assistant: $error';
  }

  @override
  String get enterReminderTitle => 'Enter a title...';

  @override
  String get reminderAlarmTitle => 'Reminder due';

  @override
  String get reminderAlarmDefaultBody => 'Time to handle this assistant';

  @override
  String get reminderAlarmSource => 'Local assistant reminder';

  @override
  String get reminderAlarmLater => 'Remind later';

  @override
  String get reminderAlarmAcknowledge => 'Got it';

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
  String get closeDialogTitle => 'Close casual';

  @override
  String get closeDialogMessage =>
      'Choose what happens when you click the close button:';

  @override
  String get closeDialogRemember => 'Don\'t ask again (changeable in Settings)';

  @override
  String get trayShowWindow => 'Show casual';

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
  String get noteWindowMove => 'Move window';

  @override
  String get noteWindowMinimize => 'Minimize window';

  @override
  String get noteWindowMaximize => 'Maximize window';

  @override
  String get noteWindowRestore => 'Restore window';

  @override
  String get noteWindowClose => 'Close window';

  @override
  String get noteWindowUnreachable =>
      'Cannot reach the main window; edits are not being saved';

  @override
  String get openAsTagWindow => 'Open as sticky tag';

  @override
  String get noteTagExpand => 'Expand note';

  @override
  String get noteTagCollapse => 'Collapse to tag';

  @override
  String get planPageSubtitle =>
      'Break one goal into ordered steps and move it forward on a clear timeline.';

  @override
  String get createPlan => 'New plan';

  @override
  String get planFilterActive => 'Active';

  @override
  String get planFilterOverdue => 'Overdue';

  @override
  String get planFilterCompleted => 'Completed';

  @override
  String get planFilterTerminated => 'Terminated';

  @override
  String get planNoPlansYet => 'No plans yet';

  @override
  String get planCreateFirst =>
      'Create a plan and start recording its progress.';

  @override
  String get planSelectPrompt => 'Select a plan to view its timeline';

  @override
  String get planTitleLabel => 'Plan title';

  @override
  String get planTitleHint => 'For example: Release casual 1.0';

  @override
  String get planGoalLabel => 'Goal';

  @override
  String get planGoalHint => 'Describe the concrete result you want to achieve';

  @override
  String get planStartAt => 'Start time';

  @override
  String get planDeadline => 'Deadline';

  @override
  String get planReminder => 'Deadline reminder';

  @override
  String get planReminderOff => 'No reminder';

  @override
  String get planReminderAtDeadline => 'At deadline';

  @override
  String get planReminderOneHourBefore => '1 hour before';

  @override
  String get planReminderOneDayBefore => '1 day before';

  @override
  String get planReminderCustom => 'Custom';

  @override
  String get planReminderMinutes => 'Minutes before deadline';

  @override
  String get planReminderMinutesHint => 'Enter a number from 1 to 525600';

  @override
  String get planEdit => 'Edit plan';

  @override
  String get planOverview => 'Overview';

  @override
  String get planProgress => 'Progress';

  @override
  String get planTimeline => 'Timeline';

  @override
  String get planUpdateProgress => 'Update progress';

  @override
  String get planAddRecord => 'Add record';

  @override
  String get planComplete => 'Complete plan';

  @override
  String get planTerminate => 'Terminate plan';

  @override
  String get planDelete => 'Delete plan';

  @override
  String get planRecordHint => 'Record a result, issue, or next step...';

  @override
  String get planProgressNoteHint =>
      'Optional note for this progress update...';

  @override
  String get planOptionalNote => 'Optional note';

  @override
  String get planTerminationReason => 'Termination reason (optional)';

  @override
  String get planStatusNotStarted => 'Not started';

  @override
  String get planStatusInProgress => 'In progress';

  @override
  String get planStatusOverdue => 'Overdue';

  @override
  String get planStatusCompleted => 'Completed';

  @override
  String get planStatusTerminated => 'Terminated';

  @override
  String get planTimelineCreated => 'Plan created';

  @override
  String get planTimelineDetailsUpdated => 'Plan details updated';

  @override
  String planTimelineProgress(int progress) {
    return 'Progress updated to $progress%';
  }

  @override
  String get planTimelineRecord => 'Execution record';

  @override
  String get planTimelineCompleted => 'Plan completed';

  @override
  String get planTimelineTerminated => 'Plan terminated';

  @override
  String planRemainingDays(int count) {
    return '$count days remaining';
  }

  @override
  String planRemainingHours(int count) {
    return '$count hours remaining';
  }

  @override
  String get planDueSoon => 'Due soon';

  @override
  String planOverdueDays(int count) {
    return '$count days overdue';
  }

  @override
  String get planValidateTitle => 'Enter a plan title';

  @override
  String get planValidateGoal => 'Enter a concrete goal';

  @override
  String get planValidateDeadline =>
      'Deadline must be later than the start time';

  @override
  String get planValidateReminder => 'Enter valid reminder minutes';

  @override
  String get planSaveSuccess => 'Plan saved';

  @override
  String get planDeleteSuccess => 'Plan deleted';

  @override
  String planOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get planConfirmComplete =>
      'Mark this plan as completed? Its progress will be set to 100%.';

  @override
  String get planConfirmTerminate =>
      'Terminate this plan? Its current progress and history will be kept.';

  @override
  String planConfirmDelete(String title) {
    return 'Delete \"$title\"? This will also remove its timeline.';
  }

  @override
  String get planRecordRequired => 'Enter an execution record';

  @override
  String get planCreatedAt => 'Created';

  @override
  String get planSteps => 'Plan steps';

  @override
  String get planActivity => 'Activity';

  @override
  String get planAddStep => 'Add step';

  @override
  String get planRemoveStep => 'Remove step';

  @override
  String get planReorderStep => 'Drag to reorder';

  @override
  String planStepNumber(int index) {
    return 'Step $index';
  }

  @override
  String get planStepTitle => 'Step title';

  @override
  String get planStepTitleHint => 'Describe the result of this step';

  @override
  String get planStepTarget => 'Expected completion time';

  @override
  String planCompletedSteps(int completed, int total) {
    return '$completed/$total steps completed';
  }

  @override
  String get planNextStep => 'Next step';

  @override
  String get planNoNextStep => 'All steps completed';

  @override
  String get planFinalDeadline => 'Final deadline';

  @override
  String get planStepStatusPending => 'Pending';

  @override
  String get planStepStatusOverdue => 'Overdue';

  @override
  String get planStepStatusCompleted => 'Completed';

  @override
  String get planCompleteStep => 'Complete step';

  @override
  String get planReopenStep => 'Reopen step';

  @override
  String get planConfirmReopenStep =>
      'Reopen this step? The plan progress and status will be recalculated.';

  @override
  String get planStepCompletionNote => 'Completion note (optional)';

  @override
  String planStepCompletedAt(String time) {
    return 'Completed at $time';
  }

  @override
  String get planValidateStepTitle => 'Enter a title for every step';

  @override
  String get planValidateStepBeforeStart =>
      'Step time cannot be earlier than the plan start time';

  @override
  String get planValidateStepOrder =>
      'Each step time must be no earlier than the previous step';

  @override
  String get planAtLeastOneStep => 'A plan must contain at least one step';

  @override
  String get planTimelineStepsUpdated => 'Plan steps updated';

  @override
  String planTimelineStepCompleted(String step) {
    return 'Completed step: $step';
  }

  @override
  String planTimelineStepReopened(String step) {
    return 'Reopened step: $step';
  }

  @override
  String planTimelineLegacyProgress(int progress) {
    return 'Legacy progress $progress% migrated to a plan step';
  }
}

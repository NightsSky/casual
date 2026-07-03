import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'casual'**
  String get appTitle;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @repository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get repository;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'v0.1.0'**
  String get versionLabel;

  /// No description provided for @untitledNote.
  ///
  /// In en, this message translates to:
  /// **'Untitled note'**
  String get untitledNote;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @syncToRemote.
  ///
  /// In en, this message translates to:
  /// **'Sync to remote'**
  String get syncToRemote;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get manageTags;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get exportMarkdown;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title...'**
  String get enterTitle;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @addTagButton.
  ///
  /// In en, this message translates to:
  /// **'+ Tag'**
  String get addTagButton;

  /// No description provided for @enterTagName.
  ///
  /// In en, this message translates to:
  /// **'Enter a tag name'**
  String get enterTagName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @startWriting.
  ///
  /// In en, this message translates to:
  /// **'Start writing... (Markdown supported)'**
  String get startWriting;

  /// No description provided for @wordCountFooter.
  ///
  /// In en, this message translates to:
  /// **'{count} chars · {time}'**
  String wordCountFooter(int count, String time);

  /// No description provided for @configureGitFirst.
  ///
  /// In en, this message translates to:
  /// **'Please configure Git first'**
  String get configureGitFirst;

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncSuccess;

  /// No description provided for @syncFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailedMessage(String error);

  /// No description provided for @deleteFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedMessage(String error);

  /// No description provided for @markdownReady.
  ///
  /// In en, this message translates to:
  /// **'Markdown content is ready to export'**
  String get markdownReady;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String confirmDeleteNote(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// No description provided for @createFirstNote.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first note'**
  String get createFirstNote;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @localStatus.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localStatus;

  /// No description provided for @conflictStatus.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get conflictStatus;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get noContent;

  /// No description provided for @sortByUpdated.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get sortByUpdated;

  /// No description provided for @sortByCreated.
  ///
  /// In en, this message translates to:
  /// **'Created time'**
  String get sortByCreated;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortByTitle;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncInProgress;

  /// No description provided for @syncFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailedShort;

  /// No description provided for @lastSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {date}'**
  String lastSyncedAt(String date);

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get neverSynced;

  /// No description provided for @repositoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get repositoryManagement;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @configureGitPlatformInSettings.
  ///
  /// In en, this message translates to:
  /// **'Configure your Git platform in Settings'**
  String get configureGitPlatformInSettings;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @syncStats.
  ///
  /// In en, this message translates to:
  /// **'Sync stats'**
  String get syncStats;

  /// No description provided for @syncLogs.
  ///
  /// In en, this message translates to:
  /// **'Sync logs'**
  String get syncLogs;

  /// No description provided for @pullRemote.
  ///
  /// In en, this message translates to:
  /// **'Pull remote'**
  String get pullRemote;

  /// No description provided for @pushLocal.
  ///
  /// In en, this message translates to:
  /// **'Push local'**
  String get pushLocal;

  /// No description provided for @fullSync.
  ///
  /// In en, this message translates to:
  /// **'Full sync'**
  String get fullSync;

  /// No description provided for @repositorySettings.
  ///
  /// In en, this message translates to:
  /// **'Repository settings'**
  String get repositorySettings;

  /// No description provided for @totalNotes.
  ///
  /// In en, this message translates to:
  /// **'Total notes'**
  String get totalNotes;

  /// No description provided for @unsyncedNotes.
  ///
  /// In en, this message translates to:
  /// **'Unsynced'**
  String get unsyncedNotes;

  /// No description provided for @syncedNotes.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedNotes;

  /// No description provided for @conflicts.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get conflicts;

  /// No description provided for @noSyncLogs.
  ///
  /// In en, this message translates to:
  /// **'No sync logs yet'**
  String get noSyncLogs;

  /// No description provided for @pulledRemoteNotes.
  ///
  /// In en, this message translates to:
  /// **'Pulled {count} remote notes successfully'**
  String pulledRemoteNotes(int count);

  /// No description provided for @pushSummary.
  ///
  /// In en, this message translates to:
  /// **'Pushed {successCount}/{totalCount} notes successfully'**
  String pushSummary(int successCount, int totalCount);

  /// No description provided for @fullSyncSummary.
  ///
  /// In en, this message translates to:
  /// **'Full sync finished, pulled {count} remote notes'**
  String fullSyncSummary(int count);

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get searchNotes;

  /// No description provided for @enterKeywordToSearch.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search notes'**
  String get enterKeywordToSearch;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching notes found'**
  String get noSearchResults;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String searchResultsCount(int count);

  /// No description provided for @gitPlatformConfig.
  ///
  /// In en, this message translates to:
  /// **'Git platform'**
  String get gitPlatformConfig;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access Token'**
  String get accessToken;

  /// No description provided for @enterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter token'**
  String get enterToken;

  /// No description provided for @ownerOrOrg.
  ///
  /// In en, this message translates to:
  /// **'Owner / Org'**
  String get ownerOrOrg;

  /// No description provided for @ownerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. username'**
  String get ownerHint;

  /// No description provided for @repoName.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get repoName;

  /// No description provided for @repoHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. my-notes'**
  String get repoHint;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @branchHint.
  ///
  /// In en, this message translates to:
  /// **'Default: main'**
  String get branchHint;

  /// No description provided for @notesDirectory.
  ///
  /// In en, this message translates to:
  /// **'Notes directory'**
  String get notesDirectory;

  /// No description provided for @notesDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Default: notes'**
  String get notesDirectoryHint;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @connectedShort.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedShort;

  /// No description provided for @saveConfig.
  ///
  /// In en, this message translates to:
  /// **'Save config'**
  String get saveConfig;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync settings'**
  String get syncSettings;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get autoSync;

  /// No description provided for @autoSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Pull remote notes on app launch'**
  String get autoSyncDescription;

  /// No description provided for @autoPush.
  ///
  /// In en, this message translates to:
  /// **'Auto push while editing'**
  String get autoPush;

  /// No description provided for @autoPushDescription.
  ///
  /// In en, this message translates to:
  /// **'Push changes after saving notes'**
  String get autoPushDescription;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear all data'**
  String get clearAllData;

  /// No description provided for @choosePlatform.
  ///
  /// In en, this message translates to:
  /// **'Choose platform'**
  String get choosePlatform;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all local data? This cannot be undone.'**
  String get clearAllConfirm;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get cleared;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @tokenHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Token Help'**
  String get tokenHelpTitle;

  /// No description provided for @tokenHelpButton.
  ///
  /// In en, this message translates to:
  /// **'How to get an Access Token'**
  String get tokenHelpButton;

  /// No description provided for @tokenHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'casual needs an access token to read and update your configured notes repository. Prefer granting access only to the notes repository, and treat the token like a password.'**
  String get tokenHelpIntro;

  /// No description provided for @githubTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get githubTokenTitle;

  /// No description provided for @githubTokenStep1.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub, click your profile picture in the upper-right corner, then open Settings.'**
  String get githubTokenStep1;

  /// No description provided for @githubTokenStep2.
  ///
  /// In en, this message translates to:
  /// **'Open Developer settings > Personal access tokens > Fine-grained tokens.'**
  String get githubTokenStep2;

  /// No description provided for @githubTokenStep3.
  ///
  /// In en, this message translates to:
  /// **'Click Generate new token, then fill in Token name and Expiration.'**
  String get githubTokenStep3;

  /// No description provided for @githubTokenStep4.
  ///
  /// In en, this message translates to:
  /// **'For Repository access, select the repository casual will use.'**
  String get githubTokenStep4;

  /// No description provided for @githubTokenStep5.
  ///
  /// In en, this message translates to:
  /// **'Under Repository permissions, set Contents to Read and write, then generate and copy the token.'**
  String get githubTokenStep5;

  /// No description provided for @githubClassicTokenTip.
  ///
  /// In en, this message translates to:
  /// **'If you use a classic token, select the repo scope. A fine-grained token is better when casual only needs one notes repository.'**
  String get githubClassicTokenTip;

  /// No description provided for @githubTokenOfficialEntrance.
  ///
  /// In en, this message translates to:
  /// **'Official entry: https://github.com/settings/personal-access-tokens'**
  String get githubTokenOfficialEntrance;

  /// No description provided for @giteeTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Gitee'**
  String get giteeTokenTitle;

  /// No description provided for @giteeTokenStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Gitee, click your profile picture in the upper-right corner, then open Settings.'**
  String get giteeTokenStep1;

  /// No description provided for @giteeTokenStep2.
  ///
  /// In en, this message translates to:
  /// **'Open Security settings > Personal access tokens, then click Generate new token.'**
  String get giteeTokenStep2;

  /// No description provided for @giteeTokenStep3.
  ///
  /// In en, this message translates to:
  /// **'Fill in a token description and choose a suitable expiration time.'**
  String get giteeTokenStep3;

  /// No description provided for @giteeTokenStep4.
  ///
  /// In en, this message translates to:
  /// **'Select the project permission so casual can read, create, and update files in the notes repository.'**
  String get giteeTokenStep4;

  /// No description provided for @giteeTokenStep5.
  ///
  /// In en, this message translates to:
  /// **'Click Submit, complete password verification, then copy the generated personal token.'**
  String get giteeTokenStep5;

  /// No description provided for @giteeTokenTip.
  ///
  /// In en, this message translates to:
  /// **'The Gitee personal token is the Access Token to paste here. If the repository belongs to an organization, make sure your account can access it.'**
  String get giteeTokenTip;

  /// No description provided for @giteeTokenOfficialEntrance.
  ///
  /// In en, this message translates to:
  /// **'Official entry: https://gitee.com/profile/personal_access_tokens'**
  String get giteeTokenOfficialEntrance;

  /// No description provided for @tokenSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Save and paste'**
  String get tokenSafetyTitle;

  /// No description provided for @tokenSafetyBody.
  ///
  /// In en, this message translates to:
  /// **'Tokens are usually shown in full only once, so copy and save yours immediately. Do not put it in public notes, screenshots, or commits. If it may have leaked, delete the old token and generate a new one.'**
  String get tokenSafetyBody;

  /// No description provided for @tokenPasteTip.
  ///
  /// In en, this message translates to:
  /// **'After copying it, return to Settings, paste it into Access Token, save the configuration, and test the connection.'**
  String get tokenPasteTip;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get reminder;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get reminders;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add Assistant'**
  String get addReminder;

  /// No description provided for @editReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit Assistant'**
  String get editReminder;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reminderTitle;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderTime;

  /// No description provided for @reminderRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get reminderRepeat;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get reminderEnabled;

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reminderNone;

  /// No description provided for @reminderDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reminderDaily;

  /// No description provided for @reminderWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reminderWeekly;

  /// No description provided for @reminderMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get reminderMonthly;

  /// No description provided for @reminderWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get reminderWeekdays;

  /// No description provided for @reminderInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get reminderInterval;

  /// No description provided for @reminderIntervalEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {duration}'**
  String reminderIntervalEvery(String duration);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hr'**
  String durationHours(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String durationMinutes(int count);

  /// No description provided for @reminderIntervalHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get reminderIntervalHoursLabel;

  /// No description provided for @reminderIntervalMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get reminderIntervalMinutesLabel;

  /// No description provided for @reminderIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Starts timing when saved, then repeats at the chosen interval'**
  String get reminderIntervalHint;

  /// No description provided for @reminderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get reminderCustom;

  /// No description provided for @noRemindersYet.
  ///
  /// In en, this message translates to:
  /// **'No assistants yet'**
  String get noRemindersYet;

  /// No description provided for @createFirstReminder.
  ///
  /// In en, this message translates to:
  /// **'Tap + in the top-right corner to create your first assistant'**
  String get createFirstReminder;

  /// No description provided for @deleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete Assistant'**
  String get deleteReminder;

  /// No description provided for @confirmDeleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String confirmDeleteReminder(String title);

  /// No description provided for @reminderSaved.
  ///
  /// In en, this message translates to:
  /// **'Assistant saved'**
  String get reminderSaved;

  /// No description provided for @enterReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title...'**
  String get enterReminderTitle;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @windowSettings.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get windowSettings;

  /// No description provided for @closeButtonAction.
  ///
  /// In en, this message translates to:
  /// **'When closing the main window'**
  String get closeButtonAction;

  /// No description provided for @closeActionAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get closeActionAsk;

  /// No description provided for @closeActionMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize to system tray'**
  String get closeActionMinimize;

  /// No description provided for @closeActionExit.
  ///
  /// In en, this message translates to:
  /// **'Exit the app'**
  String get closeActionExit;

  /// No description provided for @closeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close casual'**
  String get closeDialogTitle;

  /// No description provided for @closeDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens when you click the close button:'**
  String get closeDialogMessage;

  /// No description provided for @closeDialogRemember.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t ask again (changeable in Settings)'**
  String get closeDialogRemember;

  /// No description provided for @trayShowWindow.
  ///
  /// In en, this message translates to:
  /// **'Show casual'**
  String get trayShowWindow;

  /// No description provided for @trayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get trayExit;

  /// No description provided for @openInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Open in new window'**
  String get openInNewWindow;

  /// No description provided for @noteDetachedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Opened in a separate window'**
  String get noteDetachedTooltip;

  /// No description provided for @noteDetachedBanner.
  ///
  /// In en, this message translates to:
  /// **'This note is being edited in a separate window and is read-only here'**
  String get noteDetachedBanner;

  /// No description provided for @focusNoteWindow.
  ///
  /// In en, this message translates to:
  /// **'Focus window'**
  String get focusNoteWindow;

  /// No description provided for @noteWindowWordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String noteWindowWordCount(int count);

  /// No description provided for @noteWindowPinToTop.
  ///
  /// In en, this message translates to:
  /// **'Keep on top'**
  String get noteWindowPinToTop;

  /// No description provided for @noteWindowUnpinFromTop.
  ///
  /// In en, this message translates to:
  /// **'Stop keeping on top'**
  String get noteWindowUnpinFromTop;

  /// No description provided for @noteWindowOpacity.
  ///
  /// In en, this message translates to:
  /// **'Window opacity'**
  String get noteWindowOpacity;

  /// No description provided for @noteWindowOpacityValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String noteWindowOpacityValue(int percent);

  /// No description provided for @noteWindowUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the main window; edits are not being saved'**
  String get noteWindowUnreachable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

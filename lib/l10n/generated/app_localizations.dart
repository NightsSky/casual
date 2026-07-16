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

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

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

  /// No description provided for @openMarkdownFile.
  ///
  /// In en, this message translates to:
  /// **'Open Markdown file'**
  String get openMarkdownFile;

  /// No description provided for @markdownEditOnly.
  ///
  /// In en, this message translates to:
  /// **'Edit only'**
  String get markdownEditOnly;

  /// No description provided for @markdownSplitView.
  ///
  /// In en, this message translates to:
  /// **'Split edit and preview'**
  String get markdownSplitView;

  /// No description provided for @markdownPreviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Preview only'**
  String get markdownPreviewOnly;

  /// No description provided for @showMarkdownToolbar.
  ///
  /// In en, this message translates to:
  /// **'Show formatting toolbar'**
  String get showMarkdownToolbar;

  /// No description provided for @hideMarkdownToolbar.
  ///
  /// In en, this message translates to:
  /// **'Hide formatting toolbar'**
  String get hideMarkdownToolbar;

  /// No description provided for @enterMarkdownFocus.
  ///
  /// In en, this message translates to:
  /// **'Full-screen edit/preview'**
  String get enterMarkdownFocus;

  /// No description provided for @exitMarkdownFocus.
  ///
  /// In en, this message translates to:
  /// **'Exit full-screen edit/preview'**
  String get exitMarkdownFocus;

  /// No description provided for @saveMarkdownFile.
  ///
  /// In en, this message translates to:
  /// **'Save (Ctrl+S)'**
  String get saveMarkdownFile;

  /// No description provided for @externalMarkdownReadOnly.
  ///
  /// In en, this message translates to:
  /// **'External Markdown files are opened read-only on this platform. Edit and save the original file on Windows desktop.'**
  String get externalMarkdownReadOnly;

  /// No description provided for @externalMarkdownContentHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown content'**
  String get externalMarkdownContentHint;

  /// No description provided for @externalMarkdownSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to the original Markdown file'**
  String get externalMarkdownSaved;

  /// No description provided for @externalMarkdownSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the Markdown file: {error}'**
  String externalMarkdownSaveFailed(String error);

  /// No description provided for @externalMarkdownOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Markdown file: {error}'**
  String externalMarkdownOpenFailed(String error);

  /// No description provided for @discardUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedChangesTitle;

  /// No description provided for @discardExternalMarkdownMessage.
  ///
  /// In en, this message translates to:
  /// **'This external Markdown file has not been saved to your computer.'**
  String get discardExternalMarkdownMessage;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get continueEditing;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @missingExternalMarkdown.
  ///
  /// In en, this message translates to:
  /// **'No Markdown file was selected'**
  String get missingExternalMarkdown;

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

  /// No description provided for @repositoryManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync notes and review sync stats and logs'**
  String get repositoryManagementDescription;

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

  /// No description provided for @syncConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get syncConflictTitle;

  /// No description provided for @syncConflictLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Local version'**
  String get syncConflictLocalTime;

  /// No description provided for @syncConflictRemoteTime.
  ///
  /// In en, this message translates to:
  /// **'Remote version'**
  String get syncConflictRemoteTime;

  /// No description provided for @syncConflictTimeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get syncConflictTimeUnknown;

  /// No description provided for @syncConflictDescription.
  ///
  /// In en, this message translates to:
  /// **'Both local and remote versions have been modified. Please choose which version to keep.'**
  String get syncConflictDescription;

  /// No description provided for @syncConflictKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get syncConflictKeepLocal;

  /// No description provided for @syncConflictTakeRemote.
  ///
  /// In en, this message translates to:
  /// **'Use Remote'**
  String get syncConflictTakeRemote;

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

  /// No description provided for @gitPlatformConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure GitHub or Gitee connection details'**
  String get gitPlatformConfigDescription;

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

  /// No description provided for @checkForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdate;

  /// No description provided for @checkingForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateAvailable;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version'**
  String get upToDate;

  /// No description provided for @updateNewVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String updateNewVersion(String version);

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotes;

  /// No description provided for @updateDownloadInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & install'**
  String get updateDownloadInstall;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get updateDownloading;

  /// No description provided for @updateInstallNow.
  ///
  /// In en, this message translates to:
  /// **'Install now'**
  String get updateInstallNow;

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get updateOpenReleasePage;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateWindowsZipHint.
  ///
  /// In en, this message translates to:
  /// **'After download, extract the archive and replace the existing app files.'**
  String get updateWindowsZipHint;

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
  /// **'After copying it, return to Git platform, paste it into Access Token, save the configuration, and test the connection.'**
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

  /// No description provided for @reminderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save assistant: {error}'**
  String reminderSaveFailed(String error);

  /// No description provided for @enterReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title...'**
  String get enterReminderTitle;

  /// No description provided for @reminderAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder due'**
  String get reminderAlarmTitle;

  /// No description provided for @reminderAlarmDefaultBody.
  ///
  /// In en, this message translates to:
  /// **'Time to handle this assistant'**
  String get reminderAlarmDefaultBody;

  /// No description provided for @reminderAlarmSource.
  ///
  /// In en, this message translates to:
  /// **'Local assistant reminder'**
  String get reminderAlarmSource;

  /// No description provided for @reminderAlarmLater.
  ///
  /// In en, this message translates to:
  /// **'Remind later'**
  String get reminderAlarmLater;

  /// No description provided for @reminderAlarmAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get reminderAlarmAcknowledge;

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

  /// No description provided for @noteWindowMove.
  ///
  /// In en, this message translates to:
  /// **'Move window'**
  String get noteWindowMove;

  /// No description provided for @noteWindowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize window'**
  String get noteWindowMinimize;

  /// No description provided for @noteWindowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize window'**
  String get noteWindowMaximize;

  /// No description provided for @noteWindowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore window'**
  String get noteWindowRestore;

  /// No description provided for @noteWindowClose.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get noteWindowClose;

  /// No description provided for @noteWindowUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the main window; edits are not being saved'**
  String get noteWindowUnreachable;

  /// No description provided for @openAsTagWindow.
  ///
  /// In en, this message translates to:
  /// **'Open as sticky tag'**
  String get openAsTagWindow;

  /// No description provided for @noteTagExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand note'**
  String get noteTagExpand;

  /// No description provided for @noteTagCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse to tag'**
  String get noteTagCollapse;

  /// No description provided for @planPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Break one goal into ordered steps and move it forward on a clear timeline.'**
  String get planPageSubtitle;

  /// No description provided for @createPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get createPlan;

  /// No description provided for @planFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planFilterActive;

  /// No description provided for @planFilterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get planFilterOverdue;

  /// No description provided for @planFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get planFilterCompleted;

  /// No description provided for @planFilterTerminated.
  ///
  /// In en, this message translates to:
  /// **'Terminated'**
  String get planFilterTerminated;

  /// No description provided for @planNoPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No plans yet'**
  String get planNoPlansYet;

  /// No description provided for @planCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a plan and start recording its progress.'**
  String get planCreateFirst;

  /// No description provided for @planSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a plan to view its timeline'**
  String get planSelectPrompt;

  /// No description provided for @planTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan title'**
  String get planTitleLabel;

  /// No description provided for @planTitleHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Release casual 1.0'**
  String get planTitleHint;

  /// No description provided for @planGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get planGoalLabel;

  /// No description provided for @planGoalHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the concrete result you want to achieve'**
  String get planGoalHint;

  /// No description provided for @planStartAt.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get planStartAt;

  /// No description provided for @planDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get planDeadline;

  /// No description provided for @planReminder.
  ///
  /// In en, this message translates to:
  /// **'Deadline reminder'**
  String get planReminder;

  /// No description provided for @planReminderOff.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get planReminderOff;

  /// No description provided for @planReminderAtDeadline.
  ///
  /// In en, this message translates to:
  /// **'At deadline'**
  String get planReminderAtDeadline;

  /// No description provided for @planReminderOneHourBefore.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get planReminderOneHourBefore;

  /// No description provided for @planReminderOneDayBefore.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get planReminderOneDayBefore;

  /// No description provided for @planReminderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get planReminderCustom;

  /// No description provided for @planReminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes before deadline'**
  String get planReminderMinutes;

  /// No description provided for @planReminderMinutesHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 525600'**
  String get planReminderMinutesHint;

  /// No description provided for @planEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planEdit;

  /// No description provided for @planOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get planOverview;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get planProgress;

  /// No description provided for @planTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get planTimeline;

  /// No description provided for @planUpdateProgress.
  ///
  /// In en, this message translates to:
  /// **'Update progress'**
  String get planUpdateProgress;

  /// No description provided for @planAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get planAddRecord;

  /// No description provided for @planComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete plan'**
  String get planComplete;

  /// No description provided for @planTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate plan'**
  String get planTerminate;

  /// No description provided for @planDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get planDelete;

  /// No description provided for @planRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Record a result, issue, or next step...'**
  String get planRecordHint;

  /// No description provided for @planProgressNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional note for this progress update...'**
  String get planProgressNoteHint;

  /// No description provided for @planOptionalNote.
  ///
  /// In en, this message translates to:
  /// **'Optional note'**
  String get planOptionalNote;

  /// No description provided for @planTerminationReason.
  ///
  /// In en, this message translates to:
  /// **'Termination reason (optional)'**
  String get planTerminationReason;

  /// No description provided for @planStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get planStatusNotStarted;

  /// No description provided for @planStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get planStatusInProgress;

  /// No description provided for @planStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get planStatusOverdue;

  /// No description provided for @planStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get planStatusCompleted;

  /// No description provided for @planStatusTerminated.
  ///
  /// In en, this message translates to:
  /// **'Terminated'**
  String get planStatusTerminated;

  /// No description provided for @planTimelineCreated.
  ///
  /// In en, this message translates to:
  /// **'Plan created'**
  String get planTimelineCreated;

  /// No description provided for @planTimelineDetailsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan details updated'**
  String get planTimelineDetailsUpdated;

  /// No description provided for @planTimelineProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress updated to {progress}%'**
  String planTimelineProgress(int progress);

  /// No description provided for @planTimelineRecord.
  ///
  /// In en, this message translates to:
  /// **'Execution record'**
  String get planTimelineRecord;

  /// No description provided for @planTimelineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Plan completed'**
  String get planTimelineCompleted;

  /// No description provided for @planTimelineTerminated.
  ///
  /// In en, this message translates to:
  /// **'Plan terminated'**
  String get planTimelineTerminated;

  /// No description provided for @planRemainingDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days remaining'**
  String planRemainingDays(int count);

  /// No description provided for @planRemainingHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours remaining'**
  String planRemainingHours(int count);

  /// No description provided for @planDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get planDueSoon;

  /// No description provided for @planOverdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days overdue'**
  String planOverdueDays(int count);

  /// No description provided for @planValidateTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a plan title'**
  String get planValidateTitle;

  /// No description provided for @planValidateGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter a concrete goal'**
  String get planValidateGoal;

  /// No description provided for @planValidateDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline must be later than the start time'**
  String get planValidateDeadline;

  /// No description provided for @planValidateReminder.
  ///
  /// In en, this message translates to:
  /// **'Enter valid reminder minutes'**
  String get planValidateReminder;

  /// No description provided for @planSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get planSaveSuccess;

  /// No description provided for @planDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Plan deleted'**
  String get planDeleteSuccess;

  /// No description provided for @planOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String planOperationFailed(String error);

  /// No description provided for @planConfirmComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark this plan as completed? Its progress will be set to 100%.'**
  String get planConfirmComplete;

  /// No description provided for @planConfirmTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate this plan? Its current progress and history will be kept.'**
  String get planConfirmTerminate;

  /// No description provided for @planConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This will also remove its timeline.'**
  String planConfirmDelete(String title);

  /// No description provided for @planRecordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an execution record'**
  String get planRecordRequired;

  /// No description provided for @planCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get planCreatedAt;

  /// No description provided for @planSteps.
  ///
  /// In en, this message translates to:
  /// **'Plan steps'**
  String get planSteps;

  /// No description provided for @planActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get planActivity;

  /// No description provided for @planAddStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get planAddStep;

  /// No description provided for @planRemoveStep.
  ///
  /// In en, this message translates to:
  /// **'Remove step'**
  String get planRemoveStep;

  /// No description provided for @planReorderStep.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get planReorderStep;

  /// No description provided for @planStepNumber.
  ///
  /// In en, this message translates to:
  /// **'Step {index}'**
  String planStepNumber(int index);

  /// No description provided for @planStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step title'**
  String get planStepTitle;

  /// No description provided for @planStepTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the result of this step'**
  String get planStepTitleHint;

  /// No description provided for @planStepTarget.
  ///
  /// In en, this message translates to:
  /// **'Expected completion time'**
  String get planStepTarget;

  /// No description provided for @planCompletedSteps.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} steps completed'**
  String planCompletedSteps(int completed, int total);

  /// No description provided for @planNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get planNextStep;

  /// No description provided for @planNoNextStep.
  ///
  /// In en, this message translates to:
  /// **'All steps completed'**
  String get planNoNextStep;

  /// No description provided for @planFinalDeadline.
  ///
  /// In en, this message translates to:
  /// **'Final deadline'**
  String get planFinalDeadline;

  /// No description provided for @planStepStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get planStepStatusPending;

  /// No description provided for @planStepStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get planStepStatusOverdue;

  /// No description provided for @planStepStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get planStepStatusCompleted;

  /// No description provided for @planCompleteStep.
  ///
  /// In en, this message translates to:
  /// **'Complete step'**
  String get planCompleteStep;

  /// No description provided for @planReopenStep.
  ///
  /// In en, this message translates to:
  /// **'Reopen step'**
  String get planReopenStep;

  /// No description provided for @planConfirmReopenStep.
  ///
  /// In en, this message translates to:
  /// **'Reopen this step? The plan progress and status will be recalculated.'**
  String get planConfirmReopenStep;

  /// No description provided for @planStepCompletionNote.
  ///
  /// In en, this message translates to:
  /// **'Completion note (optional)'**
  String get planStepCompletionNote;

  /// No description provided for @planStepCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed at {time}'**
  String planStepCompletedAt(String time);

  /// No description provided for @planValidateStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title for every step'**
  String get planValidateStepTitle;

  /// No description provided for @planValidateStepBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Step time cannot be earlier than the plan start time'**
  String get planValidateStepBeforeStart;

  /// No description provided for @planValidateStepOrder.
  ///
  /// In en, this message translates to:
  /// **'Each step time must be no earlier than the previous step'**
  String get planValidateStepOrder;

  /// No description provided for @planAtLeastOneStep.
  ///
  /// In en, this message translates to:
  /// **'A plan must contain at least one step'**
  String get planAtLeastOneStep;

  /// No description provided for @planTimelineStepsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan steps updated'**
  String get planTimelineStepsUpdated;

  /// No description provided for @planTimelineStepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed step: {step}'**
  String planTimelineStepCompleted(String step);

  /// No description provided for @planTimelineStepReopened.
  ///
  /// In en, this message translates to:
  /// **'Reopened step: {step}'**
  String planTimelineStepReopened(String step);

  /// No description provided for @planTimelineLegacyProgress.
  ///
  /// In en, this message translates to:
  /// **'Legacy progress {progress}% migrated to a plan step'**
  String planTimelineLegacyProgress(int progress);
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

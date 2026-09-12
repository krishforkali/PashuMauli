// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PashuMauli';

  @override
  String get appTagline => 'Livestock Health Surveillance';

  @override
  String get splashLoading => 'Loading…';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get marathi => 'मराठी';

  @override
  String get continueBtn => 'Continue';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get role => 'Role';

  @override
  String get loginBtn => 'Login';

  @override
  String get registerBtn => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Register';

  @override
  String get invalidPhone => 'Enter a valid 10-digit phone number';

  @override
  String get invalidPassword => 'Password must be at least 6 characters';

  @override
  String get invalidName => 'Name cannot be empty';

  @override
  String get home => 'Home';

  @override
  String get registerFarmer => 'Register Farmer';

  @override
  String get addAnimal => 'Add Animal';

  @override
  String get reportCase => 'Report Case';

  @override
  String get aiScan => 'AI Scan';

  @override
  String get offlineQueue => 'Offline Queue';

  @override
  String get notifications => 'Notifications';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get settings => 'Settings';

  @override
  String get online => 'ONLINE';

  @override
  String get offline => 'OFFLINE';

  @override
  String get farmerProfile => 'Farmer Profile';

  @override
  String get animalList => 'Animal List';

  @override
  String get addAnimalTitle => 'Add Animal';

  @override
  String get animalProfile => 'Animal Profile';

  @override
  String get vaccinationHistory => 'Vaccination History';

  @override
  String get reportSymptoms => 'Report Symptoms';

  @override
  String get aiDiseaseScan => 'AI Disease Scan';

  @override
  String get aiResult => 'AI Scan Result';

  @override
  String get advisory => 'Advisory';

  @override
  String get offlineQueueTitle => 'Offline Queue';

  @override
  String get syncStatusTitle => 'Sync Status';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get earTagId => 'Ear Tag ID';

  @override
  String get species => 'Species';

  @override
  String get breed => 'Breed';

  @override
  String get sex => 'Sex';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get location => 'Location';

  @override
  String get captureLocation => 'Capture GPS Location';

  @override
  String get locationNotAvailable => 'Location not available';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get noData => 'No data available';

  @override
  String get symptoms => 'Symptoms';

  @override
  String get notes => 'Notes';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get capturePhoto => 'Capture Photo';

  @override
  String get selectFromGallery => 'Select from Gallery';

  @override
  String pendingCount(int count) {
    return '$count pending';
  }

  @override
  String lastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get noSync => 'Never synced';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get confidence => 'Confidence';

  @override
  String get riskLevel => 'Risk Level';

  @override
  String get prediction => 'Prediction';

  @override
  String get lowConfidenceWarning =>
      'Low confidence — please consult a veterinarian for diagnosis';

  @override
  String get aiDisclaimer => 'AI screening only — not a confirmed diagnosis';

  @override
  String get escalateToVet => 'Escalate to Veterinarian';

  @override
  String get modelVersion => 'Model Version';

  @override
  String get language => 'Language';

  @override
  String get permissions => 'Permissions';

  @override
  String get account => 'Account';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get farmerName => 'Farmer Name';

  @override
  String get farmerPhone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get animals => 'Animals';

  @override
  String get cases => 'Cases';

  @override
  String get vaccinations => 'Vaccinations';

  @override
  String get pending => 'Pending';

  @override
  String get synced => 'Synced';

  @override
  String get failed => 'Failed';

  @override
  String get syncing => 'Syncing';

  @override
  String get demoMode => 'DEMO MODE';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get cameraPermission =>
      'Camera permission is required to capture animal photos';

  @override
  String get locationPermission =>
      'Location permission is required to capture GPS coordinates';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get skipPermission => 'Skip';

  @override
  String get photoAdded => 'Photo added';

  @override
  String get animalAddedLocally => 'Animal saved locally';

  @override
  String get farmerAddedLocally => 'Farmer saved locally';

  @override
  String get caseAddedLocally => 'Case saved locally (will sync when online)';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidEarTag => 'Ear tag ID cannot be empty';

  @override
  String get selectSpecies => 'Select species';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get cattle => 'Cattle';

  @override
  String get buffalo => 'Buffalo';

  @override
  String get goat => 'Goat';

  @override
  String get sheep => 'Sheep';

  @override
  String get pig => 'Pig';

  @override
  String get poultry => 'Poultry';

  @override
  String get other => 'Other';

  @override
  String get noAnimals => 'No animals registered yet';

  @override
  String get noFarmer => 'No farmer profile found';

  @override
  String get noCases => 'No health cases';

  @override
  String get noVaccinations => 'No vaccination records';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noQueueItems => 'Offline queue is empty';

  @override
  String get connectivityOnlineMsg => 'Connected to server';

  @override
  String get connectivityOfflineMsg =>
      'Working offline — data will sync when connected';

  @override
  String get tokenExpired => 'Session expired — please login again';

  @override
  String get loginFailed => 'Login failed — check credentials';

  @override
  String get networkError => 'Network error — check connection';

  @override
  String get serverError => 'Server error — try again later';

  @override
  String get farmer => 'Farmer';

  @override
  String get fieldVet => 'Field Veterinarian';

  @override
  String get districtOfficer => 'District Officer';

  @override
  String get stateAdmin => 'State Administrator';

  @override
  String get labUser => 'Lab User';

  @override
  String get systemAdmin => 'System Administrator';
}

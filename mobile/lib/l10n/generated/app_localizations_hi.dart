// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'पशुमौली';

  @override
  String get appTagline => 'पशु स्वास्थ्य निगरानी';

  @override
  String get splashLoading => 'लोड हो रहा है…';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get marathi => 'मराठी';

  @override
  String get continueBtn => 'जारी रखें';

  @override
  String get login => 'लॉगिन';

  @override
  String get register => 'पंजीकरण';

  @override
  String get phoneNumber => 'फोन नंबर';

  @override
  String get password => 'पासवर्ड';

  @override
  String get name => 'नाम';

  @override
  String get role => 'भूमिका';

  @override
  String get loginBtn => 'लॉगिन करें';

  @override
  String get registerBtn => 'पंजीकरण करें';

  @override
  String get alreadyHaveAccount => 'पहले से खाता है? लॉगिन करें';

  @override
  String get dontHaveAccount => 'खाता नहीं है? पंजीकरण करें';

  @override
  String get invalidPhone => 'वैध 10-अंकीय फोन नंबर दर्ज करें';

  @override
  String get invalidPassword => 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए';

  @override
  String get invalidName => 'नाम खाली नहीं हो सकता';

  @override
  String get home => 'होम';

  @override
  String get registerFarmer => 'किसान पंजीकृत करें';

  @override
  String get addAnimal => 'पशु जोड़ें';

  @override
  String get reportCase => 'केस रिपोर्ट करें';

  @override
  String get aiScan => 'AI स्कैन';

  @override
  String get offlineQueue => 'ऑफलाइन कतार';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get syncStatus => 'सिंक स्थिति';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get online => 'ऑनलाइन';

  @override
  String get offline => 'ऑफलाइन';

  @override
  String get farmerProfile => 'किसान प्रोफ़ाइल';

  @override
  String get animalList => 'पशु सूची';

  @override
  String get addAnimalTitle => 'पशु जोड़ें';

  @override
  String get animalProfile => 'पशु प्रोफ़ाइल';

  @override
  String get vaccinationHistory => 'टीकाकरण इतिहास';

  @override
  String get reportSymptoms => 'लक्षण रिपोर्ट करें';

  @override
  String get aiDiseaseScan => 'AI रोग स्कैन';

  @override
  String get aiResult => 'AI स्कैन परिणाम';

  @override
  String get advisory => 'सलाह';

  @override
  String get offlineQueueTitle => 'ऑफलाइन कतार';

  @override
  String get syncStatusTitle => 'सिंक स्थिति';

  @override
  String get notificationsTitle => 'सूचनाएं';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get earTagId => 'कान टैग ID';

  @override
  String get species => 'प्रजाति';

  @override
  String get breed => 'नस्ल';

  @override
  String get sex => 'लिंग';

  @override
  String get dateOfBirth => 'जन्म तिथि';

  @override
  String get location => 'स्थान';

  @override
  String get captureLocation => 'GPS स्थान कैप्चर करें';

  @override
  String get locationNotAvailable => 'स्थान उपलब्ध नहीं';

  @override
  String get locationPermissionDenied => 'स्थान अनुमति अस्वीकृत';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get error => 'त्रुटि';

  @override
  String get success => 'सफल';

  @override
  String get noData => 'कोई डेटा उपलब्ध नहीं';

  @override
  String get symptoms => 'लक्षण';

  @override
  String get notes => 'नोट्स';

  @override
  String get submitReport => 'रिपोर्ट सबमिट करें';

  @override
  String get capturePhoto => 'फोटो कैप्चर करें';

  @override
  String get selectFromGallery => 'गैलरी से चुनें';

  @override
  String pendingCount(int count) {
    return '$count लंबित';
  }

  @override
  String lastSync(String time) {
    return 'अंतिम सिंक: $time';
  }

  @override
  String get noSync => 'कभी सिंक नहीं हुआ';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get confidence => 'विश्वास';

  @override
  String get riskLevel => 'जोखिम स्तर';

  @override
  String get prediction => 'पूर्वानुमान';

  @override
  String get lowConfidenceWarning =>
      'कम विश्वास — निदान के लिए पशुचिकित्सक से परामर्श करें';

  @override
  String get aiDisclaimer => 'केवल AI स्क्रीनिंग — पुष्टि निदान नहीं';

  @override
  String get escalateToVet => 'पशुचिकित्सक को भेजें';

  @override
  String get modelVersion => 'मॉडल संस्करण';

  @override
  String get language => 'भाषा';

  @override
  String get permissions => 'अनुमतियां';

  @override
  String get account => 'खाता';

  @override
  String get diagnostics => 'डायग्नोस्टिक्स';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get logoutConfirm => 'क्या आप लॉगआउट करना चाहते हैं?';

  @override
  String get yes => 'हाँ';

  @override
  String get no => 'नहीं';

  @override
  String get farmerName => 'किसान का नाम';

  @override
  String get farmerPhone => 'फोन';

  @override
  String get address => 'पता';

  @override
  String get animals => 'पशु';

  @override
  String get cases => 'केस';

  @override
  String get vaccinations => 'टीकाकरण';

  @override
  String get pending => 'लंबित';

  @override
  String get synced => 'सिंक्ड';

  @override
  String get failed => 'विफल';

  @override
  String get syncing => 'सिंक हो रहा है';

  @override
  String get demoMode => 'डेमो मोड';

  @override
  String get permissionRequired => 'अनुमति आवश्यक';

  @override
  String get cameraPermission =>
      'पशु की फोटो कैप्चर करने के लिए कैमरा अनुमति आवश्यक है';

  @override
  String get locationPermission =>
      'GPS निर्देशांक कैप्चर करने के लिए स्थान अनुमति आवश्यक है';

  @override
  String get grantPermission => 'अनुमति दें';

  @override
  String get skipPermission => 'छोड़ें';

  @override
  String get photoAdded => 'फोटो जोड़ी गई';

  @override
  String get animalAddedLocally => 'पशु स्थानीय रूप से सहेजा गया';

  @override
  String get farmerAddedLocally => 'किसान स्थानीय रूप से सहेजा गया';

  @override
  String get caseAddedLocally =>
      'केस स्थानीय रूप से सहेजा गया (ऑनलाइन होने पर सिंक होगा)';

  @override
  String get requiredField => 'यह फ़ील्ड आवश्यक है';

  @override
  String get invalidEarTag => 'कान टैग ID खाली नहीं हो सकता';

  @override
  String get selectSpecies => 'प्रजाति चुनें';

  @override
  String get male => 'नर';

  @override
  String get female => 'मादा';

  @override
  String get cattle => 'मवेशी';

  @override
  String get buffalo => 'भैंस';

  @override
  String get goat => 'बकरी';

  @override
  String get sheep => 'भेड़';

  @override
  String get pig => 'सुअर';

  @override
  String get poultry => 'मुर्गी';

  @override
  String get other => 'अन्य';

  @override
  String get noAnimals => 'अभी तक कोई पशु पंजीकृत नहीं';

  @override
  String get noFarmer => 'किसान प्रोफ़ाइल नहीं मिली';

  @override
  String get noCases => 'कोई स्वास्थ्य केस नहीं';

  @override
  String get noVaccinations => 'कोई टीकाकरण रिकॉर्ड नहीं';

  @override
  String get noNotifications => 'कोई सूचना नहीं';

  @override
  String get noQueueItems => 'ऑफलाइन कतार खाली है';

  @override
  String get connectivityOnlineMsg => 'सर्वर से जुड़ा';

  @override
  String get connectivityOfflineMsg =>
      'ऑफलाइन काम कर रहा है — जुड़ने पर डेटा सिंक होगा';

  @override
  String get tokenExpired => 'सत्र समाप्त — कृपया फिर से लॉगिन करें';

  @override
  String get loginFailed => 'लॉगिन विफल — क्रेडेंशियल जांचें';

  @override
  String get networkError => 'नेटवर्क त्रुटि — कनेक्शन जांचें';

  @override
  String get serverError => 'सर्वर त्रुटि — बाद में पुनः प्रयास करें';

  @override
  String get farmer => 'किसान';

  @override
  String get fieldVet => 'क्षेत्र पशुचिकित्सक';

  @override
  String get districtOfficer => 'जिला अधिकारी';

  @override
  String get stateAdmin => 'राज्य प्रशासक';

  @override
  String get labUser => 'प्रयोगशाला उपयोगकर्ता';

  @override
  String get systemAdmin => 'सिस्टम प्रशासक';
}

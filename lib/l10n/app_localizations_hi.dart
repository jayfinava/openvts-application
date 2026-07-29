// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'OpenVTS';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get localization => 'स्थानीयकरण';

  @override
  String get language => 'भाषा';

  @override
  String get theme => 'थीम';

  @override
  String get dateFormat => 'तारीख प्रारूप';

  @override
  String get timeFormat => 'समय प्रारूप';

  @override
  String get timezone => 'समय क्षेत्र';

  @override
  String get use24Hour => '24-घंटे का समय';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get edit => 'संपादित करें';

  @override
  String get search => 'खोज';

  @override
  String get delete => 'हटाएं';

  @override
  String get reset => 'रीसेट करें';

  @override
  String get close => 'बंद करें';

  @override
  String get back => 'पीछे';

  @override
  String get next => 'अगला';

  @override
  String get prev => 'पिछला';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get error => 'त्रुटि';

  @override
  String get success => 'सफल';

  @override
  String get warning => 'चेतावनी';

  @override
  String get light => 'हल्का';

  @override
  String get dark => 'गहरा';

  @override
  String get system => 'सिस्टम';

  @override
  String get en => 'अंग्रेजी';

  @override
  String get hi => 'हिंदी';

  @override
  String get ar => 'अरबी';

  @override
  String get es => 'स्पेनिश';

  @override
  String get fr => 'फ्रेंच';

  @override
  String get pt => 'पुर्तगाली';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get login => 'लॉगिन';

  @override
  String get register => 'पंजीकरण';

  @override
  String get administrators => 'प्रशासक';

  @override
  String get payments => 'भुगतान';

  @override
  String get support => 'समर्थन';

  @override
  String get tickets => 'टिकट';

  @override
  String get home => 'होम';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get keepEditing => 'संपादन जारी रखें';

  @override
  String get discardChanges => 'परिवर्तन हटाएं';

  @override
  String get unsavedChanges => 'बिना सहेजे गए परिवर्तन';

  @override
  String get refresh => 'ताज़ा करें';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get selectTheme => 'थीम चुनें';

  @override
  String get selectDateFormat => 'तारीख प्रारूप चुनें';

  @override
  String get selectTimeFormat => 'समय प्रारूप चुनें';

  @override
  String get selectTimezone => 'समय क्षेत्र चुनें';

  @override
  String previewDate(String date) {
    return 'पूर्वावलोकन: $date';
  }

  @override
  String previewTime(String time) {
    return 'पूर्वावलोकन: $time';
  }

  @override
  String get settingsUpdated => 'सेटिंग्स अपडेट की गई';

  @override
  String get profileUpdated => 'प्रोफाइल अपडेट की गई';

  @override
  String get localizationUpdated => 'स्थानीयकरण सेटिंग्स अपडेट की गई';

  @override
  String get failedToUpdate => 'अपडेट करने में विफल। कृपया दोबारा प्रयास करें।';

  @override
  String get noData => 'कोई डेटा उपलब्ध नहीं है';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get confirmDiscard => 'बिना सहेजे गए परिवर्तन हटाएं?';

  @override
  String confirmDiscardMessage(String tab) {
    return '$tab के अनसेव किए गए संपादन हैं। हटाने से ये परिवर्तन खो जाएंगे।';
  }

  @override
  String get reportsTitle => 'रिपोर्ट';

  @override
  String get reportsSearchHint => 'रिपोर्ट खोजें…';

  @override
  String reportsNoResultsFor(Object query) {
    return '\"$query\" के लिए कोई रिपोर्ट नहीं मिली';
  }

  @override
  String get reportsGenerate => 'रिपोर्ट बनाएं';

  @override
  String get reportsGenerating => 'बना रहा है…';

  @override
  String get reportsReset => 'रीसेट';

  @override
  String get reportsConfigureHint =>
      'उपर रिपोर्ट कॉन्फ़िगर करें और जनरेट दबाएं।';

  @override
  String get reportsNoResults => 'चुने गए फ़िल्टर के लिए कोई परिणाम नहीं मिला।';

  @override
  String get reportsErrorRetry => 'पुनः प्रयास';

  @override
  String reportsRowCount(Object count) {
    return '$count पंक्ति लोड की गई';
  }

  @override
  String get reportsLoadMore => 'और लोड करें';

  @override
  String get reportsLoadingMore => 'Loading more…';

  @override
  String reportsGeneratedAt(Object time) {
    return '$time को बनाया गया';
  }

  @override
  String get reportsExportTitle => 'रिपोर्ट एक्सपोर्ट';

  @override
  String get reportsExportCsv => 'CSV';

  @override
  String get reportsExportXlsx => 'Excel (XLSX)';

  @override
  String get reportsExportJson => 'JSON';

  @override
  String get reportsExportPdf => 'PDF';

  @override
  String get reportsExportHtml => 'HTML';

  @override
  String get reportsScopeAll => 'सभी वाहन';

  @override
  String get reportsScopeSingle => 'एकल वाहन';

  @override
  String get reportsScopeMultiple => 'कई वाहन';

  @override
  String get reportsScopeGroup => 'समूह';

  @override
  String get reportsScopeSelectVehicle => 'Select vehicle';

  @override
  String get reportsScopeSelectVehicles => 'Select vehicles';

  @override
  String get reportsScopeSelectGroup => 'Select group';

  @override
  String get reportsScopeSearchHint => 'Search by name, plate or IMEI…';

  @override
  String get reportsScopeSelectAll => 'Select all visible';

  @override
  String get reportsScopeDone => 'Done';

  @override
  String reportsScopeNVehiclesSelected(Object count) {
    return '$count vehicles selected';
  }

  @override
  String get reportsDateStart => 'Start date';

  @override
  String get reportsDateEnd => 'End date';

  @override
  String get reportsDateFrom => 'Start';

  @override
  String get reportsDateTo => 'End';

  @override
  String reportsDateMaxDays(Object days) {
    return 'Max $days days for this report type';
  }

  @override
  String get reportsValidationScopeRequired =>
      'Please select at least one vehicle.';

  @override
  String get reportsValidationStartRequired => 'Start date is required.';

  @override
  String get reportsValidationEndRequired => 'End date is required.';

  @override
  String get reportsValidationStartBeforeEnd => 'Start must be before end.';

  @override
  String reportsValidationMaxDays(Object days) {
    return 'Date range exceeds the $days-day limit for this report.';
  }

  @override
  String get reportsValidationSensorVehicleRequired =>
      'Please select a vehicle for the sensor report.';

  @override
  String get reportsValidationSensorRequired => 'Please select a sensor.';

  @override
  String get reportsValidationTimelineStateRequired =>
      'Select at least one state (Running or Stopped).';

  @override
  String get reportsFilterSpeedLimit => 'Speed limit (km/h)';

  @override
  String get reportsFilterSpeedCustom => 'Custom limit…';

  @override
  String get reportsFilterGeofenceHint => 'Search geofences…';

  @override
  String get reportsFilterGeofenceAllNote =>
      'No selection includes all geofences.';

  @override
  String get reportsFilterAlertType => 'Alert type';

  @override
  String get reportsFilterAlertSeverity => 'Severity';

  @override
  String get reportsFilterAlertAck => 'Acknowledgement';

  @override
  String get reportsFilterAlertAckAll => 'All';

  @override
  String get reportsFilterAlertAckAcknowledged => 'Acknowledged';

  @override
  String get reportsFilterAlertAckUnacknowledged => 'Unacknowledged';

  @override
  String get reportsFilterLogsVehicle => 'Vehicle';

  @override
  String get reportsFilterLogsCategory => 'Category';

  @override
  String get reportsFilterLogsLevel => 'Level';

  @override
  String get reportsFilterTimelineRunning => 'Running';

  @override
  String get reportsFilterTimelineStopped => 'Stopped';

  @override
  String get reportsFilterSensorVehicle => 'Vehicle';

  @override
  String get reportsFilterSensorSensor => 'Sensor';

  @override
  String get reportsCatalogDistanceTitle => 'दूरी';

  @override
  String get reportsCatalogDistanceDesc =>
      'Total distance driven per vehicle per day with engine hours and odometer readings.';

  @override
  String get reportsCatalogDrivenTitle => 'चलाए गए दिन';

  @override
  String get reportsCatalogDrivenDesc =>
      'Daily distance matrix — which vehicles moved on which days and how far.';

  @override
  String get reportsCatalogDetailsTitle => 'वाहन विवरण';

  @override
  String get reportsCatalogDetailsDesc =>
      'Fleet summary: total distance, engine hours, active days, last known location per vehicle.';

  @override
  String get reportsCatalogOverspeedTitle => 'ओवरस्पीड';

  @override
  String get reportsCatalogOverspeedDesc =>
      'Speeding events with observed speed, configured limit, excess, duration, and location.';

  @override
  String get reportsCatalogGeofenceTitle => 'जियोफेंस';

  @override
  String get reportsCatalogGeofenceDesc =>
      'Entry and exit events for selected geofences with timestamps and dwell duration.';

  @override
  String get reportsCatalogAlertsTitle => 'अलर्ट';

  @override
  String get reportsCatalogAlertsDesc =>
      'Alert events by type and severity with acknowledgement status.';

  @override
  String get reportsCatalogSensorTitle => 'सेंसर';

  @override
  String get reportsCatalogSensorDesc =>
      'Time-series readings for a specific sensor on a single vehicle with chart visualisation.';

  @override
  String get reportsCatalogLogsTitle => 'डिवाइस लॉग';

  @override
  String get reportsCatalogLogsDesc =>
      'Raw communication logs from vehicle devices grouped by category and level.';

  @override
  String get reportsCatalogTimelineTitle => 'समयरेखा';

  @override
  String get reportsCatalogTimelineDesc =>
      'Running and stopped segments with duration, distance, and GPS map trace per segment.';

  @override
  String get reportsKpiTotalDistance => 'Total Distance';

  @override
  String get reportsKpiEngineHours => 'Engine Hours';

  @override
  String get reportsKpiActiveVehicles => 'Active Vehicles';

  @override
  String get reportsKpiAvgDistance => 'Avg Distance';

  @override
  String get reportsKpiVehiclesDriven => 'Vehicles Driven';

  @override
  String get reportsKpiAvgDaily => 'Avg Daily';

  @override
  String get reportsKpiPeakDay => 'Peak Day';

  @override
  String get reportsKpiViolations => 'Violations';

  @override
  String get reportsKpiAffectedVehicles => 'Affected Vehicles';

  @override
  String get reportsKpiHighestSpeed => 'Highest Speed';

  @override
  String get reportsKpiTotalDuration => 'Total Duration';

  @override
  String get reportsKpiTotalEvents => 'Total Events';

  @override
  String get reportsKpiEntries => 'Entries';

  @override
  String get reportsKpiExits => 'Exits';

  @override
  String get reportsKpiTotalAlerts => 'Total Alerts';

  @override
  String get reportsKpiCritical => 'Critical';

  @override
  String get reportsKpiAcknowledged => 'Acknowledged';

  @override
  String get reportsKpiReadings => 'Readings';

  @override
  String get reportsKpiOnEvents => 'ON Events';

  @override
  String get reportsKpiOffEvents => 'OFF Events';

  @override
  String get reportsKpiTotalLogs => 'Total Logs';

  @override
  String get reportsKpiRunningDuration => 'Running Duration';

  @override
  String get reportsKpiStoppedDuration => 'Stopped Duration';

  @override
  String get reportsKpiMovementDistance => 'Movement Distance';

  @override
  String get reportsKpiStopCount => 'Stop Count';

  @override
  String get reportsDetailTitle => 'Row Details';

  @override
  String get reportsDetailRawPayload => 'Raw Payload';

  @override
  String get reportsDetailCopied => 'Copied';

  @override
  String get reportsDetailCopy => 'Copy';

  @override
  String get reportsDetailTruncated =>
      'Payload truncated for display. Export for full data.';

  @override
  String get reportsRowDetailsViewMap => 'View Map';

  @override
  String get reportsRowDetailsHideMap => 'Hide Map';

  @override
  String get reportsRowDetailsNoGps =>
      'No GPS data available for this segment.';

  @override
  String reportsWarningBanner(Object message) {
    return 'Warning: $message';
  }

  @override
  String reportsSourceLabel(Object source) {
    return 'Source: $source';
  }
}

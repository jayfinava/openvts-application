// Run explicitly with:
// flutter test --platform chrome test/report_browser_contract.dart
// A root-level entry avoids Flutter's Windows browser harness embedding an
// unescaped backslash-u from features/user in its JavaScript test selector.
import 'features/user/reports/user_report_api_contract_test.dart' as contracts;

void main() => contracts.main();

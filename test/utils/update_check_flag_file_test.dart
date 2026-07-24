import 'package:doudou/utils/update_check_flag_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updateCheckFlag is true by default', () {
    expect(updateCheckFlag, isTrue);
  });
}

import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('reserves measured navigation height only when requested', (
    tester,
  ) async {
    const bodyKey = ValueKey('body');
    Widget layout(bool reserve, {double navHeight = 80}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: MainLayout(
            reserveBottomNavSpace: reserve,
            sideBar: null,
            bottomNav: SizedBox(height: navHeight, width: 400),
            body: const SizedBox(key: bodyKey),
          ),
        ),
      ),
    );
    await tester.pumpWidget(layout(false));
    expect(tester.getSize(find.byKey(bodyKey)).height, 600);
    await tester.pumpWidget(layout(true));
    expect(tester.getSize(find.byKey(bodyKey)).height, 520);
    await tester.pumpWidget(layout(true, navHeight: 100));
    expect(tester.getSize(find.byKey(bodyKey)).height, 500);
    await tester.pumpWidget(layout(false));
    expect(tester.getSize(find.byKey(bodyKey)).height, 600);
  });
}

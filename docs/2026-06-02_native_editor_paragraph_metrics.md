# 2026-06-02 native editor paragraph metrics

## 작업한 내용

- rhwp Rust bridge에 본문 section count, paragraph count, paragraph length command를 추가했다.
- Dart `RhwpCommand`와 `RhwpDocument` convenience API에서 같은 metric command를 호출할 수 있게 했다.
- Flutter-native editor의 Backspace/Delete 문단 병합 로직이 보이는 text layer만 보지 않고, 필요할 때 Rust core의 본문 문단 metric을 fallback으로 쓰도록 했다.
- 빈 문단처럼 SVG text run에 나타나지 않는 문단도 키보드 경계 병합 테스트로 검증했다.

## 이 작업을 진행한 이유

페이지 SVG layer tree는 렌더링에 최적화된 정보라서, 빈 문단이나 화면에 직접 보이지 않는 구조적 문단을 항상 표현하지 않는다. 기존 병합 로직이 visible text run만 기준으로 판단하면 빈 문단 앞뒤에서 Backspace/Delete가 no-op처럼 보일 수 있다.

문단 존재 여부와 길이는 문서 구조의 책임이므로 rhwp core에서 직접 가져오는 편이 맞다. Flutter-native editor는 화면 좌표와 overlay를 담당하고, 문단 경계 판단은 core metric으로 보강해야 실제 에디터 동작에 가까워진다.

## 이 작업을 통해 배울점

- 렌더링 layer tree는 편집 모델의 단일 진실 공급원으로 쓰기 어렵다.
- 빈 문단, 숨은 control, 페이지 경계처럼 화면 정보가 부족한 케이스는 core document metric이 필요하다.
- Flutter-native editor를 100% 포팅하려면 UI command뿐 아니라 문서 구조 조회 API도 단계적으로 노출해야 한다.
- 테스트 fake session은 화면 layer와 core metric을 분리해서, 둘이 다를 때의 편집 동작을 재현해야 한다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor merges empty paragraphs using core metrics"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor merges paragraphs at keyboard boundaries"`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter analyze`
- `git diff --check`

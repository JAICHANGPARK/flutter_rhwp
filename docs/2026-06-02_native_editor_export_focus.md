# 2026-06-02 native editor export focus

## 작업한 내용

Flutter-native editor의 save/export 흐름이 끝난 뒤 editor focus를 복원하도록 변경했다.
파일 리본에서 Save HWP, Save HWPX, Export PDF를 누른 뒤 페이지를 다시 클릭하지 않아도
Ctrl/Cmd+S, Ctrl/Cmd+Shift+S, Ctrl/Cmd+P 단축키가 바로 이어진다.

기존 export API와 `onExported` callback 경계는 그대로 유지했다. 변경한 부분은 export callback이
끝난 뒤 toolbar/button focus에 머물지 않고 editor surface로 돌아오게 만든 것이다.

## 이 작업을 진행한 이유

upstream web editor는 파일 작업 버튼과 단축키가 같은 editor surface 안에서 이어진다. Flutter
위젯 기반 editor도 사용자가 save/export 버튼을 누른 뒤 다시 문서 페이지를 클릭해야 다음 단축키가
먹는다면 실제 편집기 UX가 끊긴다.

Open 버튼 focus는 이미 보강했지만 save/export는 여전히 테스트에서 page caret를 다시 클릭하는
우회가 남아 있었다. 이번 작업은 그 우회를 제거하고 파일 작업 후 keyboard flow를 유지한다.

## 이 작업을 통해 배울점

파일 export는 Rust core 명령과 앱 callback이 섞이는 경계다. 문서는 Rust에서 bytes로 export하고,
앱은 `onExported`에서 다운로드나 저장 UI를 처리한다. 이 경계가 끝난 뒤 editor focus를 복원해야
Flutter-native editor가 toolbar 중심 UI가 아니라 문서 편집 surface로 계속 동작한다.

또한 테스트는 단순히 export bytes만 확인하면 부족하다. 버튼을 누른 뒤 바로 shortcut을 보내서
후속 editor input이 연결되는지도 함께 검증해야 실제 UX 회귀를 잡을 수 있다.

## 검증

다음 widget test를 갱신해 file-ribbon export 버튼 이후 page를 다시 클릭하지 않아도 Ctrl/Cmd 기반
save/export shortcut이 이어지는지 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon exports save artifacts"
```

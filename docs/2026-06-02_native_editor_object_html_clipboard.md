# 2026-06-02 Native Editor Object HTML Clipboard

## 작업한 내용

- Flutter-native editor에서 선택된 개체를 복사할 때 기존 `copyObjectControl` 호출을 유지하면서 `exportControlHtml`도 함께 호출하도록 했다.
- 복사한 개체의 HTML fragment에서 plain text를 추출해 Flutter clipboard에 저장하고, 내부 rich clipboard에도 HTML/text 쌍을 보관하도록 했다.
- Rust 쪽 object clipboard가 비어 있거나 사용할 수 없는 경우 같은 HTML fragment를 `pasteHtml` 경로로 붙여넣는 fallback을 추가했다.
- 선택 개체 복사/붙여넣기 테스트를 갱신하고, object clipboard 실패 시 HTML fallback paste가 동작하는 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 기반 full editor를 대체하려면 단순 텍스트 입력뿐 아니라 개체가 포함된 문서 편집 흐름도 자체적으로 처리해야 한다.

기존 개체 복사는 Rust 내부 object clipboard만 사용했다. 이 방식은 같은 rhwp 세션에서 개체를 다시 붙여넣을 때는 좋지만, 플랫폼이나 실행 환경에 따라 object clipboard가 비어 있으면 붙여넣기 경로가 바로 끊긴다. 이미 rhwp core에 `exportControlHtml`과 `pasteHtml` 명령이 있으므로, 개체 복사 시 HTML 표현을 함께 보관하면 Flutter-native editor 안에서 더 안정적인 fallback을 제공할 수 있다.

## 이 작업을 통해 배울점

- Flutter clipboard는 기본적으로 plain text만 다루기 때문에 HTML clipboard를 그대로 OS clipboard에 실을 수 없다.
- 같은 editor 인스턴스 안에서는 plain text와 HTML fragment를 내부 상태로 함께 보관해 rich paste를 재현할 수 있다.
- object clipboard와 HTML clipboard는 우선순위가 다르다. object clipboard가 살아 있으면 원본 개체 paste를 먼저 시도하고, 실패할 때만 HTML import fallback으로 내려가는 구조가 안전하다.

## 검증

- `RhwpNativeEditor copies and pastes selected object controls` 테스트에서 `copyObjectControl` 뒤에 `exportControlHtml`이 호출되고, plain clipboard text가 저장되는지 확인한다.
- `RhwpNativeEditor falls back to object HTML clipboard paste` 테스트에서 object clipboard가 비어 있을 때 `pasteHtml` 경로로 붙여넣는지 확인한다.

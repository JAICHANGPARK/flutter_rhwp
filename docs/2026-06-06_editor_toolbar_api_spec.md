# Editor toolbar API spec

## 작업한 내용

- `README.md`에 API spec, native editor parity, roadmap/TODO 문서 링크를 추가했다.
- `docs/API_SPEC.md`에 외부 툴바 구현 계약을 추가했다.
- `RhwpEditorController`에서 읽어야 하는 cursor, selection, table-cell selection, object selection, dirty state를 기능별로 정리했다.
- 외부 툴바가 `RhwpDocument` command API를 호출할 때 따라야 하는 순서를 정리했다.
- body text insert와 table-cell fill 예시 코드를 추가했다.
- `CHANGELOG.md`와 `docs/TODO.md`에 이번 문서화 작업을 반영했다.

## 이 작업을 진행한 이유

`RhwpNativeEditor`의 내장 리본은 내부에서 context를 계산하지만, 패키지 사용자가 앱 전용 툴바나 메뉴를 만들면 어떤 controller 상태를 읽고 어떤 document API를 호출해야 하는지 명확해야 한다.

에디터를 100% Flutter로 포팅하는 방향이라면 문서도 단순 사용법을 넘어서 toolbar command 명세 역할을 해야 한다. 그래야 앱 개발자가 Web editor UI에 의존하지 않고도 같은 기능을 자기 UI에 붙일 수 있다.

## 이 작업을 통해 배울점

- editor widget API와 document command API는 역할이 다르다. widget은 context와 UX를 관리하고, document API는 Rust bridge 명령을 실행한다.
- 파일 선택, 저장 위치, 다운로드, 프린트, 이미지 선택은 플러그인 내부가 아니라 host app이 처리해야 하는 플랫폼 UX다.
- custom toolbar는 `RhwpEditorController`와 같은 controller 인스턴스를 공유해야 cursor, selection, dirty 상태가 내장 리본과 같은 기준으로 유지된다.
- HWP/HWPX primary save와 PDF/DOCX/Text/SVG export는 dirty 처리 의미가 다르므로 API spec에서 명확히 구분해야 한다.

## 검증

```sh
flutter_rust_bridge_codegen --version
```

결과는 `flutter_rust_bridge_codegen 2.12.0`이다.

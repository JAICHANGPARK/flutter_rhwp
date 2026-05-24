# 2026-05-25 Third Party Notices

## 작업한 내용

- 루트 `THIRD_PARTY_NOTICES.md`를 추가했다.
- vendored `rhwp` v0.7.12의 upstream repository, MIT license, vendored source 위치, upstream third-party license 문서 위치를 명시했다.
- Cargokit, direct Dart dependencies, direct Rust dependencies, Web editor ESM module, FRB generated files의 notice 범위를 정리했다.
- README에 License 섹션을 추가하고 root third-party notices 문서로 연결했다.
- CHANGELOG에 notice 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 초기 가정에서 upstream `rhwp`의 MIT license와 third-party notices를 패키지에 포함해야 한다고 정리했다.
- `rust/vendor/rhwp/LICENSE`와 `rust/vendor/rhwp/THIRD_PARTY_LICENSES.md`는 이미 존재하지만, pub package 사용자가 루트에서 바로 확인할 수 있는 통합 안내가 없었다.
- Flutter plugin은 Dart, Rust, generated bridge, platform build helper가 함께 배포되므로 notice 위치를 한 문서에 묶어야 배포와 검토가 쉬워진다.

## 이 작업을 통해 배울점

- vendoring은 재현 가능한 빌드에는 유리하지만, license 추적 책임도 함께 생긴다.
- upstream notice 파일을 그대로 유지하면서 루트 notice 문서에서 위치와 역할을 연결하면 중복 복사보다 유지보수가 쉽다.
- 동적으로 로드하는 Web editor module은 패키지에 vendoring된 코드가 아니므로, self-host/bundle하는 앱이 별도 npm dependency notice를 포함해야 한다는 점을 분리해서 문서화해야 한다.

## 검증

- `flutter analyze`
- `git diff --check`

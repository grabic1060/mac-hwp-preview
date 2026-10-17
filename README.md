# HWP Preview

macOS Finder의 Quick Look에서 HWP 5.x와 HWPX를 페이지 형태로 표시하는 **개발용 alpha**입니다. 두 형식의 본문·표·이미지를 같은 경로로 렌더링하며, 페이지 이동·확대·너비 맞춤과 첫 페이지 썸네일을 제공합니다.

현재 공식 한글 기준 출력과의 정밀 비교는 미완료입니다. 정식 배포 준비가 끝난 제품으로 간주하지 마세요. 단계별 근거와 미충족 조건은 [구현 상태](docs/IMPLEMENTATION_STATUS.md), [원래 계획](IMPLEMENTATION_PLAN.md)에 기록합니다.

## 로컬 빌드

필요 환경: macOS, Xcode의 Swift SDK, Python 3, curl. 실제 검증 환경은 macOS 26 / Apple Silicon입니다. macOS 14를 최소 빌드 대상으로 지정했지만 해당 OS 및 Intel 실기 검증은 아직 하지 않았습니다.

```sh
bash scripts/fetch-wasm.sh
python3 scripts/build-app.py
bash scripts/register-app.sh
open '.build/app/HWP Preview.app'
```

Finder에서 `.hwp` 또는 `.hwpx` 파일을 선택하고 스페이스바를 누릅니다. 확장 선택이 필요한 경우 시스템 설정의 Quick Look 확장 항목을 확인하세요. 등록 스크립트는 현재 개발 빌드를 등록하고 이 프로젝트의 확장을 활성화합니다. 다른 앱의 기본 연결을 변경하지 않습니다.

앱을 다른 경로로 이동했다면 `bash scripts/register-app.sh '/새 경로/HWP Preview.app'`으로 다시 등록할 수 있습니다. 제거할 때는 앱을 휴지통으로 이동하고 해당 확장을 비활성화합니다. 시스템의 Quick Look 캐시가 즉시 사라지는 것은 보장하지 않습니다.

## 검사

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift test --disable-sandbox --cache-path .build/cache --scratch-path .build/swift
python3 scripts/test_wasm_limits.py
bash scripts/fetch-fixtures.sh
python3 scripts/verify-local.py --system
python3 scripts/test-preview-controller.py
```

GUI 세션에서 실행해야 WebKit/Quick Look 검사가 가능합니다. Codex 등의 추가 샌드박스 안에서는 네이티브 GUI 프로브에 별도 실행 권한이 필요할 수 있습니다. `--disable-sandbox`는 SwiftPM의 빌드 샌드박스 옵션이며 제품 확장의 App Sandbox를 끄지 않습니다.

추가 문서군 검사는 `python3 scripts/fetch-corpus.py` 후 `python3 scripts/run-corpus.py`입니다. 공개 평가 문서는 `.build`에만 저장하며 앱이나 저장소에 포함하지 않습니다. 결과는 `.build/corpus-results/results.json`입니다. 성공은 정상 페이지 생성·이미지 디코딩·원본 불변 검사이며 원본 레이아웃 정확도를 뜻하지 않습니다.

## 동작 및 제한

- 읽기 전용 입력 → Swift 컨테이너 검사 → 로컬 WASM Worker → 정제된 SVG → WebKit 표시 순서입니다. 문서 내용을 서버로 전송하는 기능은 없습니다. WebKit 실행을 위해 `network.client` entitlement를 사용하지만 화면과 Worker에는 외부 연결을 금지하는 CSP를 적용합니다.
- 외부 링크·스크립트·OLE 객체를 실행하지 않습니다. 보호 문서는 해제하지 않고 오류로 반환합니다.
- 입력 50 MiB, 500쪽, SVG 문자열 100 MiB, WASM 선형 메모리 256 MiB를 제한합니다. ZIP 항목 4,096개, 압축 해제 항목 40 MiB/총 100 MiB, XML 깊이 128을 제한합니다. 이미지도 디코딩 전 메타데이터 크기 검사를 거칩니다.
- 글꼴과 복잡한 개체의 배치는 원본과 다를 수 있습니다. 엔진 경고·이미지 실패·제거된 요소는 상단에 표시합니다. 실패한 이미지는 원래 영역을 남깁니다.
- ZIP64, 분할 ZIP, HWP 3.x, 암호·배포용·DRM 문서는 현재 지원하지 않습니다. 특수 수식·차트·OLE·벡터 이미지의 원본 동일성은 보장하지 않습니다.
- 앱의 영구 문서 캐시는 만들지 않습니다. macOS 자체의 Quick Look 캐시는 별개입니다.

## 개발판 패키지

```sh
python3 scripts/package-local.py
```

`.build/releases`에 adhoc 서명된 개발용 ZIP과 SHA256이 생성됩니다. Developer ID 서명·공증·Gatekeeper 배포 검증은 수행하지 않았습니다. 공개 배포 전 기준 문서, 글꼴, 접근성, OS/CPU 호환성, 의존성 고지의 검증이 필요합니다.

버전 변경 내역은 [CHANGELOG](CHANGELOG.md), 라이선스 고지는 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)를 참고하세요.

# HWP Preview

macOS Finder에서 **HWP 5.x와 HWPX 문서를 스페이스바로 미리 보는 Quick Look 확장**입니다. 본문·페이지·표·이미지를 표시하고 Finder 썸네일도 제공합니다. 문서를 서버에 업로드하지 않고 Mac 안에서 렌더링합니다.

[최신 버전 다운로드](https://github.com/grabic1060/mac-hwp-preview/releases/latest) · [변경 내역](CHANGELOG.md) · [문제 제보](https://github.com/grabic1060/mac-hwp-preview/issues)

## 지원 환경

- Apple Silicon Mac(M1 이상), macOS 14 이상
- Intel용 앱은 현재 제공하지 않습니다.
- 실제 Finder 검증은 macOS 26에서 수행했습니다. 최소 버전으로 빌드한 것과 해당 OS의 실기 검증은 별개입니다.

## 설치 및 사용

1. Releases에서 `HWP-Preview-<버전>-macOS-arm64.zip`을 내려받아 압축을 풉니다.
2. `HWP Preview.app`을 **응용 프로그램(`/Applications`)** 폴더로 옮깁니다.
3. 앱을 한 번 실행하고 **Quick Look 확장 설정 열기** 버튼을 누릅니다. Quick Look 항목에서 HWP Preview 확장을 활성화합니다.
4. Finder에서 `.hwp` 또는 `.hwpx` 파일을 선택하고 **스페이스바**를 누릅니다. 여러 페이지는 스크롤로 읽습니다.

macOS 15 이상 설정 경로는 **일반 → 로그인 항목 및 확장 프로그램 → Quick Look**입니다. macOS 14에서는 **개인정보 보호 및 보안 → 확장 프로그램 → Quick Look**을 확인하세요. 앱 창을 닫아도 Finder 미리보기는 사용할 수 있습니다.

### Gatekeeper 경고가 나타나는 경우

현재 배포본은 **Developer ID 서명 및 Apple 공증 없이 adhoc 서명**됩니다. macOS에서 개발자를 확인할 수 없다는 경고가 나타날 수 있습니다. 공식 저장소에서 받은 파일인지 확인한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기**를 사용할 수 있습니다. [Apple 안내](https://support.apple.com/en-us/102445)

터미널로 이 앱의 다운로드 격리 속성을 제거하려면 다음을 실행하세요.

```sh
xattr -dr com.apple.quarantine "/Applications/HWP Preview.app"
open "/Applications/HWP Preview.app"
```

다른 위치에 설치했다면 경로를 바꾸세요. 이 명령은 지정한 앱과 내부 파일의 격리 속성만 제거하며 Apple의 검증을 추가하지 않습니다. 출처를 확인한 파일에만 사용하세요. 시스템 전체의 Gatekeeper를 끌 필요는 없습니다.

ZIP과 함께 제공되는 `.sha256` 파일로 다운로드 무결성을 확인할 수 있습니다. 두 파일이 같은 폴더에 있을 때 실행하세요.

```sh
shasum -a 256 -c HWP-Preview-0.1.0-macOS-arm64.zip.sha256
```

### 업데이트와 제거

새 버전은 Releases에서 내려받아 기존 앱을 종료한 뒤 교체하세요. Quick Look 창도 닫고 다시 열어 주세요. 앱에 Sparkle 기반 확인 기능이 있지만, **CI에 업데이트 서명 키를 연결하기 전까지 자동 업데이트 피드는 게시하지 않습니다**. Releases에 새 파일이 올라오는 것과 앱 내 자동 설치는 별개입니다.

업데이트 확인은 앱 실행 시와 실행 중에만 이루어집니다. 로그인 항목이나 별도 상주 프로그램을 설치하지 않습니다. 제거하려면 앱을 종료하고 확장을 비활성화한 뒤 앱을 휴지통으로 옮기세요.

## 지원 범위와 제한

- 본문·페이지·표·이미지를 읽기 전용으로 표시합니다. 원본 파일을 수정하지 않습니다.
- 글꼴, 복잡한 표·수식·차트·OLE·벡터 개체는 한글 프로그램과 다르게 표시되거나 일부 누락될 수 있습니다.
- HWP 3.x, 암호·DRM·배포용 문서, ZIP64·분할 ZIP은 지원하지 않습니다.
- 입력 50 MiB, 최대 500쪽 등 처리 한도를 적용합니다. 외부 링크·스크립트·OLE를 실행하지 않습니다.
- 문서 처리는 로컬에서 수행합니다. 앱의 업데이트 확인은 GitHub의 HTTPS 피드에 연결하며 문서 내용을 전송하지 않습니다.

문제를 제보할 때 macOS 버전, 앱 버전, 파일 형식과 증상을 적어 주세요. 민감한 문서는 공개 이슈에 첨부하지 마세요.

## 개발

Xcode 또는 macOS SDK가 있는 Swift 개발 환경, Python 3, curl이 필요합니다.

```sh
bash scripts/fetch-wasm.sh
python3 scripts/fetch-sparkle.py
python3 scripts/build-app.py
python3 scripts/package-local.py
```

앱은 `.build/app/HWP Preview.app`, ZIP과 체크섬은 `.build/releases/`에 생성됩니다. 렌더링 엔진과 Sparkle은 고정 버전·체크섬으로 내려받습니다. 개발 빌드를 Finder에 등록하려면 다음 명령을 사용하세요.

```sh
bash scripts/register-app.sh
```

### 검사

```sh
swift test --disable-sandbox
python3 scripts/test_wasm_limits.py
python3 scripts/test_release_config.py
python3 scripts/test-update-signature.py
```

GUI 통합 검사는 Swift 프로브를 `.build/swift`에 빌드한 뒤 수행합니다.

```sh
swift build --disable-sandbox --scratch-path .build/swift
bash scripts/fetch-fixtures.sh
python3 scripts/verify-local.py --system
python3 scripts/test-preview-controller.py
python3 scripts/test-updates.py
```

`--system`은 개발 빌드를 시스템에 등록합니다. 테스트 문서는 `.build`에만 저장하며 배포 ZIP에 넣지 않습니다. 검사의 통과는 원본 한글 출력과의 정밀한 레이아웃 일치를 보장하지 않습니다.

### 릴리스 자동화

`VERSION`, `BUILD_NUMBER`, `CHANGELOG.md`를 갱신하고 커밋한 뒤 일치하는 태그를 푸시합니다.

```sh
git tag -a v0.1.0 -m 'Release v0.1.0'
git push origin main
git push origin v0.1.0
```

다음 릴리스에서는 새 버전 번호를 사용하고 `BUILD_NUMBER`도 증가시킵니다. 기존 태그를 이동하지 마세요. [.github/workflows/release.yml](.github/workflows/release.yml)이 태그 일치 확인 → 테스트 → arm64 빌드 → 서명·ZIP 검사 → GitHub Release 게시를 수행합니다. `-alpha.N` 태그는 prerelease로 게시합니다. 기존 Release의 파일은 자동으로 덮어쓰지 않습니다.

Developer ID 인증서와 Apple 공증 자격 증명은 현재 CI에 필요하지 않습니다. 추후 서명·공증 및 Sparkle 업데이트 피드를 연결하는 절차는 [배포 문서](docs/DISTRIBUTION.md)에 있습니다.

## 라이선스

자체 코드는 [MIT License](LICENSE)로 제공합니다. RHWP, Sparkle 및 포함된 의존성은 각각의 라이선스를 따릅니다. 원문은 [ThirdParty](ThirdParty/), 설명은 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 포함되어 있으며 배포 앱에도 함께 제공됩니다. 외부 평가 문서와 별도 폰트는 배포하지 않습니다.

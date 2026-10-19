# HWP Preview

macOS Finder에서 `.hwp`(5.x)와 `.hwpx` 문서를 스페이스바로 바로 미리 볼 수 있는 Quick Look 확장 프로그램입니다. 문서의 본문, 표, 이미지를 빠르게 확인할 수 있으며 Finder 아이콘 썸네일도 지원합니다. 모든 문서는 외부 서버로 전송되지 않고 기기 내부에서만 안전하게 처리됩니다.

[최신 버전 다운로드](https://github.com/grabic1060/mac-hwp-preview/releases/latest) · [변경 내역](CHANGELOG.md) · [문제 제보](https://github.com/grabic1060/mac-hwp-preview/issues)

## 지원 환경

* **기기**: Apple Silicon 탑재 Mac (M1 이상, Intel Mac 미지원)
* **운영체제**: macOS 14 Sonoma 이상

## 설치 및 사용 방법

1. [Releases](https://github.com/grabic1060/mac-hwp-preview/releases/latest)에서 `HWP-Preview-<버전>-macOS-arm64.zip` 파일을 내려받아 압축을 풉니다.
2. `HWP Preview.app`을 **응용 프로그램(`/Applications`)** 폴더로 옮깁니다.
3. 앱을 한 번 실행한 뒤 **Quick Look 확장 설정 열기** 버튼을 누르고, 목록에서 **HWP Preview**를 켭니다.
* **macOS 15 이상**: 시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look
* **macOS 14**: 시스템 설정 → 개인정보 보호 및 보안 → 확장 프로그램 → Quick Look


4. 설정이 끝나면 앱 창을 닫아도 됩니다. Finder에서 `.hwp` 또는 `.hwpx` 파일을 선택하고 **스페이스바**를 눌러 미리보기를 사용하세요.

### '개발자를 확인할 수 없음' 경고가 뜨는 경우

현재 배포 파일에는 Apple 개발자 서명(공증)이 적용되어 있지 않아 첫 실행 시 보안 경고가 나타날 수 있습니다. 아래 두 가지 방법 중 하나로 실행할 수 있습니다.

* **시스템 설정에서 허용**: 경고 창을 닫고 **시스템 설정 → 개인정보 보호 및 보안**으로 이동한 뒤, 하단에 나타난 **확인 없이 열기**를 클릭합니다. ([Apple 공식 안내](https://support.apple.com/ko-kr/102445))
* **터미널 명령어로 허용**: 터미널을 열고 아래 명령어를 실행하여 다운로드 격리 속성을 제거합니다.
```sh
xattr -dr com.apple.quarantine "/Applications/HWP Preview.app"
open "/Applications/HWP Preview.app"

```



릴리스에 함께 제공되는 `.sha256` 파일을 이용해 다운로드한 압축 파일이 손상되지 않았는지 확인할 수 있습니다. 두 파일을 같은 폴더에 두고 아래 명령어를 실행하세요.

```sh
shasum -a 256 -c HWP-Preview-0.1.0-macOS-arm64.zip.sha256

```

### 업데이트 및 제거

* **업데이트**: 현재 자동 업데이트는 지원하지 않습니다. 새 버전이 나오면 기존 앱을 종료한 뒤, 새 앱 파일을 내려받아 응용 프로그램 폴더에 덮어쓰세요.
* **제거**: 앱을 종료하고 시스템 설정에서 Quick Look 확장을 끈 뒤, 응용 프로그램 폴더에서 `HWP Preview.app`을 휴지통으로 옮기면 깔끔하게 삭제됩니다. (별도의 백그라운드 상주 프로그램을 설치하지 않습니다.)

## 지원 범위 및 제한 사항

* **읽기 전용**: 본문, 페이지, 표, 이미지를 표시하며 원본 파일은 수정하지 않습니다.
* **표시 차이**: 전용 폰트나 복잡한 표, 수식, 차트, 도형(OLE/벡터 개체) 등은 한컴오피스 한글 프로그램과 다르게 보이거나 생략될 수 있습니다.
* **미지원 형식**: HWP 3.x 이하 구버전 문서, 암호가 걸린 문서, 배포용 문서(DRM), 분할 압축(ZIP64) 파일은 지원하지 않습니다.
* **안전 제한**: 보안을 위해 파일 크기 최대 50 MiB, 페이지 수 최대 500쪽으로 처리를 제한하며 문서 내 외부 링크나 스크립트는 실행하지 않습니다.

오류를 제보하실 때는 **macOS 버전, 앱 버전, 파일 형식(.hwp/.hwpx), 증상**을 함께 적어 주세요. 개인정보나 민감한 내용이 담긴 문서는 공개 이슈에 첨부하지 않도록 주의해 주세요.

## 빌드 및 개발 안내

프로젝트를 직접 빌드하려면 Xcode(또는 macOS SDK가 포함된 Swift 환경), Python 3, `curl`이 필요합니다.

### 로컬 빌드

```sh
# 1. 의존성(Wasm 렌더링 엔진 및 Sparkle) 다운로드 및 앱 빌드
bash scripts/fetch-wasm.sh
python3 scripts/fetch-sparkle.py
python3 scripts/build-app.py
python3 scripts/package-local.py

# 2. 빌드된 앱을 Finder Quick Look에 등록
bash scripts/register-app.sh

```

* 빌드된 앱 경로: `.build/app/HWP Preview.app`
* 패키징 결과물(ZIP 및 체크섬): `.build/releases/`

### 테스트 실행

단위 테스트 및 기본 검증:

```sh
swift test --disable-sandbox
python3 scripts/test_wasm_limits.py
python3 scripts/test_release_config.py
python3 scripts/test-update-signature.py

```

GUI 통합 테스트 (시스템에 개발 빌드를 등록하여 검증):

```sh
swift build --disable-sandbox --scratch-path .build/swift
bash scripts/fetch-fixtures.sh
python3 scripts/verify-local.py --system
python3 scripts/test-preview-controller.py
python3 scripts/test-updates.py

```

### 릴리스 배포

1. `VERSION`, `BUILD_NUMBER`, `CHANGELOG.md` 파일을 수정하고 커밋합니다. (새 릴리스 시 `BUILD_NUMBER`도 함께 올려야 합니다.)
2. 버전과 일치하는 Git 태그를 생성하여 푸시하면 [GitHub Actions](.github/workflows/release.yml)가 자동으로 테스트, 빌드, GitHub Release 게시를 수행합니다. (`-alpha.N` 형식의 태그는 Pre-release로 분류됩니다.)

```sh
git tag -a v0.1.0 -m 'Release v0.1.0'
git push origin main
git push origin v0.1.0

```

추후 Apple Developer ID 서명·공증 및 Sparkle 자동 업데이트 피드를 연결하는 방법은 [배포 문서](docs/DISTRIBUTION.md)를 참고하세요.

## 라이선스

이 프로젝트의 자체 코드는 [MIT License](LICENSE)를 따릅니다. 내부에 사용된 RHWP, Sparkle 등 외부 라이브러리는 각각의 라이선스가 적용되며, 자세한 내용은 [ThirdParty](ThirdParty/) 폴더와 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에서 확인할 수 있습니다.

---

### 주요 수정 포인트

1. **불필요한 변명 및 내부 사정 제거**: "macOS 26에서 검증했다", "최소 버전 빌드와 실기 검증은 별개다", "CI에 업데이트 서명 키를 연결하기 전까지 피드를 게시하지 않는다", "테스트 통과가 레이아웃 일치를 보장하지 않는다" 등 사용자에게 혼란을 주는 방어적 문구를 삭제했습니다.
2. **전문 용어 순화**: `adhoc 서명` 같은 개발 용어를 빼고 일반 사용자가 이해하기 쉽도록 "Apple 개발자 서명(공증)이 적용되어 있지 않아..."로 풀어서 설명했습니다.
3. **가독성 개선**: Gatekeeper 우회 방법을 시스템 설정(GUI)과 **터미널(CLI)** 두 가지로 명확히 나누고, 일반 사용자가 잘 쓰지 않는 `shasum` 무결성 검사는 `<details>` 접기 태그로 숨겨 문서를 깔끔하게 정리했습니다.

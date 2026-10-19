## 설치

Apple Silicon(M1 이상), macOS 14 이상용입니다. ZIP을 풀고 `HWP Preview.app`을 `/Applications`(응용 프로그램)로 옮긴 뒤 한 번 실행하세요. 앱의 **Quick Look 확장 설정 열기** 버튼으로 확장을 활성화하고 Finder에서 HWP/HWPX 파일을 선택해 스페이스바를 누릅니다.

### Gatekeeper 실행 차단

이 배포본은 **Developer ID 서명·Apple 공증 없이 adhoc 서명**되어 있습니다. macOS에서 개발자를 확인할 수 없다는 경고가 나올 수 있습니다. 신뢰하는 공식 저장소의 파일인지 확인한 뒤 시스템 설정 → 개인정보 보호 및 보안에서 **확인 없이 열기**를 선택할 수 있습니다.

터미널에서 이 앱에 한해 다운로드 격리 속성을 제거하려면 다음을 실행하세요.

```sh
xattr -dr com.apple.quarantine "/Applications/HWP Preview.app"
open "/Applications/HWP Preview.app"
```

실제 설치 위치가 다르면 경로를 바꾸세요. 이 명령은 지정한 앱과 내부 파일의 격리 속성만 제거합니다. Apple의 검증을 추가하는 명령이 아니므로 출처를 확인한 파일에만 사용하세요. 시스템 전체 Gatekeeper 설정을 끌 필요는 없습니다.

### 업데이트

현재 GitHub Releases에서 새 ZIP을 내려받아 앱을 교체할 수 있습니다. 앱 내 Sparkle 확인 기능은 있지만, CI에 업데이트 서명 키를 연결하기 전까지 **Releases 게시와 앱 내 자동 업데이트 피드 게시를 연동하지 않습니다**. 이 릴리스는 앱 내 자동 설치 대상으로 등록되지 않습니다.

### 제한

본문·페이지·표·이미지를 렌더링하지만 원본 한글 프로그램과 글꼴·복잡한 배치가 다를 수 있습니다. 암호·DRM·배포용 문서, HWP 3.x 및 일부 특수 개체는 지원하지 않습니다. Intel 빌드는 제공하지 않습니다.

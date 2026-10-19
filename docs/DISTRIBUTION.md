# 서명·공증·자동 업데이트 배포

## v0.1.0부터의 기본 공개 배포

버전 태그 push 시 `.github/workflows/release.yml`이 Developer ID 없이 adhoc 서명한 arm64 ZIP을 Releases에 게시합니다. Apple 공증과 Sparkle appcast 서명은 이 워크플로에 포함되지 않습니다. 설치 및 Gatekeeper 안내는 README와 `release/INSTALL.md`를 참고하세요. 아래 절차는 추후 공증 또는 별도 업데이트 서명 키를 사용하는 수동 배포 경로입니다.

## 현재 상태

Sparkle 2.10.0을 호스트 앱에 통합했습니다. Quick Look 확장은 업데이트를 확인하지 않습니다. 앱 실행 직후와 앱이 실행 중인 동안 Sparkle 주기(기본 24시간)로 확인하며, 사용자의 Sparkle 설정을 존중합니다. 로그인 항목, LaunchAgent, 상주 업데이트 서비스를 설치하지 않습니다. 설치 시에만 Sparkle의 임시 설치 도우미가 실행됩니다. 기본적으로 업데이트 다운로드·설치는 사용자 확인을 거칩니다.

기본 빌드는 `release/update-config.json`의 공개 GitHub HTTPS feed를 사용합니다. 현재 feed는 비어 있어 공개 업데이트가 없으며 v0.1.0부터 GitHub Releases에 ZIP을 게시합니다. 업데이트 feed에는 아직 항목을 추가하지 않습니다. 빈 JSON을 `--update-config`로 지정한 빌드는 네트워크 확인을 하지 않으며 업데이트 버튼이 비활성화됩니다. 사용자가 제공해야 하는 주소와 Developer ID Application 인증서를 대신하여 가짜 주소나 Apple Development 서명을 사용하지 않습니다.

## 최초 설정

1. Developer ID 배포를 사용할 경우 Xcode 또는 키체인 접근에서 **Developer ID Application** 인증서와 대응하는 개인 키를 설치합니다. 인증서/개인 키를 앱 리소스나 저장소에 복사하지 않습니다. `security find-identity -v -p codesigning`으로 사용 가능한 서명 ID를 확인합니다.
2. `python3 scripts/fetch-sparkle.py`로 고정된 공식 프레임워크를 받고 체크섬을 검증합니다.
3. 이 Mac에는 `org.hwp-preview.app` 계정의 Sparkle Ed25519 키가 키체인에 생성되어 있습니다. 다른 Mac에서 새 키를 무작정 생성하면 기존 사용자의 업데이트가 끊길 수 있으므로 기존 키를 안전하게 이전해야 합니다. 개인 키는 채팅·Git·배포 서버에 넣지 않습니다. 공개 키는 `release/update-config.example.json`에 기록되어 있습니다.
4. 현재 `release/update-config.json`을 사용하거나 예시 JSON을 `.build/update-config.json`으로 복사해 다른 실제 HTTPS appcast URL을 지정합니다. 이 JSON에는 공개 정보만 들어갑니다.
5. Apple 공증용 인증 정보를 `xcrun notarytool store-credentials`로 키체인 프로필에 보관합니다. 스크립트에는 프로필 이름만 전달합니다. 암호를 명령행 인자로 넣거나 저장소에 기록하지 마세요.

## 빌드 및 로컬 배포물 생성

```sh
python3 scripts/fetch-wasm.sh
python3 scripts/fetch-sparkle.py
python3 scripts/build-app.py --release \
  --identity 'Developer ID Application: YOUR NAME (TEAMID)' \
  --update-config .build/update-config.json
python3 scripts/prepare-release.py \
  --notary-profile HWPPreview-Notary \
  --download-url-prefix 'https://YOUR-HOST/releases/'
```

현재 사용자는 유료 Apple Developer 멤버십이 없어 위 Developer ID·공증 경로는 실행할 수 없습니다. 인증서 없이 개발용 업데이트를 준비하려면 다음 명령을 사용합니다. Ed25519 업데이트 서명은 Developer ID와 별개이며, 이를 사용해도 Gatekeeper 공증을 대신하지는 않습니다.

```sh
python3 scripts/build-app.py
python3 scripts/prepare-release.py --allow-unnotarized \
  --download-url-prefix 'https://github.com/grabic1060/mac-hwp-preview/releases/download/v0.1.0-alpha.5/'
```

위 URL은 향후 게시 위치이며 해당 alpha.5 Release는 존재하지 않습니다. 스크립트는 로컬 산출물만 만들고 게시하지 않습니다. 현재 macOS에서 실제 업데이트 서명 키 접근 요청이 취소되었으므로 배포 feed 생성 시 키체인 접근 허용이 필요합니다.

실제 값으로 바꿔 실행합니다. build-app은 올바른 Developer ID와 업데이트 설정이 없으면 출력 앱을 지우기 전에 중단합니다. 안쪽 Sparkle 도우미·프레임워크 → Quick Look 확장 → 앱 순서로 Hardened Runtime 및 timestamp를 적용합니다. 개발 빌드는 `--release` 없이 adhoc 서명합니다.

prepare-release는 명시적으로 실행할 때만 Apple 공증 서비스에 제출합니다. Accepted 확인 → staple 및 Gatekeeper 검사 → 최종 ZIP → EdDSA 서명 enclosure를 포함한 appcast 순서이며 GitHub/배포 서버에 업로드하지 않습니다. 결과는 `.build/distribution/<version>-<arch>/`에 저장됩니다. 실패한 실행의 폴더는 진단을 위해 남으며, 재시도 전 다른 위치로 옮깁니다.

직접 배포할 파일은 `.app` 또는 ZIP, 업데이트용 ZIP과 appcast.xml입니다. 업데이트 ZIP이 먼저 다운로드 가능한 상태가 된 뒤 feed를 게시해야 합니다. feed는 빌드 시 지정한 URL에, ZIP은 download-url-prefix에 게시합니다. appcast에는 증가하는 BUILD_NUMBER로 버전을 비교하는 정보와 CPU/최소 OS 조건이 포함됩니다. 기존 파일을 덮어쓰거나 BUILD_NUMBER를 재사용하지 않습니다.

## 검증 범위

```sh
python3 scripts/test_release_config.py
python3 scripts/test-updates.py
python3 scripts/test-update-signature.py
```

두 번째 검사는 GUI 세션에서 실제 Sparkle로 localhost 테스트 피드의 새 버전·동일 버전·이전 버전·잘못된 XML을 확인합니다. HTTP 허용은 임시 테스트 앱에만 있으며 제품 빌드 설정은 HTTPS를 요구합니다. 최종 배포물을 게시하기 전에 실제 설치된 구 버전에서 신 버전 다운로드, 서명 검증, 앱 교체, 재실행, Quick Look 확장 갱신까지 별도로 확인해야 합니다. 개발 빌드 파서 검사는 이 최종 검증을 대체하지 않습니다.

## 확인한 공식 자료

- [Sparkle 설치·서명·배포](https://sparkle-project.org/documentation/)
- [Sparkle 실행 시 확인과 앱 내 확인 주기](https://sparkle-project.org/documentation/programmatic-setup/)
- [Apple 공증](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

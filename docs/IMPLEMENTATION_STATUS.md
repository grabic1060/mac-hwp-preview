# 구현 및 검증 상태

## M1: Quick Look 통합 기반 (2026-10-16)

- AppKit 호스트, Quick Look Preview/Thumbnail 확장, HWP/HWPX UTI 연결을 구현했습니다.
- 확장 내부 `Process` 실행이 실패하여 RHWP 0.8.7 WASM을 번들에 넣고 WKWebView의 로컬 URL scheme으로 실행합니다. 네이티브 CLI는 비교용 개발 도구로만 남깁니다.
- WebKit 보조 프로세스 시작에 `network.client` entitlement가 필요했습니다. 문서 화면에는 CSP와 외부 탐색 차단을 적용합니다. entitlement 자체가 네트워크 접근을 금지하지 않으므로 네트워크 차단 회귀 검증은 별도로 필요합니다.
- macOS 26 / Apple Silicon에서 실제 `QLThumbnailGenerator` 호출로 HWP 2쪽 문서와 HWPX 10쪽 문서의 첫 페이지 썸네일 생성에 성공했습니다(`representationType=2`). PNG를 열어 한글·표·표지 이미지 표시를 확인했습니다.
- Swift 단위 테스트 4개, 앱/확장 컴파일, adhoc 서명 검증을 통과했습니다.
- 전체 미리보기는 독립 WKWebView 프로브에서 양 형식 렌더링을 확인했습니다. Finder Space 키 화면 및 Preview 확장 호출은 아직 별도 검증 대상입니다.

## 남은 통과 조건

- M0 엔진 선정의 충실도 게이트는 미통과입니다. 같은 RHWP 엔진의 PDF/SVG 비교는 독립 기준 출력이 아닙니다.
- M2~M4의 페이지·줄바꿈·표 병합·이미지 배치·보호 문서·손상 입력 검증을 계속합니다. HWPX와 이미지도 최초 통합 목표에 유지합니다.
- 계획서의 양 형식 각 30개 정상 문서, 30개 오류 문서, 공식 한글 기준 출력, 1pt 배치 비교, 성능 p95 및 접근성 검증은 아직 확보하지 못했습니다.
- M5의 Developer ID 서명·공증과 Intel/macOS 14 실기 검증은 완료하지 않았습니다. 현재 결과는 개발용이며 정식 릴리스 통과를 의미하지 않습니다.

평가 문서와 생성 이미지는 `.build/fixtures`, `.build/evidence`, `.build/quicklook`에만 보관하며 배포하지 않습니다.

## M2: 전체 페이지 탐색 기반 (2026-10-16)

- 쪽 번호 이동과 너비 맞춤·확대·축소, 요청 교체 시 오래된 결과 무시, 제한된 입력 스냅샷 읽기를 추가했습니다.
- 실제 WebKit 회귀 검사에서 HWP 2쪽/HWPX 10쪽 전체 SVG 생성, 마지막 쪽 본문, 확대 및 너비 복원, 마지막 쪽 이동을 확인했습니다. 단일 프로브 처리 시간은 각각 0.32초/0.63초이며 p95 판정이 아닙니다.
- `QLPreviewView` 시스템 호스트로 HWPX를 열고 Preview 확장의 `WASM preview complete` 로그를 확인했습니다. Finder Space 키 직접 조작 검증과 구분합니다.
- 페이지 수·줄바꿈의 공식 기준 비교는 미완료입니다. 이 커밋은 페이지 탐색 구현 체크포인트이며 M2 충실도 게이트 통과를 선언하지 않습니다.

## M3: 표·이미지 표시와 누락 진단 (2026-10-16)

- SVG의 링크는 실행을 막되 내부 본문을 보존합니다. 허용된 SVG 요소, 로컬 clip 참조, 내장 래스터만 표시하며 제거된 요소 수를 표시합니다.
- 이미지 디코딩 실패 시 원래 위치·크기·변환을 유지한 색상 영역과 접근성 제목을 남기고, 상단에 실패 건수를 표시합니다. 엔진의 입력 검증 경고 수도 함께 알립니다.
- WebKit 회귀 검사에서 링크 본문 보존, 외부 이미지·스크립트 제거, clip 유지, 손상 이미지 2개의 자리 표시, 정상 PNG 디코딩을 통과했습니다. 외부 fetch가 `connect-src` CSP 위반으로 차단되는 것도 확인했습니다.
- HWP 표지 문서 이미지 3개, HWPX 이미지 문서 5쪽/이미지 5개가 디코딩 오류 없이 표시됐습니다. HWPX XML의 `pic` 5개와 대조했습니다. HWPX 표 문서 XML에는 표 15개가 있으며 첫 페이지 표 표시를 시각 확인했습니다.
- 표 병합·반복 머리행·다양한 감싸기와 모든 페이지 개체의 좌표 정확도는 공식 기준 출력과 비교해야 합니다. 현재의 개수/디코딩/시각 검사는 그 판정을 대체하지 않습니다.

## M4: 입력 방어와 취소 가능한 처리 (2026-10-16)

- WASM을 module Web Worker로 분리했습니다. 타임아웃·취소 시 Worker를 종료하고, 교체 요청은 이전 결과를 무시합니다. 컨테이너 검사는 Swift 백그라운드 큐에서 수행합니다.
- HWPX의 중앙/로컬 ZIP 헤더 일치, CRC, 중복/이탈 경로, 암호화, 실제 압축 해제 크기(항목 40 MiB/총 100 MiB), 항목 4,096개 제한을 검사합니다. ZIP64·분할 ZIP·지원하지 않는 압축법은 거부합니다.
- XML DTD/엔티티 선언을 파서 전에 거부하고, 깊이 128·파일별 요소 200,000개를 제한합니다. 암호화 manifest를 거부합니다.
- HWP CFB FAT/mini-FAT의 범위와 순환, FileHeader 버전 및 암호·배포용·DRM·인증서·개인정보 보호 플래그를 검사합니다. 보호 해제는 시도하지 않습니다.
- 11개 XCTest(직접 생성한 구조 fixture와 여러 절단 경계 포함)를 통과했습니다. 실제 HWP/HWPX에서 Worker 취소·재요청 검사, 네이티브 요청 교체·강제 타임아웃·renderer 해제 검사를 통과했습니다.
- Web Worker 응답 후 500쪽·SVG 100 MiB 제한도 적용합니다. 다만 WASM 내부의 순간 메모리 사용 상한, HWP의 모든 스트림 압축 해제 총량, 이미지 디코딩 전 픽셀 제한은 아직 강제하지 못합니다. 이 항목은 정식 출시 차단 사유로 유지합니다.
- 합성 구조 fixture는 실제 정상 문서 60개/오류 문서 30개 기준 문서군을 대체하지 않습니다.

### 입력 구조 근거 (2026-10-16 접속 확인)

- [Microsoft CFB Header](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/05060311-bfce-4b12-874d-71fd4ce63aea): FAT/mini-FAT 및 섹터 정보.
- [한컴 HWP 5.0 revision 1.3](https://cdn.hancom.com/link/docs/%ED%95%9C%EA%B8%80%EB%AC%B8%EC%84%9C%ED%8C%8C%EC%9D%BC%ED%98%95%EC%8B%9D_5.0_revision1.3.pdf): PDF 13쪽 FileHeader 보호 속성.
- [한컴 HWPX 구조](https://tech.hancom.com/hwpxformat/): 패키지와 암호화 manifest.
- [PKWARE ZIP specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT): ZIP 중앙/로컬 헤더·압축 및 CRC.

### M4 자원 한도 보강

- 번들 생성 시 RHWP WASM의 단일 memory 선언에 최대 4,096페이지(256 MiB)를 설정합니다. 메모리 최소값·섹션 형식이 예상과 다르면 빌드가 실패합니다. Node의 실제 WASM 검증과 한도 초과 `memory.grow` 실패를 확인했습니다. 이는 선형 메모리 상한이며 WebKit 프로세스 전체 RSS 상한은 아닙니다.
- HWP의 DocInfo/Section 및 BIN 계열 압축 스트림에 항목 40 MiB·총량 100 MiB 제한과 본문 레코드 수·깊이 검사를 추가했습니다. 기존 파일에서 발견한 CRC32/ISIZE 종료부는 검증 후 허용합니다. HWP 확장 스토리지의 모든 압축 변종 지원은 아직 미확인입니다.
- SVG 이미지를 DOM에 넣을 때 URL을 보류하고 ImageIO 메타데이터로 먼저 검사합니다. 이미지당 20 MiB·4천만 픽셀(프레임 합계), 요청당 8천만 픽셀을 넘으면 원래 영역에 누락 표시를 남깁니다.
- Swift 15개 테스트와 WASM 변환기 Python 3개 테스트 통과. 실제 HWP/HWPX 본문·이미지·탐색 검사 통과. 원본 레이아웃의 정답 비교를 의미하지 않습니다.
- WASM memory 필드 근거: [WebAssembly binary types](https://webassembly.github.io/spec/core/binary/types.html), [memory section](https://webassembly.github.io/spec/core/binary/modules.html) (2026-10-16 접속 확인).

### M4 확장 문서군 회귀

- RHWP v0.8.7 공개 샘플에서 HWP 30개/HWPX 30개를 선택하고 Git blob 해시를 고정했습니다. 문서 자체는 로컬 `.build/corpus`에만 둡니다.
- 첫 실행 59/60 통과. 암호화 manifest가 생략된 HWPX 1개가 과도한 필수 항목 검사에 걸린 문제를 수정했습니다. 모든 실제 XML의 암호화·DTD·손상 검사는 유지합니다. 회귀 fixture를 추가했습니다.
- 이 문서군은 독립 공식 출력과 사용 허가를 확정한 기준 문서군이 아닙니다. 각 30개라는 수량만으로 원래 출시 게이트를 통과했다고 판정하지 않습니다.

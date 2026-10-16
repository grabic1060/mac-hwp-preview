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

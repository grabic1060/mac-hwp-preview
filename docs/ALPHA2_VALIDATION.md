# alpha.2 미리보기 연결 수정 검증 — 2026-10-17

## 관측과 진단

사용자 보고는 Finder Space 미리보기에서 확장 오류와 함께 작은 문서 썸네일만 표시되는 현상이었습니다. 실제 Finder 로그에서 렌더링 완료 직후 ViewBridge Code 17 연결 해제가 확인됐습니다. 기존 완료 로그 기반 검사는 이 오류를 놓칠 수 있었습니다.

코드에서 준비 중 루트 뷰 교체 및 일시적 비표시 시 렌더러 폐기를 확인했습니다. 고정 루트 NSView에 WKWebView를 하위 뷰로 연결하고, 비표시와 요청 종료를 구분하도록 수정했습니다.

## Red → Green

- 수정 전 `test-preview-controller.py`: `FAIL: hosted root view replaced during prepare` 재현.
- 수정 후 HWP와 HWPX 모두 고정 루트, 준비 중 숨김/재표시, 리사이즈, 다중 페이지 유지 통과.
- Swift XCTest 15개 통과.
- `verify-local.py --system`: 페이지·이미지·취소/복구·네이티브 수명 및 양 형식 시스템 Preview/Thumbnail 통과. 표시 구간의 ViewBridge 연결 오류가 없어야 통과하도록 검사를 강화했습니다.
- 별도의 QLPreviewPanel에서 HWP/HWPX 표시와 창 리사이즈를 실행하고 완료 로그 및 연결 해제 로그 부재를 확인했습니다. 해당 패널 프로브도 반복 검사 스크립트에 포함했습니다.

Finder 자체 키 입력 자동화나 사용자가 보고한 특정 파일 재현은 수행하지 않았습니다. 실제 Finder에서 재확인할 때 기존 Quick Look 창을 닫은 뒤 문서를 다시 선택하여 스페이스바를 누릅니다. 현재 등록 경로는 작업 폴더의 `.build/app/HWP Preview.app`이며 build 8입니다.

원본 출력 충실도, Intel/이전 OS 실기, Developer ID 서명·공증은 이전 개발판과 마찬가지로 미완료입니다.

# M0 — 엔진 실행 검증 (2026-10-15)

- 공식 한글 SDK의 존재는 확인했으나 macOS 바이너리와 재배포 권한은 확보하지 못했습니다. 부재로 단정하지 않습니다.
- RHWP v0.8.7의 공식 GitHub release macOS arm64 아카이브를 내려받고 게시 SHA256과 일치함을 확인했습니다. 버전·해시는 fetch-engine.sh에 고정했습니다.
- 실제 HWP BookReview 문서 → PDF 2쪽, HWPX form-002 → PDF 10쪽 생성에 성공했습니다. `export-pdf --json` 결과와 PDF를 .build/evidence에 보관합니다.
- Xcode 26.6, Swift 6.3.3, arm64 환경입니다. Rust 빌드 도구 없이 배포 CLI를 평가했습니다.
- 후보 채택은 조건부입니다. PDF 생성 성공은 원본 레이아웃 정확성 또는 Quick Look 샌드박스 실행을 증명하지 않습니다. 공식 앱 기준 PDF 및 독립 시각 검증은 아직 없습니다.
- 공식 SDK 문의·구매는 하지 않았습니다. 이 경로는 공개 엔진을 사용한 기술 검증이며, SDK 평가를 영구 배제하지 않습니다.
- 로컬 평가 문서는 저장소·배포물에 복사하지 않습니다. 라이선스·출처를 확정한 기준 문서군은 별도로 확보해야 합니다.

출처: https://github.com/edwardkim/rhwp/releases/tag/v0.8.7
공식 SDK: https://download.hancom.com/product/sdk/hwpSdk

## 단계 상태

M0: 양 형식 PDF 실행 성공. 원본 충실도와 확장 실행은 다음 검증에서 확인해야 하므로 전체 선정 게이트는 미통과입니다.

# macOS 27 Golden Gate / Xcode 27 — 1.0.0 개발 기준

확인일 2026-09-23. 최소 실행·테스트 대상은 macOS 27.0, 빌드 아키텍처는 arm64입니다. Package.swift, 앱 Info.plist 생성과 빌드 사전 검사가 같은 기준을 사용합니다.

Apple의 Xcode 27 표는 Swift 6.4와 macOS 27 SDK를 명시하며, Swift 5/6 언어 모드를 모두 지원합니다. Xcode 자체는 macOS 26.6 이상에서 실행할 수 있지만, **이 프로젝트의 최소 실행 대상이 27이므로 테스트를 포함하는 빌드 명령은 macOS 27 이상에서 실행합니다.** macOS 27은 Apple Silicon 대상입니다. Intel 지원 중단은 이 개발 라인의 선택이며 Xcode가 모든 과거 OS용 Intel 빌드를 금지한다는 뜻은 아닙니다.

## 검사

`bash Check-Xcode.command`는 선택된 Xcode 27.x, SDK 27.x, Swift 6.4 이상(6.x), native arm64, 실행 OS를 검사합니다. 앱 버전·최소 OS 일치와 음원 해시도 확인하고 빌드·XCTest를 실행합니다. DEVELOPER_DIR를 지정하면 해당 설치를 사용하며 전역 xcode-select는 변경하지 않습니다.

`bash Check-Xcode.command swift6`는 별도의 `.build/compatibility-swift6/package`와 `CINDER_SWIFT6=1`을 사용해 Swift 6 언어 모드로 검사합니다. 기본 경로는 Swift 5 + StrictConcurrency 진단입니다. 언어 모드와 SDK/컴파일러 버전은 별개의 설정입니다. Swift 5 모드에서 종료 코드가 0이어도 동시성 경고 검토가 필요합니다.

각 경로는 toolchain.txt, build.log, tests.log, result.txt를 남깁니다. 실제 장치 출력·UI·장시간 전력 검사는 자동 빌드 결과에 포함하지 않습니다. 실행 확인 전에는 지원 완료로 표시하지 않습니다.

## 남은 검토

- RenderKernel의 unchecked Sendable, 준비 취소와 C 버퍼 소유권, AVAudioEngine 설정 변경 알림.
- MainRunLoopTicker의 actor 격리와 해제 시점, 장치 감시와 UI 작업 종료.
- 외부 음원과 7종 프리셋의 AVAudioConverter 변환, 재생 경계와 장치 분리.
- 이전 0.4.x 설정을 가진 실제 Mac에서 게인·시간·음악·테마 복원과 자동 재생되지 않음.
- Light/Dark/System, 창 최소 크기, 3개 언어, 팝업 포커스·호버 및 새 onChange/activate 처리.

참조: [Xcode 요구사항](https://developer.apple.com/xcode/system-requirements), [Xcode 27 릴리스 노트](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes), [macOS 27 릴리스 노트](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes), [Swift 동시성 검사](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/).

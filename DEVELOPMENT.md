# 개발 안내

프로젝트 루트의 `Package.swift`를 Xcode에서 열거나 아래 명령으로 빌드합니다.
실행·테스트 환경은 macOS 27.0 이상과 Apple Silicon이며, Xcode 27.x,
macOS 27 SDK, Swift 6.4 이상(6.x 컴파일러)이 필요합니다.

## Swift 버전과 앱 채널

| 구분 | 현재 값 | 의미 |
|---|---|---|
| Swift 컴파일러 | 6.4 | 소스를 검사하고 실행 파일을 만드는 도구 |
| Swift 언어 모드 | 기본 5, 별도 검사 6 | 같은 컴파일러에서 적용할 언어·동시성 규칙 |
| Cinder 버전·출시 채널 | `1.0.0-dev` · `dev` | 앱의 기능 버전과 배포 단계 |

Swift 6.4 컴파일러를 이미 사용합니다. 기본 언어 모드는 Swift 5이며 전체 동시성
진단을 켜 두었습니다. `Check-Xcode.command swift6`는 같은 컴파일러로 Swift 6
언어 모드를 별도 검사합니다. 앱의 dev·stable 선택은 이 설정을 바꾸지 않습니다.
[Swift 공식 버전 호환성 안내](https://docs.swift.org/latest/documentation/the-swift-programming-language/compatibility/)도
컴파일러 버전과 언어 모드를 구분합니다.

## 준비와 빌드

```bash
bash Setup-Mac.command
bash Check-Xcode.command
bash Build-App.command
```

Setup은 실행 환경·버전·리소스를 검사하고 고정된 Yams 의존성을 준비합니다.
다운로드 없이 환경만 확인하려면 `bash Setup-Mac.command --check-only`를 사용합니다.
Check-Xcode는 기본 Swift 5 모드와 전체 동시성 진단으로 빌드·XCTest를 실행합니다.
Build-App은 테스트 후 릴리스 앱 `dist/Cinder (Dev).app`을 생성합니다.

각 명령은 기존 Xcode 선택을 사용합니다. 다른 Xcode 설치를 사용하려면 해당
명령에 `DEVELOPER_DIR`를 지정하세요. 전역 Xcode 설정은 변경하지 않습니다.
`Package.resolved`를 소스와 함께 관리하며 빌드 캐시는 공유하지 않습니다.

```bash
# 별도 Swift 6 언어 모드 검사
bash Check-Xcode.command swift6
# 테스트와 앱 빌드 후 로컬 설치 패키지 생성
bash Build-DMG.command
bash Build-PKG.command
```

로그는 `.build/mac-setup/`, `.build/compatibility-native/`,
`.build/compatibility-swift6/`, `.build/golden-gate-app/`에 저장합니다.
종료 코드와 함께 컴파일 경고를 확인하세요. 현재 패키지는 로컬 ad-hoc 서명이며,
공개 배포 전 Developer ID 서명·공증과 설치 검증이 필요합니다.

## 프로젝트 구성

| 경로 | 역할 |
|---|---|
| Sources/ | 앱·Core·Audio·DSP·Platform·Storage 모듈 |
| Tests/ | XCTest, 오디오 시험 자료, 출시 정책 검사 |
| Tools/ | 소스 검증·패키징·선택적 음원 생성 |
| Examples/ · ReferenceProfiles/ | 설정 예시와 하드웨어 참고 자료 |
| Docs/ | 구조·음원·도구·출시 운영 문서 |

내장 FLAC 7곡과 시험 자료를 포함하므로 일반 빌드에 음원 합성기나 악기 뱅크는
필요하지 않습니다. 모듈 역할과 실시간 오디오 제약은 [아키텍처](Docs/ARCHITECTURE.md)에 있습니다.

## 소스 검사와 패키징

Python 3 표준 라이브러리만으로 다음을 실행할 수 있습니다.

```bash
python3 Tools/Validate-Source.py
python3 -m unittest discover -s Tests/Tooling -v
python3 Tools/Check-Release.py
python3 Tools/Package-Source.py
```

Check-Release는 커밋된 Git 체크아웃에서 실행합니다. 소스 검사는 네이티브
컴파일·청취 검사를 대신하지 않습니다. 소스 ZIP은 프로젝트 옆 `Cinder-artifacts`에
만들며 `--output`으로 다른 외부 폴더를 지정할 수 있습니다. ZIP의 최상단은 `Cinder/`이고,
체크섬을 함께 생성합니다. 캐시·빌드 결과·로컬 작업 자료는 포함하지 않습니다.

## 변경과 출시

현재 작업 브랜치는 `dev`입니다. 일반 push/PR은 소스만 검사하며,
기능이 모인 뒤 Actions → Build → Run workflow에서 staging 검증을 실행합니다.
`main`과 정식 태그는 출시 기준을 통과한 소스에 사용합니다.
[출시 운영](Docs/RELEASING.md)과 [ROADMAP.md](ROADMAP.md)를 참조하세요.

앱 식별자와 `Swinder` 설정 폴더를 유지하고, 실행이나 프리셋 적용만으로
재생·예약을 시작하지 않습니다. ChatGPT/Codex 커밋의 작성자와 공동 작성 표기는
[AUTHORS.md](AUTHORS.md)를 따릅니다.

Live Activities 도입 전 SDK 지원 여부는 `bash Check-LiveActivities.command`로
별도 확인합니다. 실제 기능 통합에는 `--require-supported` 검사를 사용하세요.
현재 macOS SDK의 제약과 기능 커밋 분리 범위는 [SDK 도입 안내](Docs/LIVE-ACTIVITIES.md)에 있습니다.

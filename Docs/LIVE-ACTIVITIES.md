# Live Activities SDK 도입 경계

ActivityKit·WidgetKit은 Xcode에 포함된 Apple 시스템 프레임워크입니다.
별도 Swift Package를 설치하거나 프레임워크를 저장소에 복사하지 않습니다.

## 현재 지원 범위

macOS 27 SDK에서 프레임워크를 가져오는 것은 가능하지만, Mac 앱의 Live Activities
생성·갱신·종료 API와 `ActivityConfiguration`은 macOS 사용 불가로 지정되어 있습니다.
Mac의 시스템 Live Activities 표시는 iPhone에서 전달받는 경로입니다.

- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Mac의 iPhone 알림·Live Activities](https://support.apple.com/en-us/120684)
- [Mac 앱 표시 방식에 대한 Apple DTS 안내](https://developer.apple.com/forums/thread/834361)

## SDK 확인

프로젝트에서 선택한 Xcode·SDK·배포 대상에 대해 다음을 실행합니다.
기존 `DEVELOPER_DIR`를 존중하며 전역 Xcode 선택은 바꾸지 않습니다.

```bash
bash Check-LiveActivities.command
bash Check-LiveActivities.command --require-supported
```

각 실행은 먼저 SDK 모듈을 가져올 수 있는지 확인하고, 이어서 실제 활동 수명 API와
화면 구성 API를 컴파일할 수 있는지 확인합니다. 진단 코드는 실행하지 않습니다.
결과·실행 환경·컴파일 로그는 `.build/live-activities-sdk/check.*/`에 남습니다.

| 상태 | 기본 종료 코드 | `--require-supported` 종료 코드 | 의미 |
|---|---:|---:|---|
| `compile-supported` | 0 | 0 | 컴파일 가능. 권한·시스템 표시·장시간 실행은 별도 검증 필요 |
| `unsupported` | 0 | 2 | SDK가 API를 macOS에서 사용할 수 없다고 명시 |
| `error` | 1 | 1 | 환경·모듈·기타 컴파일 오류. 지원 여부를 판정하지 않음 |

일반 검사에서 종료 코드 0은 조사가 정상 종료됐다는 뜻입니다. 실제 기능의
개발·통합 조건에는 `--require-supported`를 사용해야 합니다. `canImport(ActivityKit)`
만으로 기능을 활성화해서는 안 됩니다.

## 기능 커밋과 되돌리기

SDK 준비는 이 검사와 진단 소스·문서까지 포함합니다. 앱 타깃·오디오 엔진·설정·UI에는
의존성을 추가하지 않으며 기존 앱 빌드와 일반 dev CI에서도 이 선택적 검사를 실행하지 않습니다.
따라서 SDK 준비 커밋을 되돌려도 현재 재생 기능의 소스는 영향을 받지 않습니다.

실제 기능은 지원되는 플랫폼과 구현 경로를 정한 뒤 별도 커밋으로 추가합니다.
그 커밋에 상태 전달, 표시 확장, 필요한 권한·메타데이터, UI와 검사를 함께 포함합니다.
사용자 기능을 되돌릴 때는 기능 커밋부터 취소하고 SDK 준비 커밋은 유지할 수 있습니다.
둘 다 제거할 때는 기능 → SDK 준비 순서를 사용합니다. 이후 변경이 같은 파일에
겹치면 충돌 검토가 필요하므로 커밋 분리가 모든 revert의 무충돌을 보장하지는 않습니다.

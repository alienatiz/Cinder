# Cinder 1.0 개발 트리

프로젝트 루트의 Package.swift가 모듈과 리소스를 구성합니다. 소스·리소스·테스트 자료는 저장소 안에서 상대 경로로 찾습니다.

| 모듈 | 책임 |
|---|---|
| CinderApp | SwiftUI 화면, AppModel, 예약과 작업 수명, 사용자 동작 연결 |
| CinderCore | 세션·프리셋·테마·장르·시간·게인·예약 규칙 |
| CinderAudio | AVAudioEngine, 외부 음악·내장 프리셋 로딩과 변환, PCM 소유권 전달 |
| CinderDSP | C11 렌더 콜백, 고정 버퍼, 게인·페이드·미터 집계 |
| CinderPlatform | Core Audio 장치 조회·변경 감시, 모델 정보와 잠자기 방지, 메인 루프 타이머 |
| CinderStorage | 설정·프리셋·테마의 JSON/YAML 저장과 리소스 탐색 |

음악 준비는 렌더 콜백 밖에서 수행하고 취소 여부를 확인합니다. 준비된 PCM은 C 엔진으로 소유권을 이전합니다. 재생 콜백에서는 음원 생성·파일 접근·동적 할당을 하지 않습니다. 일시정지 페이드가 완료되면 엔진을 멈추며, 미터는 화면 갱신 사이의 오디오 블록을 집계합니다.

Tests/CinderCoreTests에는 Core·저장·예약·노이즈·음원 로딩 검사가 있으며 Fixtures 경로는 테스트 소스 위치를 기준으로 찾습니다. SwiftPM이 Sources/CinderApp/Resources의 JSON·이미지·FLAC를 번들에 포함합니다. 앱 생성 스크립트는 번들 배치와 프리셋 해시를 검사합니다.

일반 개발에는 프로젝트와 Xcode만 사용합니다. Tools의 Python 스크립트는 소스 검증·아카이브 제작 및 선택적인 오프라인 음원 재생성용입니다. 이미 생성된 FLAC를 앱에서 사용하는 데에는 Python·FluidSynth·SoundFont가 필요하지 않습니다.

실시간 장치 출력·메모리·에너지는 자동 신호 검사와 별도로 Mac에서 확인합니다. 현재 검증 범위는 [VALIDATION.md](../VALIDATION.md)에 있습니다.

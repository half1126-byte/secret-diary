# 비밀 일기 ✍️

**손으로 쓰는 비밀 일기장 — AI가 읽고, 기억하고, 답장해주는 감성 다이어리 앱**

패드나 펜슬(Apple Pencil, S펜), 또는 손가락으로 일기를 쓰면
AI가 손글씨를 읽고 따뜻한 친구처럼 답장해줍니다.
아이디어도, 고민도, 나눈 대화도 모두 기록되어 언제든 이어서 이야기할 수 있어요.

## 특징

- 🖋️ **진짜 잉크 감성** — 필압에 따라 굵기가 변하는 만년필 느낌의 손글씨 캔버스
- 🌏 **전 세계 언어 지원** — 한국어·영어·일본어·중국어·아랍어 등 20개+ 언어의 손글씨 인식
- 🤖 **AI 답장·상담** — 공감하며 들어주는 일기 친구. 과거 일기를 기억하고, 쓴 언어 그대로 답장
- 🔒 **프라이버시 우선** — 모든 일기·대화는 **기기 안에만** 저장. 손글씨 인식도 기기 안에서(온디바이스)
- 💸 **완전 무료** — 유료 API 없음. 손글씨 인식은 Google ML Kit(무료·온디바이스),
  AI 답장은 Gemini API **무료 등급**으로 동작
- 🎨 **감성 디자인** — 종이 질감, 언어별 무료 손글씨 폰트(나눔펜스크립트, Caveat 등), 잉크가 스며드는 애니메이션

## 실행 방법

Flutter가 설치되어 있어야 합니다. ([설치 안내](https://docs.flutter.dev/get-started/install))

```bash
flutter pub get
dart run build_runner build          # drift DB 코드 생성
flutter run                          # 연결된 기기/에뮬레이터에서 실행
```

- **Android**: minSdk 24 (Android 7.0) 이상
- **iOS**: iOS 15.5 이상 (ML Kit 요구사항 — `ios/` 에서 `pod install` 필요)
- 손글씨 인식(ML Kit)은 **실기기에서만** 동작합니다. 에뮬레이터에서도 UI는 확인 가능해요.

### 💻 PC에서 미리 보기 (Windows/Linux 데스크톱)

폰 없이 디자인·UI·흐름을 확인할 수 있습니다. 마우스로 손글씨를 쓸 수 있고,
손글씨 인식만 가짜 인식기로 대체됩니다 (AI 답장은 키가 있으면 실제로 동작).

```bash
# Windows: Flutter SDK + Visual Studio(C++ 데스크톱 개발 워크로드) 설치 후
flutter run -d windows

# Linux: clang/cmake/ninja/libgtk-3-dev/libsecret-1-dev 설치 후
flutter run -d linux
```

## AI 답장 연결하기 (무료, 1분)

1. [aistudio.google.com/apikey](https://aistudio.google.com/apikey) 접속 → 구글 계정 로그인
2. **"API 키 만들기"** 클릭 → 키 복사 (결제 정보 필요 없음)
3. 앱의 **설정 → AI 답장** 에 붙여넣고 저장 → "연결 테스트"

키가 없어도 손글씨 인식과 일기 저장은 모두 동작합니다.
무료 등급으로 하루 수백 번의 답장을 받을 수 있어요.

## 처음 사용할 때

1. 홈에서 **"오늘 일기 쓰기"** 를 누르면 선택한 언어의 손글씨 모델(~20MB)을 한 번 내려받아요 (이후 오프라인 인식).
2. 캔버스에 마음껏 쓰면 잠시 후 아래에 인식된 글자가 나타나요. 틀렸다면 탭해서 고칠 수 있어요.
3. ✉️ 보내기를 누르면 손글씨 원본 그대로 저장되고, AI의 답장이 도착해요.
4. 언어는 쓰기 화면 상단의 언어 칩에서 언제든 바꿀 수 있어요.

## 프라이버시

- 일기·손글씨·대화는 전부 기기 내 로컬 DB(SQLite)에만 저장됩니다. 서버가 없어요.
- 손글씨 → 텍스트 변환은 100% 기기 안에서 이루어집니다 (Google ML Kit Digital Ink, 온디바이스).
- AI 답장을 요청할 때만 해당 일기 텍스트가 Google Gemini API로 전송됩니다.
  API 키는 기기의 보안 저장소(Keychain/Keystore)에 보관됩니다.

## 기술 스택

| 영역 | 선택 |
|---|---|
| 프레임워크 | Flutter (iOS + Android) |
| 손글씨 렌더링 | perfect_freehand (필압 기반 가변 굵기 잉크) |
| 손글씨 인식 | Google ML Kit Digital Ink Recognition (온디바이스, 무료) |
| AI 대화 | Gemini API 무료 등급 (REST 직접 호출) |
| 로컬 DB | drift (SQLite) |
| 상태 관리 | Riverpod |
| 폰트 | google_fonts — 언어별 무료 손글씨 폰트 |

## 개발

```bash
flutter analyze        # 정적 분석
flutter test           # 단위·위젯 테스트 (30건)
dart run build_runner build --delete-conflicting-outputs   # DB 스키마 변경 시
```

### 프로젝트 구조

```
lib/
  core/        테마(팔레트·손글씨 폰트 매핑)와 공용 위젯(종이 질감 등)
  data/        획(stroke) 모델, drift DB, 리포지토리
  services/    손글씨 인식(ML Kit + 테스트용 Fake), Gemini 클라이언트·프롬프트
  features/    홈 타임라인, 쓰기(캔버스·대화 스레드), 설정
```

## 앞으로 추가하고 싶은 것

- 앱 잠금 (생체인증/PIN)
- 일기 검색, 무드 트래킹
- PDF/이미지 내보내기
- 온디바이스 AI 모드 (완전 오프라인 답장)

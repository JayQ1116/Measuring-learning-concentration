# 📱 LensFocus AI — 프론트엔드 (Flutter)

> * 학습 집중도 관리 시스템**  
> 학생의 학습 집중도를 실시간으로 모니터링하고, AI 도우미를 통해 학습을 지원하는 모바일 앱

---

## 목차 

- [프로젝트 개요](#프로젝트-개요)
- [주요 기능](#주요-기능)
- [기술 스택](#기술-스택)
- [프로젝트 구조](#프로젝트-구조)
- [설치 및 실행](#설치-및-실행)
- [환경 설정](#환경-설정)
- [API 인터페이스 명세](#api-인터페이스-명세)
- [화면 구성](#화면-구성)

---

## 프로젝트 개요

LensFocus AI는 Flutter 기반의 모바일 앱으로, 학생이 PDF 강의 자료를 학습하는 동안:

- **전면 카메라**로 얼굴을 감지하여 집중도를 실시간 측정
- **AI 모델**(35MB 경량 모델)로 눈, 입, 머리 자세를 분석
- 집중도 저하 시 **AI 기포 알림**으로 강제 개입
- **Gemini AI**로 PDF 페이지 기반 질의응답 제공
- **Firebase**로 학습 데이터 클라우드 저장 및 교사 대시보드 연동

---

## 주요 기능

### 학생 앱
| 기능 | 설명 |
|------|------|
| 🔐 회원가입 / 로그인 | Firebase Auth 기반 이메일 인증 |
| 📄 PDF 학습 | PDF 파일 불러오기 및 페이지 탐색 |
| 👁️ 집중도 모니터링 | 전면 카메라 + 로컬 AI 모델 실시간 추론 |
| 🤖 AI 개입 알림 | 집중도 60% 미만 시 자동 팝업 |
| 💬 Gemini 문답 | 현재 페이지 컨텍스트 기반 AI 질의응답 |
| ☁️ 데이터 업로드 | 집중도 로그 Firebase 자동 저장 |

### 교사 앱
| 기능 | 설명 |
|------|------|
| 📊 실시간 모니터링 | 전체 학생 집중도 실시간 조회 |
| 📈 학습 리포트 | 집중도 추이 차트 및 분석 |
| 🚨 주의 학생 알림 | 집중도 저하 학생 목록 표시 |

---

## 기술 스택

```
Flutter 3.x (Dart)
├── Firebase Auth         - 인증
├── Cloud Firestore       - 데이터베이스
├── camera                - 전면 카메라 제어
├── flutter_pdfview       - PDF 렌더링
├── google_generative_ai  - Gemini 2.0 Flash API
├── percent_indicator     - 집중도 링 UI
├── file_picker           - PDF 파일 선택
├── permission_handler    - 카메라 권한 관리
├── http                  - Flask 추론 서버 통신
└── fl_chart              - 차트 시각화
```

---

## 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점, Firebase 초기화
├── app_theme.dart               # 전역 테마 설정
├── firebase_options.dart        # Firebase 플랫폼 설정 (자동 생성)
├── database_helper.dart         # (레거시, 미사용)
│
├── pages/
│   ├── login_page.dart          # 로그인 / 회원가입 페이지
│   ├── dashboard_page.dart      # 학생 메인 대시보드
│   ├── course_list_page.dart    # 강의 목록 페이지
│   ├── learning_page.dart       # ⭐ 핵심: PDF 학습 + 카메라 + Gemini
│   ├── report_page.dart         # 학습 결과 리포트
│   ├── environment_page.dart    # 환경 설정 페이지
│   ├── teacher_page.dart        # 교사 메인 페이지
│   ├── teacher_dashboard_page.dart  # 교사 대시보드
│   └── teacher_monitoring_page.dart # 실시간 모니터링
│
└── service/
    └── firebase_service.dart    # Firebase 데이터 서비스 레이어
```

---

## 설치 및 실행

### 요구사항

```
Flutter SDK >= 3.0.0
Dart SDK >= 3.0.0
Xcode >= 14 (iOS 빌드)
iOS 13.0+
```

### 설치

```bash
# 1. 저장소 클론
git clone https://github.com/Fa1tumn/Measuring-learning-concentration.git
cd Measuring-learning-concentration

# 2. 패키지 설치
flutter pub get

# 3. iOS Pod 설치
cd ios && pod install && cd ..

# 4. 실행
flutter run
```

---

## 환경 설정

### 1. Firebase 설정

`ios/Runner/GoogleService-Info.plist` 파일이 필요합니다.  
Firebase 콘솔에서 iOS 앱을 추가하고 다운로드하세요.

```
Firebase 콘솔 → 프로젝트 설정 → 앱 추가(iOS) → plist 다운로드
```

### 2. Gemini API Key

`lib/pages/learning_page.dart` 상단에서 설정:

```dart
const String _kGeminiApiKey = 'YOUR_GEMINI_API_KEY';
```

Google AI Studio에서 발급:  
👉 https://aistudio.google.com/apikey

### 3. Flask 추론 서버 주소

같은 Wi-Fi 네트워크에서 Mac의 IP 주소로 설정:

```dart
const String _kFlaskBaseUrl = 'http://192.168.x.x:5001';
```

Mac IP 확인:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### 4. iOS 권한 설정

`ios/Runner/Info.plist`에 추가 필요:

```xml
<key>NSCameraUsageDescription</key>
<string>학습 집중도 모니터링을 위해 카메라를 사용합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>카메라 사용을 위해 필요합니다</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>PDF 파일 선택을 위해 사용합니다</string>
```

---

## API 인터페이스 명세

### Firebase Firestore 컬렉션

#### `/users/{uid}`
| 필드 | 타입 | 설명 |
|------|------|------|
| uid | String | 사용자 고유 ID |
| name | String | 이름 |
| email | String | 이메일 |
| role | String | `"Student"` 또는 `"Teacher"` |
| classId | String | 학급 ID |
| createdAt | Timestamp | 가입 일시 |

#### `/sessions/{sessionId}`
| 필드 | 타입 | 설명 |
|------|------|------|
| studentUid | String | 학생 UID |
| pdfName | String | 학습 중인 PDF 파일명 |
| startTime | Timestamp | 학습 시작 시간 |
| endTime | Timestamp | 학습 종료 시간 |
| totalFocusedSeconds | int | 집중 시간 (초) |
| totalConfusedSeconds | int | 비집중 시간 (초) |

#### `/concentrationLogs/{logId}`
| 필드 | 타입 | 설명 |
|------|------|------|
| studentUid | String | 학생 UID |
| sessionId | String | 세션 ID |
| timestamp | Timestamp | 측정 시각 |
| state | String | `"focused"` 또는 `"confused"` |
| confidence | double | 집중도 점수 (0.0 ~ 1.0) |

#### `/studentLiveState/{studentUid}`
| 필드 | 타입 | 설명 |
|------|------|------|
| studentUid | String | 학생 UID |
| state | String | 현재 상태 |
| confidence | double | 현재 집중도 점수 |
| updatedAt | Timestamp | 마지막 업데이트 시각 |

#### `/pdfProgress/{progressId}`
| 필드 | 타입 | 설명 |
|------|------|------|
| studentUid | String | 학생 UID |
| pdfName | String | PDF 파일명 |
| currentPage | int | 현재 페이지 |
| totalPages | int | 전체 페이지 수 |
| lastReadAt | Timestamp | 마지막 열람 시각 |

---

### Flask 추론 서버 API

#### `GET /`
서버 상태 확인

#### `POST /infer`
집중도 추론 요청

**Request:**
```json
{
  "image": "base64_encoded_jpeg",
  "page": 1
}
```

**Response:**
```json
{
  "focus_score": 0.85,
  "state": "focused"
}
```

| `state` 값 | 설명 |
|------------|------|
| `focused` | 집중 상태 (score >= 0.6) |
| `confused` | 비집중 상태 (score < 0.6) |
| `absent` | 얼굴 미감지 |

---

## 화면 구성

```
로그인/회원가입
    ↓
학생 대시보드
    ↓
강의 목록
    ↓
학습 페이지 (핵심)
    ├── PDF 뷰어 (전체 화면)
    ├── 집중도 링 (우상단 플로팅)
    ├── 카메라 상태 표시 (AppBar)
    ├── AI 개입 기포 (집중도 저하 시)
    └── Gemini 문답 시트 (하단 팝업)
        ↓
학습 결과 리포트
```

---

## 주요 플로우

### 집중도 모니터링 플로우

```
앱 실행
  → 카메라 권한 요청
  → 전면 카메라 초기화 (백그라운드, UI 미표시)
  → Flask 서버 연결 확인
  → 5초마다:
      카메라 촬영 → base64 인코딩
      → Flask /infer 전송
      → focus_score 수신
      → UI 업데이트 + Firebase 업로드
      → score < 0.6 이면 AI 기포 표시
```

### Gemini 문답 플로우

```
[AI 질문] 버튼 클릭
  → 하단 시트 오픈
  → 사용자 질문 입력
  → [현재 PDF명 + 페이지 번호] + 질문 → Gemini API
  → 응답 표시
```

---

## 개발자 정보

| 이름 | 역할 |
|------|------|
| Fa1tumn (GYULIM SHIN) | 프론트엔드 리드 |
| Nago625 | 백엔드 / AI 모델 |
| kyuhyuk0924 | 백엔드 |
| JayQ1116 | 데이터 / 리포트 |

---

*LensFocus AI — 2025*
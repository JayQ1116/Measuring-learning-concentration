# 학습 집중도 시스템 Dry Run 보고서

## 1. 프로젝트 목적
본 보고서는 Python Dry Run을 기반으로 학습 집중도 시스템의 학생 측부터 교사 측까지 이어지는 전체 업무 폐쇄루프를 검증한다. 이 버전은 실제 AI 모델이나 카메라 입력에 의존하지 않고, 실행 가능한 모의 구현을 통해 실제 시스템의 데이터 흐름, 판단 로직, 피드백 메커니즘을 재현한다.

## 2. 검증 범위
Dry Run은 다음 두 영역을 포함한다.

1. 학생 측 흐름: 영상 프레임 수집, 집중도 추론, 슬라이딩 윈도우 평활화, 상태 판정, AI 개입, 데이터 업로드
2. 교사 측 흐름: 학생 데이터 수신, 상태 분석, 페이지별 히트맵 집계, 위험 학생 탐지, 대시보드 표시

## 3. 시스템 전체 흐름

### 3.1 학생 측
1. 5초 영상 프레임 수집(30fps, 총 150프레임)
2. ViT 추론 결과를 프레임 단위로 모의 생성(점수 및 라벨)
3. 5초 윈도우 기반 슬라이딩 평균으로 집중도 안정화
4. 임계값 기준으로 Focused / Slightly Distracted / Distracted 분류
5. Focused가 아닌 경우 RAG+LLM 학습 피드백 생성
6. 학생 UI 출력 후 교사 측으로 데이터 전송

### 3.2 교사 측
1. 학생 측 업로드 JSON 데이터 수신
2. 학생별 집중 상태 재분류
3. PDF 페이지 기준 평균 집중도 집계 및 히트맵 색상 생성
4. 저집중 위험 학생 목록 탐지
5. 교사 대시보드에 반 전체 학습 상태 출력

## 4. 핵심 구현 로직

### 4.1 임계값 규칙
- Focused: score > 0.7
- Slightly Distracted: 0.4 < score <= 0.7
- Distracted: score <= 0.4

### 4.2 슬라이딩 윈도우 평활화
- 최근 window_size 프레임 점수 평균을 사용하여 단기 노이즈를 완화한다.
- 본 실험의 window_size는 5초 x 30fps = 150이다.

### 4.3 교사 측 히트맵 생성
- 동일 page의 학생 score를 평균한다.
- 평균 점수에 따라 색상을 매핑한다.
  - Green: avg > 0.7
  - Yellow: 0.4 < avg <= 0.7
  - Red: avg <= 0.4

### 4.4 위험 학생 탐지
- score <= 0.4인 학생을 경고 대상자로 분류한다.

## 5. Dry Run 입력 및 파라미터

### 5.1 학생 측 파라미터
- fps = 30
- duration_seconds = 5
- window_seconds = 5
- random_seed = 42
- student_id = A01
- rag_page = PDF_page_10

### 5.2 교사 측 모의 데이터 구성
- 학생 측 실제 업로드 1건(A01)
- 같은 페이지, 같은 시점의 동료 학생 데이터 2건(A02, A03)을 결합하여 반 단위 분석 수행

## 6. 실행 결과(실측)
다음 결과는 현재 코드 실행 출력에서 가져온 내용이다.

```text
=== Learning Concentration System Dry Run ===
Focus Score: 0.64
State: Slightly Distracted
AI Feedback: [AI 튜터] 현재 PDF_page_10 내용의 핵심 요약: 핵심 개념에 유의하고, 먼저 정의를 다시 설명한 후 문제를 풀어보세요.
Send to teacher: {'student_id': 'A01', 'page': 10, 'focus_score': 0.64, 'state': 'Slightly Distracted'}

=== Teacher Dashboard ===

[Student Status]
{'student_id': 'A01', 'page': 10, 'score': 0.64, 'state': 'Slightly Distracted'}
{'student_id': 'A02', 'page': 10, 'score': 0.82, 'state': 'Focused'}
{'student_id': 'A03', 'page': 10, 'score': 0.45, 'state': 'Slightly Distracted'}

[Heatmap]
Page 10: {'avg_score': 0.64, 'color': 'Yellow'}

[Warning Students]
[]
```

## 7. 결과 분석
1. 학생 측 점수 0.64는 Slightly Distracted로 판정되며 AI 학습 피드백이 정상 트리거되었다.
2. 교사 측은 학생 업로드를 정상 수신하고 반 단위 집계 분석을 수행했다.
3. 페이지 10 평균 집중도는 0.64로 Yellow 등급이며, 해당 페이지에 일정 수준의 학습 부담이 있음을 시사한다.
4. Warning Students가 빈 목록이므로 score <= 0.4 조건의 고위험 학생은 없었다.

## 8. 폐쇄루프 검증 결론
본 Dry Run은 시스템의 엔드투엔드 폐쇄루프 동작을 검증했다.

1. 입력 계층: 학생 측 영상 프레임 유입
2. 추론 계층: 모델 점수 산출 및 시간 평활화
3. 의사결정 계층: 상태 판정 및 AI 개입 트리거
4. 동기화 계층: 학생 결과 교사 측 업로드
5. 관리 계층: 교사 측 시각화, 위험 탐지, 수업 지원

결론적으로, 본 Python Dry Run은 시스템 흐름의 완결성, 모듈 간 연계성, 보고서 및 시연 목적의 활용성을 충분히 입증한다.

## 9. 향후 확장 방향
1. 학생 측 OpenCV 실시간 카메라 입력 연동
2. Torch 기반 모델 스텁 및 실제 가중치 인터페이스 연결
3. 교사 측 시계열 추세 분석 및 난이도 페이지 자동 마킹
4. matplotlib 또는 웹 대시보드 기반 시각화 고도화

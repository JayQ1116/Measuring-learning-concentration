from __future__ import annotations
import cv2
import time
import random
from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple

# --- 1. 配置与数据结构 ---
@dataclass
class PipelineConfig:
    fps: int = 30
    window_seconds: int = 5              # 滑动窗口时长
    focused_threshold: float = 0.7       # 专注阈值
    slight_distracted_threshold: float = 0.4
    student_id: str = "GAO_LUO_01"       # 唯一学生标识
    rag_page: str = "PDF_Page_10"        # 当前阅读页码
    sync_interval: int = 2               # 同步频率（秒）

# --- 2. 学生端模块 (Student Side) ---

def get_vit_prediction(frame) -> Tuple[float, str]:
    """[Module A] 视觉感知：此处对接真实的 ViT 推理接口"""
    # 模拟真实环境下模型对当前帧的实时置信度输出
    score = random.uniform(0.1, 0.95) 
    label = "Focused" if score > 0.6 else "Distracted"
    return score, label

def sliding_window_smooth(history: List[Tuple[float, str]], window_size: int) -> float:
    """[Module B] 滑动窗口：对实时流进行去噪平滑"""
    if not history: return 0.0
    recent = history[-window_size:]
    scores = [s for s, l in recent]
    return sum(scores) / len(scores)

def classify_state(score: float, config: PipelineConfig) -> str:
    """状态分类逻辑"""
    if score > config.focused_threshold:
        return "Focused"
    if score > config.slight_distracted_threshold:
        return "Slightly Distracted"
    return "Distracted"

def rag_llm_feedback(page: str) -> str:
    """[Module C] RAG + LLM：基于当前页内容的生成式干预"""
    return f"[AI 튜터] {page} 요약: 몰입도가 낮아졌습니다. 핵심 개념을 다시 요약해 드릴까요?"

# --- 3. 教师端模块 (Teacher Side - 纯真实数据驱动) ---

# 模拟服务器端的全局存储（在全栈中这通常是 Redis 或 Database）
global_class_data = {} 

def update_server_state(payload: Dict[str, object]):
    """模拟后端接收 API 请求并更新全局状态"""
    student_id = payload["student_id"]
    global_class_data[student_id] = payload

def generate_teacher_report(config: PipelineConfig):
    """教师端核心分析：仅基于 global_class_data 中的真实在线学生"""
    if not global_class_data:
        print("\n[Teacher Dashboard] 대기 중... 접속한 학생이 없습니다.")
        return

    page_summary = defaultdict(list)
    at_risk_students = []

    print("\n" + "="*45)
    print(f"   [TEACHER REAL-TIME DASHBOARD]")
    print(f"   현재 접속 학생 수: {len(global_class_data)}명")
    
    for s_id, data in global_class_data.items():
        score = data["focus_score"]
        page = data["page"]
        state = classify_state(score, config)
        
        # 实时风险监测
        if score <= config.slight_distracted_threshold:
            at_risk_students.append(f"{s_id}({state})")
        
        page_summary[page].append(score)
        print(f"   - 학생[{s_id}]: 점수 {score:.2f} | 상태 {state}")

    # 动态热力图计算
    print(f"\n   [페이지별 히트맵 분석]")
    for page, scores in page_summary.items():
        avg = sum(scores) / len(scores)
        color = "Green(수월)" if avg > config.focused_threshold else ("Yellow(보통)" if avg > config.slight_distracted_threshold else "Red(어려움)")
        print(f"     Page {page}: 평균 {avg:.2f} -> 상태: {color}")

    if at_risk_students:
        print(f"\n   ⚠️ 집중도 저하 학생: {at_risk_students}")
    print("="*45)

# --- 4. 主程序：全链路实时循环 ---

def main():
    config = PipelineConfig()
    cap = cv2.VideoCapture(0)
    
    window_size = config.window_seconds * config.fps
    predictions_history = []
    last_sync_time = time.time()

    print(f"시스템 초기화 완료. 학생 ID: {config.student_id}")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        # 1. 实时感知 (Module A)
        score, label = get_vit_prediction(frame)
        predictions_history.append((score, label))
        if len(predictions_history) > window_size:
            predictions_history.pop(0)

        # 2. 数据平滑 (Module B)
        smooth_score = sliding_window_smooth(predictions_history, window_size)
        state = classify_state(smooth_score, config)

        # 3. 学生端 UI 表现
        ui_color = (0, 255, 0) if state == "Focused" else ((0, 255, 255) if state == "Slightly Distracted" else (0, 0, 255))
        
        cv2.rectangle(frame, (15, 15), (420, 140), (0, 0, 0), -1)
        cv2.putText(frame, f"REAL-TIME MONITOR: {config.student_id}", (30, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
        cv2.putText(frame, f"SCORE: {smooth_score:.2f}", (30, 85), cv2.FONT_HERSHEY_SIMPLEX, 1, ui_color, 2)
        cv2.putText(frame, f"STATE: {state}", (30, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, ui_color, 2)
        
        if state == "Distracted":
            cv2.putText(frame, "AI HELP ACTIVE", (30, 170), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 150, 0), 2)

        cv2.imshow('Student Interface', frame)

        # 4. 真实同步逻辑 (Module B -> Module C / Teacher)
        # 只有到达同步间隔时，才将“我”的数据发给“服务器”并触发教师端更新
        if time.time() - last_sync_time > config.sync_interval:
            my_payload = {
                "student_id": config.student_id,
                "page": 10,
                "focus_score": smooth_score,
                "timestamp": time.time()
            }
            # 更新全局状态（模拟真实数据库写入）
            update_server_state(my_payload)
            # 触发教师端分析逻辑
            generate_teacher_report(config)
            last_sync_time = time.time()

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()

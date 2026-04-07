from dataclasses import dataclass


@dataclass
class PipelineConfig:
    fps: int = 30
    duration_seconds: int = 5
    window_seconds: int = 5
    focused_threshold: float = 0.7
    slight_distracted_threshold: float = 0.4
    student_id: str = "A01"
    rag_page: str = "PDF_page_10"
    random_seed: int = 42
    sync_interval: int = 2
    camera_index: int = 0
    current_page: int = 10
    ui_window_name: str = "Student Interface"
    quit_key: str = "q"

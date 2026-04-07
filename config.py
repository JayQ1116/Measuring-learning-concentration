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
    ask_llm_key: str = "a"
    next_page_key: str = "n"
    prev_page_key: str = "p"
    toggle_window_key: str = "m"
    toggle_topmost_key: str = "t"
    pdf_path: str ="assets/pdf/lesson1.pdf"
    pdf_window_name: str = "Courseware PDF"
    compact_width: int = 520
    compact_height: int = 300
    maximized_width: int = 1280
    maximized_height: int = 720
    student_window_topmost: bool = True
    confusion_high_threshold: int = 2

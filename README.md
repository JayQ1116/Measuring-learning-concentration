# Measuring-learning-concentration

Language: [中文文档](README_zh.md)

Realtime learning concentration dry run project.

Dataset link:
https://drive.google.com/file/d/1yrk_wyhZ-c7q0Mcyyi888ylFkl_JDELi/view

## Quick Start

1. Create and activate virtual environment.
2. Install dependencies:

```bash
pip install opencv-python
```

3. Run:

```bash
python dryrun.py
```

Quit realtime window with key `q`.

### Runtime Hotkeys

- `a`: Ask LLM anytime (type question in terminal)
- `n`: Next PDF page
- `p`: Previous PDF page
- `m`: Toggle student camera window compact/maximized
- `t`: Toggle student camera window topmost (floating)
- `q`: Quit

## Project Structure And File Summary

### Root files

- `dryrun.py`
	- Project entrypoint.
	- Builds `PipelineConfig` and starts realtime pipeline via `run_realtime_pipeline`.

- `README.md`
	- This documentation file.
	- Includes run instructions and file/function overview.

- `DryRun_Report.md`
	- Earlier dry run analysis/report document.
	- Contains project goals, flow, and expected results narrative.

### Core package

- `src/mlc/config.py`
	- Defines `PipelineConfig` dataclass.
	- Centralizes runtime parameters such as `fps`, `window_seconds`, thresholds, camera index, sync interval, window name, and quit key.

- `src/mlc/__init__.py`
	- Public package exports.
	- Exposes `PipelineConfig`, `run_realtime_pipeline`, and `run_student_camera_loop`.

### Realtime orchestration

- `src/mlc/realtime/pipeline.py`
	- Main orchestration logic for the realtime loop.
	- Function `run_student_camera_loop(config)`:
		- Opens camera.
		- Reads frames continuously.
		- Calls ViT stub inference.
		- Applies sliding-window smoothing.
		- Classifies concentration state.
		- Draws and displays UI.
		- Builds and uploads payload at sync interval.
		- Triggers teacher dashboard report.
	- Function `run_realtime_pipeline(config=None)`:
		- Creates default config when needed.
		- Calls `run_student_camera_loop`.

- `src/mlc/realtime/__init__.py`
	- Realtime layer exports.
	- Exposes pipeline runner, model stub accessor, and teacher dashboard state/update APIs.

### Input module (camera)

- `src/mlc/realtime/input/camera_input.py`
	- Camera I/O utilities.
	- `open_camera(camera_index)`: opens camera and validates availability.
	- `read_camera_frame(cap)`: reads one frame.
	- `close_camera(cap)`: releases camera and destroys OpenCV windows.

- `src/mlc/realtime/input/__init__.py`
	- Export surface for camera input module.

### Model module (ViT + scoring)

- `src/mlc/realtime/model/vit_inference.py`
	- ViT inference stub.
	- `get_vit_prediction(frame)`: currently returns simulated `(score, label)`.

- `src/mlc/realtime/model/scoring.py`
	- Concentration scoring logic.
	- `classify_state(score, config)`: maps score to `Focused`, `Slightly Distracted`, or `Distracted`.
	- `sliding_window(scores_history, window_size)`: computes smoothed score using latest history.

- `src/mlc/realtime/model/__init__.py`
	- Export surface for model module.

### Output module (UI + data payload)

- `src/mlc/realtime/output/ui_output.py`
	- Student-side OpenCV overlay rendering.
	- `draw_student_ui(...)`: draws score and state panel.
	- `show_student_ui(window_name, frame)`: displays the frame.
	- `should_quit(quit_key)`: checks if quit key is pressed.

- `src/mlc/realtime/output/data_output.py`
	- Payload builder for teacher-side sync.
	- `build_teacher_payload(config, smooth_score)`: builds structured data with student id, page, score, timestamp.

- `src/mlc/realtime/output/__init__.py`
	- Export surface for output module.

### Teacher module

- `src/mlc/realtime/teacher/dashboard.py`
	- In-memory teacher-side state and report logic.
	- `GLOBAL_CLASS_DATA`: simulated server-side student data store.
	- `update_server_state(payload)`: updates one student's latest state.
	- `generate_teacher_report(config)`: prints connected students, per-page average, heatmap color, and warning students.

- `src/mlc/realtime/teacher/__init__.py`
	- Export surface for teacher module.

## Current Runtime Flow

1. `dryrun.py` creates config and starts realtime loop.
2. Camera module captures frames.
3. ViT stub module outputs raw score.
4. Scoring module smooths and classifies concentration state.
5. Output module renders student UI and creates payload.
6. Teacher module updates server state and prints dashboard report periodically.

## Notes

- `vit_inference.py` is currently a stub and is the main replacement point for a real model.
- Teacher data store is in-memory (`GLOBAL_CLASS_DATA`) and should be replaced by DB/Redis/API in production.

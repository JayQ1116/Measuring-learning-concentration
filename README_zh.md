# Measuring-learning-concentration 中文说明

语言: [English README](README.md)

这是一个基于摄像头实时采集的学习专注度 Dry Run 项目。

数据集链接：
https://drive.google.com/file/d/1yrk_wyhZ-c7q0Mcyyi888ylFkl_JDELi/view

## 1. 快速开始

1. 创建并激活虚拟环境（可选，但推荐）。
2. 安装依赖：

```bash
pip install opencv-python
pip install pymupdf
```

3. 启动项目：

```bash
python dryrun.py
```

默认 PDF 路径是 `assets/pdf/courseware.pdf`。

4. 按 `q` 键退出实时窗口。

### 运行时快捷键

- `a`: 学生可随时提问 LLM（在终端输入问题）
- `n`: PDF 下一页
- `p`: PDF 上一页
- `m`: 学生摄像头窗口在紧凑/放大之间切换
- `t`: 学生摄像头窗口置顶开关（浮窗效果）
- `q`: 退出

## 2. 项目结构与文件功能说明

### 根目录文件

- dryrun.py
  - 项目入口文件。
  - 创建 PipelineConfig 并调用 run_realtime_pipeline 启动实时流程。
  - 设置默认 `pdf_path`。

- README.md
  - 英文说明文档。

- README_zh.md
  - 中文说明文档（本文件）。

- DryRun_Report.md
  - Dry Run 报告文档，记录了项目目标、流程、结果分析与扩展方向。

### 核心配置层

- src/mlc/config.py
  - 定义 PipelineConfig 配置类。
  - 管理阈值、摄像头参数、PDF 路径/窗口、快捷键、教师端统计阈值等运行参数。

- src/mlc/__init__.py
  - 包的对外导出入口。
  - 导出 PipelineConfig、run_realtime_pipeline、run_student_camera_loop。

### 实时流程编排层

- src/mlc/realtime/pipeline.py
  - 实时主流程编排文件。
  - run_student_camera_loop(config)：
    - 打开摄像头并循环读取帧。
    - 调用模型推理获得分数。
    - 执行滑动窗口平滑。
    - 进行状态分类。
    - 绘制并显示摄像头 UI 与 PDF 课件窗口。
    - 处理运行时按键（LLM 提问、翻页、窗口切换、置顶切换）。
    - 按同步间隔构建并上传数据到教师端状态。
    - 触发教师端实时报告（含低专注页和高疑惑页）。
  - run_realtime_pipeline(config=None)：
    - 若无配置则使用默认配置。
    - 调用 run_student_camera_loop 运行完整实时流程。

- src/mlc/realtime/__init__.py
  - realtime 子包的导出入口。
  - 导出实时流程函数、模型推理函数、教师端状态与报告函数。

### 输入模块（摄像头）

- src/mlc/realtime/input/camera_input.py
  - 摄像头输入相关函数。
  - open_camera(camera_index)：打开并校验摄像头。
  - read_camera_frame(cap)：读取一帧图像。
  - close_camera(cap)：释放摄像头并关闭 OpenCV 窗口。

- src/mlc/realtime/input/__init__.py
  - input 模块导出。

### 模型模块（ViT + 评分）

- src/mlc/realtime/model/vit_inference.py
  - ViT 推理桩代码。
  - get_vit_prediction(frame)：当前返回模拟 score + label，后续可替换为真实模型推理。

- src/mlc/realtime/model/scoring.py
  - 评分与状态逻辑。
  - classify_state(score, config)：将分数映射为 Focused / Slightly Distracted / Distracted。
  - sliding_window(scores_history, window_size)：对历史分数做滑动窗口平均，减小抖动。

- src/mlc/realtime/model/__init__.py
  - model 模块导出。

### 助手模块（LLM 问答）

- src/mlc/realtime/assistant/llm_assistant.py
  - 软件内 LLM 助手桩实现。
  - ask_learning_llm(question, page, state)：返回学习辅导回复。

- src/mlc/realtime/assistant/__init__.py
  - assistant 模块导出。

### 课件模块（PDF 查看器）

- src/mlc/realtime/courseware/pdf_viewer.py
  - 基于 PyMuPDF + OpenCV 的软件内 PDF 查看器。
  - PdfCoursewareViewer 支持当前页渲染、上一页/下一页、窗口显示。
  - PDF 加载失败时显示回退提示信息。

- src/mlc/realtime/courseware/__init__.py
  - courseware 模块导出。

### 输出模块（UI + 数据输出）

- src/mlc/realtime/output/ui_output.py
  - 学生端 UI 绘制与显示。
  - draw_student_ui(...)：绘制分数、状态、提示信息。
  - init_student_window(...)：初始化学生窗口。
  - set_student_window_mode(...)：切换紧凑/放大窗口模式。
  - set_student_window_topmost(...)：切换窗口置顶（浮窗风格）。
  - read_key()：读取 OpenCV 事件循环中的按键输入。
  - show_student_ui(window_name, frame)：显示当前帧。

- src/mlc/realtime/output/data_output.py
  - 输出给教师端的数据构造。
  - build_teacher_payload(config, smooth_score, confusion_count_on_page)：构建包含分数、页码、疑惑计数、低专注标记、时间戳的 payload。

- src/mlc/realtime/output/__init__.py
  - output 模块导出。

### 教师端模块

- src/mlc/realtime/teacher/dashboard.py
  - 教师端状态管理与看板输出。
  - GLOBAL_CLASS_DATA：内存中的班级状态（模拟后端存储）。
  - update_server_state(payload)：更新某个学生的最新状态。
  - generate_teacher_report(config)：打印在线人数、学生状态、页面均值、风险学生、低专注页、高疑惑页。

- src/mlc/realtime/teacher/__init__.py
  - teacher 模块导出。

## 3. 当前运行流程

1. 入口 dryrun.py 启动 realtime pipeline。
2. 摄像头模块采集实时帧。
3. 模型模块进行（模拟）ViT 推理。
4. 评分模块执行平滑与状态分类。
5. 课件模块在软件内渲染 PDF 并更新当前页上下文。
6. 学生可随时提问 LLM，并记录页面级疑惑计数。
7. 输出模块绘制学生端 UI，并构建同步 payload。
8. 教师端模块更新全局状态并输出实时看板。

## 4. 后续扩展建议

1. 将 vit_inference.py 的模拟逻辑替换为真实模型推理（如 PyTorch/ONNX）。
2. 将 GLOBAL_CLASS_DATA 替换为真实后端存储（Redis/数据库/API）。
3. 将 LLM 助手从本地桩实现替换为真实 API 客户端。
4. 新增日志与数据落盘模块，用于训练集回放与分析。
5. 将教师端控制台输出升级为 Web Dashboard。

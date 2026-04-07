"""Realtime dry run entrypoint.

This script starts the camera-based monitoring loop.
"""

from src.mlc import PipelineConfig, run_realtime_pipeline


def main() -> None:
    config = PipelineConfig(
        student_id="GAO_LUO_01",
        current_page=10,
        sync_interval=2,
        camera_index=0,
    )
    run_realtime_pipeline(config)


if __name__ == "__main__":
    main()

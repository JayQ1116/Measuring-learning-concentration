from __future__ import annotations


def ask_learning_llm(question: str, page: int, state: str) -> str:
    """Return a lightweight tutoring response for in-app Q&A.

    This function is a local stub and can be replaced by a real LLM API call.
    """
    guidance = (
        "Try this 3-step method: 1) restate the definition, "
        "2) solve a tiny example, 3) explain why the answer makes sense."
    )

    return (
        f"[LLM Tutor] Page {page} | Current state: {state}. "
        f"Q: {question}\n"
        f"A: {guidance}"
    )

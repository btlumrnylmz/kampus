"""
Campus-specific guardrails for query filtering.
Ensures only campus-related queries are processed.
"""
from typing import Tuple
from dataclasses import dataclass

from config import CAMPUS_TOPICS, OFF_TOPIC_KEYWORDS


@dataclass
class GuardrailResult:
    """Result of guardrail check."""
    is_allowed: bool
    reason: str
    confidence: float  # 0.0 to 1.0


def normalize_text(text: str) -> str:
    """Normalize text for comparison."""
    return text.lower().strip()


def check_off_topic(query: str) -> Tuple[bool, str]:
    """
    Check if query contains off-topic keywords.

    Returns:
        Tuple of (is_off_topic, matched_keyword)
    """
    query_lower = normalize_text(query)

    for keyword in OFF_TOPIC_KEYWORDS:
        if keyword.lower() in query_lower:
            return True, keyword

    return False, ""


def check_campus_relevance(query: str) -> Tuple[bool, float]:
    """
    Check if query is campus-related.

    Returns:
        Tuple of (is_relevant, confidence_score)
    """
    query_lower = normalize_text(query)

    # Count matching campus topic keywords
    matches = 0
    for topic in CAMPUS_TOPICS:
        if topic.lower() in query_lower:
            matches += 1

    # Calculate confidence based on matches
    if matches >= 3:
        return True, 1.0
    elif matches >= 2:
        return True, 0.9
    elif matches >= 1:
        return True, 0.7
    else:
        # Check for question patterns that might be campus-related
        campus_question_patterns = [
            "nerede", "where", "nasıl gid", "how to get",
            "çalışma saatl", "working hours", "açık mı", "is it open",
            "kaç dakika", "how long", "ne zaman", "when",
            "hangi bina", "which building", "nereye", "where to",
        ]

        for pattern in campus_question_patterns:
            if pattern.lower() in query_lower:
                return True, 0.5

        return False, 0.0


def apply_guardrails(query: str) -> GuardrailResult:
    """
    Apply all guardrails to a query.

    Args:
        query: User query text

    Returns:
        GuardrailResult with decision and reason
    """
    # Reject empty queries
    if not query or not query.strip():
        return GuardrailResult(
            is_allowed=False,
            reason="Boş sorgu gönderildi.",
            confidence=1.0,
        )

    # Reject very short queries
    if len(query.strip()) < 3:
        return GuardrailResult(
            is_allowed=False,
            reason="Sorgu çok kısa.",
            confidence=1.0,
        )

    # Check for off-topic content
    is_off_topic, matched_keyword = check_off_topic(query)
    if is_off_topic:
        return GuardrailResult(
            is_allowed=False,
            reason=f"Bu konu kampüs asistanının kapsamı dışındadır.",
            confidence=1.0,
        )

    # Check campus relevance
    is_relevant, confidence = check_campus_relevance(query)

    if is_relevant:
        return GuardrailResult(
            is_allowed=True,
            reason="Sorgu kampüs ile ilgili.",
            confidence=confidence,
        )
    else:
        # Allow with low confidence - retrieval will filter further
        return GuardrailResult(
            is_allowed=True,
            reason="Sorgu kabul edildi, ancak kampüs ile ilgili olmayabilir.",
            confidence=0.3,
        )


def format_rejection_message(result: GuardrailResult) -> str:
    """Format a user-friendly rejection message."""
    return (
        "Bu soru kampüs asistanının kapsamı dışındadır. "
        "Lütfen kampüs binaları, konumlar, hizmetler veya "
        "üniversite ile ilgili sorular sorun."
    )










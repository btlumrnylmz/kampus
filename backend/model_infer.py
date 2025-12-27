"""
Model inference module for GPT-2 fine-tuned model.

Loads the Turkish GPT-2 model and generates JSON-structured answers.
"""
import json
import os
import re
from typing import Optional, List
from dataclasses import dataclass

from config import MODEL_PATH, MAX_NEW_TOKENS, TEMPERATURE


@dataclass
class InferenceResult:
    """Result of model inference."""
    text: str
    answer: Optional[str]
    sources: List[str]
    tokens_generated: int
    is_placeholder: bool
    raw_output: Optional[str] = None


# Singleton pattern for model
_model = None
_tokenizer = None
MODEL_LOADED = False


def is_model_available() -> bool:
    """Check if the model is available for inference."""
    return MODEL_LOADED


def get_model_path() -> Optional[str]:
    """Get the model path from environment or config."""
    return os.getenv("GPT2_MODEL_PATH", MODEL_PATH)


def load_model() -> bool:
    """
    Load the fine-tuned GPT-2 model (singleton).
    Returns True if successful, False otherwise.
    """
    global MODEL_LOADED, _model, _tokenizer

    if MODEL_LOADED:
        return True

    model_path = get_model_path()

    if model_path is None:
        print("[Model] GPT2_MODEL_PATH not set. Model inference disabled.")
        print("[Model] Set GPT2_MODEL_PATH environment variable to enable.")
        return False

    if not os.path.exists(model_path):
        print(f"[Model] Model path does not exist: {model_path}")
        return False

    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer

        print(f"[Model] Loading GPT-2 from {model_path}")

        # Load tokenizer
        _tokenizer = AutoTokenizer.from_pretrained(model_path)

        # Ensure pad token is set
        if _tokenizer.pad_token is None:
            _tokenizer.pad_token = _tokenizer.eos_token

        # Load model (CPU by default)
        _model = AutoModelForCausalLM.from_pretrained(
            model_path,
            device_map="cpu",
            low_cpu_mem_usage=True,
        )
        _model.eval()

        MODEL_LOADED = True
        print(f"[Model] Loaded GPT-2 from {model_path}")
        return True

    except ImportError:
        print("[Model] transformers library not installed.")
        print("[Model] Install with: pip install transformers torch")
        return False
    except Exception as e:
        print(f"[Model] Failed to load model: {e}")
        return False


def format_prompt(query: str, context: str, source_ids: List[str]) -> str:
    """
    Format the prompt for the model with inline source citations.

    Each context chunk should have its source_id for traceability.
    """
    # Build context with inline source citations
    context_with_sources = context

    prompt = f"""Sen bir kampüs asistanısın. Aşağıdaki bağlama dayanarak soruyu yanıtla.
Cevabı SADECE JSON formatında ver. Başka hiçbir metin ekleme.

Bağlam:
{context_with_sources}

Soru: {query}

JSON formatı:
{{"answer": "cevap metni", "confidence": 0.0-1.0}}

JSON:"""

    return prompt


def extract_json_from_output(text: str) -> Optional[dict]:
    """
    Extract and parse JSON from model output.
    Returns None if parsing fails.
    """
    try:
        # Try to find JSON in the output
        # Look for content between { and }
        json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if json_match:
            json_str = json_match.group()
            return json.loads(json_str)

        # Try parsing the entire text
        return json.loads(text.strip())

    except json.JSONDecodeError:
        return None


def generate_answer(
    query: str,
    context: str,
    source_ids: List[str],
) -> InferenceResult:
    """
    Generate an answer using the fine-tuned GPT-2 model.

    Args:
        query: User question
        context: Retrieved context from knowledge base (with source citations)
        source_ids: List of source document IDs

    Returns:
        InferenceResult with generated answer and metadata
    """
    if not is_model_available():
        return InferenceResult(
            text="",
            answer=None,
            sources=[],
            tokens_generated=0,
            is_placeholder=True,
        )

    try:
        # Format prompt
        prompt = format_prompt(query, context, source_ids)

        # Tokenize
        inputs = _tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=1024,
        )

        # Generation parameters
        gen_kwargs = {
            "max_new_tokens": 120,
            "temperature": 0.25,
            "top_p": 0.9,
            "repetition_penalty": 1.08,
            "do_sample": True,
            "pad_token_id": _tokenizer.pad_token_id,
            "eos_token_id": _tokenizer.eos_token_id,
        }

        # Generate
        import torch
        with torch.no_grad():
            outputs = _model.generate(**inputs, **gen_kwargs)

        # Decode
        generated_text = _tokenizer.decode(
            outputs[0],
            skip_special_tokens=True,
        )

        # Extract only the generated part (after the prompt)
        if prompt in generated_text:
            generated_part = generated_text[len(prompt):].strip()
        else:
            # Try to find JSON after "JSON:" marker
            if "JSON:" in generated_text:
                generated_part = generated_text.split("JSON:")[-1].strip()
            else:
                generated_part = generated_text.strip()

        print(f"[Model] Raw output: {generated_part[:200]}...")

        # Parse JSON
        parsed = extract_json_from_output(generated_part)

        if parsed is None:
            print("[Model] Failed to parse JSON from output")
            return InferenceResult(
                text="",
                answer=None,
                sources=source_ids,  # Return original sources
                tokens_generated=len(outputs[0]) - len(inputs["input_ids"][0]),
                is_placeholder=False,
                raw_output=generated_part,
            )

        # Extract answer
        answer = parsed.get("answer", "")
        confidence = parsed.get("confidence", 0.5)

        # IMPORTANT: Use ONLY the provided source_ids, not any from model output
        # The model must not invent source IDs
        validated_sources = source_ids

        print(f"[Model] Generated answer: {answer[:100]}...")
        print(f"[Model] Confidence: {confidence}")

        return InferenceResult(
            text=answer,
            answer=answer,
            sources=validated_sources,
            tokens_generated=len(outputs[0]) - len(inputs["input_ids"][0]),
            is_placeholder=False,
            raw_output=generated_part,
        )

    except Exception as e:
        print(f"[Model] Generation error: {e}")
        return InferenceResult(
            text="",
            answer=None,
            sources=source_ids,
            tokens_generated=0,
            is_placeholder=False,
        )

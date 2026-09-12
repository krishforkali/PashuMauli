# AI Specification

## Mobile vision
Use a lightweight quantized TensorFlow Lite model appropriate to the validated livestock dataset.

The model must be replaceable without changing the business layer.

Output:
- model version
- candidate labels
- confidence
- inference time
- preprocessing metadata

## Risk engine
AI prediction is only one signal.

Risk can incorporate:
- disease candidate
- confidence
- symptom checklist
- severity
- geographic outbreak context
- recent case density
- animal context

Return:
- score 0-100
- LOW/MEDIUM/HIGH/CRITICAL
- reasons
- escalation recommendation

## Advisory engine
Use an approved structured veterinary knowledge base/rule set.

A language model, if used, may translate/summarize approved content but must not invent treatment or medication instructions.

## Low confidence
If confidence is below configured threshold:
- do not present a definitive disease.
- request more information/photo.
- recommend veterinary review.

## Cloud AI
Amazon Bedrock may be an optional cloud enhancement for summaries or advanced assistance. Core offline workflows must not depend on Bedrock.

## Phase 5 local assistant
The conversational layer is Gemma 3 1B IT through LiteRT-LM behind a Dart `LocalLLMProvider` and Android platform bridge. It is separate from TFLite vision screening and from the deterministic risk engine. Before a response is displayed it must be grounded in the local approved knowledge retrieval result and pass the safety validator. The assistant must not diagnose, prescribe medication, give a dose, or contradict escalation advice.

Model binaries are external/local artifacts and must never be committed. Record model name, version, SHA-256 hash, runtime, backend, local path and status. CPH2213 testing identified Android 13 / arm64-v8a / MT6853V/TNZA; no verified LiteRT-LM accelerator package is available for that SoC, so CPU fallback is selected. Actual latency, memory and physical local-generation results must be measured and recorded only after a licensed compatible Gemma artifact is installed.

## Model lifecycle
Record model name/version/hash with each result. Keep model artifacts versioned.

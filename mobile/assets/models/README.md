No model binary is committed to this repository. A validated livestock TFLite model and its label/normalization manifest must be copied into app-private storage by a model installer; do not package an unvalidated model as production AI.

The conversational artifact is **Gemma 3 1B IT**, quantized for **LiteRT-LM**. Obtain it through the model publisher's approved distribution/licence flow, verify SHA-256, and install it outside Git/APK assets. Configure its runtime path and save model name/version/hash/runtime/backend/local path/status in SQLite `model_metadata`.

CPH2213 reports Android 13, arm64-v8a, and MediaTek MT6853V/TNZA. No compatible LiteRT-LM accelerator artifact is verified for this SoC; selected backend is CPU fallback. Basic reporting remains usable when either model is absent.

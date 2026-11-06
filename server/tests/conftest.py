import os

# Tests must never reach a paid API; force the deterministic fake provider
# before the settings object is created.
os.environ.setdefault("ASR_PROVIDER", "fake")
os.environ.setdefault("TRANSLATE_PROVIDER", "none")

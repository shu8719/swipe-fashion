import os

DB_PATH       = os.getenv("DB_PATH", "./fashion.sqlite3")
SECRET_KEY    = os.getenv("SECRET_KEY", "dev_secret_key")
LLM_PROVIDER  = os.getenv("LLM_PROVIDER", "ollama")     # ollama | gemini | mock
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL  = os.getenv("OLLAMA_MODEL", "gemma4:26b-mxfp8")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
GEMINI_MODEL   = os.getenv("GEMINI_MODEL", "gemini-3.5-flash")

import os

# Production: postgresql+psycopg2://user:pass@host/dbname (tech-design.md §8).
# Defaults to a local SQLite file so the app runs without a Postgres instance
# during development/testing.
DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./dev.db")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

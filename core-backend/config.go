package main

import "os"

// Production: postgresql connection string via DATABASE_URL (tech-design.md §8).
// Defaults to a local SQLite file so the service runs without Postgres during
// development/testing.
func databaseURL() string {
	if v := os.Getenv("DATABASE_URL"); v != "" {
		return v
	}
	return "sqlite:./dev.db"
}

func aiServiceURL() string {
	if v := os.Getenv("AI_SERVICE_URL"); v != "" {
		return v
	}
	return "http://localhost:8001"
}

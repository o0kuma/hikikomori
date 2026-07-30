package main

import (
	"log"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func openDB() *gorm.DB {
	url := databaseURL()

	var dialector gorm.Dialector
	if strings.HasPrefix(url, "sqlite:") {
		dialector = sqlite.Open(strings.TrimPrefix(url, "sqlite:"))
	} else {
		dialector = postgres.Open(url)
	}

	db, err := gorm.Open(dialector, &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	if err := db.AutoMigrate(allModels...); err != nil {
		log.Fatalf("failed to migrate database: %v", err)
	}

	return db
}

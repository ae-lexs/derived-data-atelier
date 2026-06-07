package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPAddr     string
	PGHost       string
	PGPort       int
	PGUser       string
	PGPassword   string // empty when UseIAMAuth is true
	PGDatabase   string
	UseIAMAuth   bool
	AWSRegion    string
	OTLPEndpoint string
	ServiceName  string
}

func Load() (Config, error) {
	port, err := strconv.Atoi(getenv("PG_PORT", "5432"))
	if err != nil {
		return Config{}, fmt.Errorf("PG_PORT: %w", err)
	}

	return Config{
		HTTPAddr:     getenv("HTTP_ADDR", ":8080"),
		PGHost:       mustGet("PG_HOST"),
		PGPort:       port,
		PGUser:       mustGet("PG_USER"),
		PGPassword:   os.Getenv("PG_PASSWORD"),
		PGDatabase:   mustGet("PG_DATABASE"),
		UseIAMAuth:   getenv("USE_IAM_AUTH", "false") == "true",
		AWSRegion:    getenv("AWS_REGION", "us-east-1"),
		OTLPEndpoint: getenv("OTLP_ENDPOINT", "http://localhost:4318"),
		ServiceName:  getenv("SERVICE_NAME", "dda-api"),
	}, nil
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mustGet(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("required env var not set: %s", key))
	}
	return v
}

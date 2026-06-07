package pg

import (
	"context"
	"testing"
	"time"
)

func TestBuildPoolConfig_PasswordAuth(t *testing.T) {
	cfg := Config{
		Host:       "localhost",
		Port:       5432,
		User:       "dda_master",
		Password:   "p",
		Database:   "tpch",
		UseIAMAuth: false,
	}
	poolCfg, err := buildPoolConfig(context.Background(), cfg)
	if err != nil {
		t.Fatalf("buildPoolConfig: %v", err)
	}
	if poolCfg.BeforeConnect != nil {
		t.Errorf("BeforeConnect must be nil for password auth; got non-nil")
	}
	if poolCfg.MaxConnLifetime != 10*time.Minute {
		t.Errorf("MaxConnLifetime: want 10m, got %v", poolCfg.MaxConnLifetime)
	}
	if poolCfg.MaxConns != 25 {
		t.Errorf("MaxConns: want 25, got %d", poolCfg.MaxConns)
	}
	if poolCfg.MinConns != 5 {
		t.Errorf("MinConns: want 5, got %d", poolCfg.MinConns)
	}
}

func TestBuildPoolConfig_IAMAuth(t *testing.T) {
	cfg := Config{
		Host:       "dda-aurora.cluster-xyz.us-east-1.rds.amazonaws.com",
		Port:       5432,
		User:       "dda_app",
		Database:   "tpch",
		UseIAMAuth: true,
		AWSRegion:  "us-east-1",
	}
	poolCfg, err := buildPoolConfig(context.Background(), cfg)
	if err != nil {
		t.Fatalf("buildPoolConfig: %v", err)
	}
	if poolCfg.BeforeConnect == nil {
		t.Fatal("BeforeConnect must be wired when UseIAMAuth=true; got nil")
	}
	// MaxConnLifetime must be strictly less than the 15-minute IAM-token lifetime
	// so the pool rotates connections before their tokens expire.
	if poolCfg.MaxConnLifetime >= 15*time.Minute {
		t.Errorf("MaxConnLifetime must be < 15m for IAM auth; got %v", poolCfg.MaxConnLifetime)
	}
}

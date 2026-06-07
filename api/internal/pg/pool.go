package pg

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/rds/auth"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Config struct {
	Host       string
	Port       int
	User       string
	Password   string // empty when UseIAMAuth is true
	Database   string
	UseIAMAuth bool
	AWSRegion  string
}

func NewPool(ctx context.Context, cfg Config) (*pgxpool.Pool, error) {
	poolCfg, err := buildPoolConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	return pool, nil
}

func buildPoolConfig(ctx context.Context, cfg Config) (*pgxpool.Config, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s dbname=%s sslmode=require",
		cfg.Host, cfg.Port, cfg.User, cfg.Database,
	)
	if !cfg.UseIAMAuth {
		dsn = fmt.Sprintf("%s password=%s", dsn, cfg.Password)
	}

	poolCfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse pool config: %w", err)
	}

	poolCfg.MaxConns = 25
	poolCfg.MinConns = 5
	poolCfg.MaxConnLifetime = 10 * time.Minute // < 15-min IAM-token lifetime
	poolCfg.MaxConnIdleTime = 30 * time.Second
	poolCfg.HealthCheckPeriod = 30 * time.Second

	if cfg.UseIAMAuth {
		awsCfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(cfg.AWSRegion))
		if err != nil {
			return nil, fmt.Errorf("load AWS config: %w", err)
		}
		endpoint := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)

		poolCfg.BeforeConnect = func(ctx context.Context, c *pgx.ConnConfig) error {
			token, err := auth.BuildAuthToken(ctx, endpoint, cfg.AWSRegion, cfg.User, awsCfg.Credentials)
			if err != nil {
				return fmt.Errorf("build IAM token: %w", err)
			}
			c.Password = token
			return nil
		}
	}

	return poolCfg, nil
}

package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/ae-lexs/derived-data-atelier/api/internal/config"
	"github.com/ae-lexs/derived-data-atelier/api/internal/handlers"
	"github.com/ae-lexs/derived-data-atelier/api/internal/pg"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	pool, err := pg.NewPool(ctx, pg.Config{
		Host:       cfg.PGHost,
		Port:       cfg.PGPort,
		User:       cfg.PGUser,
		Password:   cfg.PGPassword,
		Database:   cfg.PGDatabase,
		UseIAMAuth: cfg.UseIAMAuth,
		AWSRegion:  cfg.AWSRegion,
	})
	if err != nil {
		log.Fatalf("pool: %v", err)
	}
	defer pool.Close()

	orders := &handlers.Orders{Pool: pool}
	analytics := &handlers.Analytics{Pool: pool}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/healthz", handlers.Health)
	r.Get("/orders/{key}", orders.Get)
	r.Post("/orders", orders.Create)
	r.Get("/analytics/{q}", analytics.Run)

	srv := &http.Server{Addr: cfg.HTTPAddr, Handler: r}
	go func() {
		log.Printf("listening on %s", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	<-ctx.Done()
	shCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shCtx); err != nil {
		log.Fatalf("shutdown: %v", err)
	}
}

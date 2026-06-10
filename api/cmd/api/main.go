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
	apiotel "github.com/ae-lexs/derived-data-atelier/api/internal/otel"
	"github.com/ae-lexs/derived-data-atelier/api/internal/pg"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/trace"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	shutdown, err := apiotel.Setup(ctx, cfg.ServiceName, cfg.OTLPEndpoint)
	if err != nil {
		log.Fatalf("otel: %v", err)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = shutdown(ctx)
	}()

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
	// Rename the server span to METHOD<space>route-pattern after chi has
	// routed, so dashboards group OLTP vs OLAP traffic by route rather than
	// by raw URL path. The span itself is created by otelhttp at the outer
	// http.Server boundary; this middleware just updates its name.
	r.Use(spanRouteName)
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/healthz", handlers.Health)
	r.Get("/orders/{key}", orders.Get)
	r.Post("/orders", orders.Create)
	r.Get("/analytics/{q}", analytics.Run)

	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: otelhttp.NewHandler(r, cfg.ServiceName,
			// Skip /healthz from tracing — probe noise would dilute the OLTP
			// latency histogram the methodology contract measures.
			otelhttp.WithFilter(func(req *http.Request) bool {
				return req.URL.Path != "/healthz"
			}),
		),
	}
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

func spanRouteName(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
		rc := chi.RouteContext(r.Context())
		if rc == nil {
			return
		}
		if pat := rc.RoutePattern(); pat != "" {
			trace.SpanFromContext(r.Context()).SetName(r.Method + " " + pat)
		}
	})
}

package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"
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
		SSLMode:    cfg.PGSSLMode,
		UseIAMAuth: cfg.UseIAMAuth,
		AWSRegion:  cfg.AWSRegion,
	})
	if err != nil {
		log.Fatalf("pool: %v", err)
	}
	defer pool.Close()

	orders := &handlers.Orders{Pool: pool}
	analytics := &handlers.Analytics{Pool: pool}

	// JSON access logger. Its output is the methodology contract's primary data
	// source: the awslogs driver ships these lines to the /dda/api log group,
	// where queries/p99-during-vs-outside-olap.cwli reads http.method,
	// http.target, and latency_ms. chi's stock middleware.Logger emits
	// plaintext that Logs Insights cannot parse into those fields, so it is
	// replaced by accessLog below.
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	r := chi.NewRouter()
	// Rename the server span to METHOD<space>route-pattern after chi has
	// routed, so dashboards group OLTP vs OLAP traffic by route rather than
	// by raw URL path. The span itself is created by otelhttp at the outer
	// http.Server boundary; this middleware just updates its name.
	r.Use(spanRouteName)
	r.Use(middleware.RequestID)
	r.Use(accessLog(logger))
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

// accessLog emits one structured JSON line per request to stdout. The fields
// are nested under "http" so CloudWatch Logs Insights flattens them to the
// dotted names the methodology query expects: http.method, http.target,
// http.status. latency_ms is the wall-clock service time in milliseconds and is
// the value pct(latency_ms, 99) aggregates. /healthz is skipped — ALB probe
// traffic would otherwise dominate the log group and inflate cost without
// contributing to the /orders/-scoped p99 measurement (mirrors the otelhttp
// trace filter above).
func accessLog(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/healthz" {
				next.ServeHTTP(w, r)
				return
			}
			ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			start := time.Now()
			next.ServeHTTP(ww, r)
			logger.LogAttrs(r.Context(), slog.LevelInfo, "http_request",
				slog.Group("http",
					slog.String("method", r.Method),
					slog.String("target", r.URL.Path),
					slog.Int("status", ww.Status()),
				),
				slog.Float64("latency_ms", float64(time.Since(start).Microseconds())/1000.0),
				slog.String("request_id", middleware.GetReqID(r.Context())),
			)
		})
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

package handlers

import (
    "encoding/json"
    "errors"
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"
)

type Order struct {
    OrderKey      int64   `json:"o_orderkey"`
    CustKey       int64   `json:"o_custkey"`
    OrderStatus   string  `json:"o_orderstatus"`
    TotalPrice    float64 `json:"o_totalprice"`
    OrderDate     string  `json:"o_orderdate"`
    OrderPriority string  `json:"o_orderpriority"`
    Clerk         string  `json:"o_clerk"`
    ShipPriority  int32   `json:"o_shippriority"`
    Comment       string  `json:"o_comment"`
}

type Orders struct {
    Pool *pgxpool.Pool
}

func (h *Orders) Get(w http.ResponseWriter, r *http.Request) {
    key := chi.URLParam(r, "key")
    var o Order
    err := h.Pool.QueryRow(r.Context(), `
        SELECT o_orderkey, o_custkey, o_orderstatus, o_totalprice,
               o_orderdate::text, o_orderpriority, o_clerk, o_shippriority, o_comment
        FROM orders
        WHERE o_orderkey = $1
    `, key).Scan(
        &o.OrderKey, &o.CustKey, &o.OrderStatus, &o.TotalPrice,
        &o.OrderDate, &o.OrderPriority, &o.Clerk, &o.ShipPriority, &o.Comment,
    )
    if errors.Is(err, pgx.ErrNoRows) {
        http.NotFound(w, r)
        return
    }
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    writeJSON(w, http.StatusOK, o)
}

func (h *Orders) Create(w http.ResponseWriter, r *http.Request) {
    var in Order
    if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    err := h.Pool.QueryRow(r.Context(), `
        INSERT INTO orders (
            o_orderkey, o_custkey, o_orderstatus, o_totalprice, o_orderdate,
            o_orderpriority, o_clerk, o_shippriority, o_comment
        ) VALUES ($1, $2, $3, $4, $5::date, $6, $7, $8, $9)
        RETURNING o_orderkey
    `,
        in.OrderKey, in.CustKey, in.OrderStatus, in.TotalPrice, in.OrderDate,
        in.OrderPriority, in.Clerk, in.ShipPriority, in.Comment,
    ).Scan(&in.OrderKey)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    writeJSON(w, http.StatusCreated, in)
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    _ = json.NewEncoder(w).Encode(v)
}

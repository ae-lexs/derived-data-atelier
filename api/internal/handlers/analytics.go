package handlers

import (
	"embed"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed sql/*.sql
var sqlFS embed.FS

type Analytics struct {
	Pool *pgxpool.Pool
}

func (h *Analytics) Run(w http.ResponseWriter, r *http.Request) {
	q := chi.URLParam(r, "q")
	sql, err := sqlFS.ReadFile("sql/" + q + ".sql")
	if err != nil {
		http.NotFound(w, r)
		return
	}

	rows, err := h.Pool.Query(r.Context(), string(sql))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	cols := rows.FieldDescriptions()
	out := []map[string]interface{}{}
	for rows.Next() {
		vals, err := rows.Values()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		row := make(map[string]interface{}, len(cols))
		for i, c := range cols {
			row[string(c.Name)] = vals[i]
		}
		out = append(out, row)
	}
	writeJSON(w, http.StatusOK, out)
}

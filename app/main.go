package main

import (
	"embed"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strings"
)

//go:embed data/questions.json
var questionsJSON []byte

//go:embed all:web/dist
var webDist embed.FS

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/api/questions", handleQuestions)
	mux.HandleFunc("/", handleSPA)

	log.Printf("listening on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"healthy":true}`))
}

func handleQuestions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.Write(questionsJSON)
}

// handleSPA serves the React SPA from web/dist. If the requested path points
// at an existing file (e.g. /assets/index-abc.js) it's served as-is; otherwise
// we fall back to index.html so React Router can handle client-side routes.
func handleSPA(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	dist, err := fs.Sub(webDist, "web/dist")
	if err != nil {
		http.Error(w, "spa not built", http.StatusInternalServerError)
		return
	}

	reqPath := strings.TrimPrefix(r.URL.Path, "/")
	if reqPath != "" {
		if f, err := dist.Open(reqPath); err == nil {
			info, _ := f.Stat()
			f.Close()
			if info != nil && !info.IsDir() {
				http.FileServer(http.FS(dist)).ServeHTTP(w, r)
				return
			}
		}
	}

	index, err := dist.Open("index.html")
	if err != nil {
		http.Error(w, "spa not built — run 'make web-build'", http.StatusNotFound)
		return
	}
	defer index.Close()
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	io.Copy(w, index)
}

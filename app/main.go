package main

import (
	"embed"
	"encoding/json"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
)

//go:embed data/questions.json
var questionsJSON []byte

//go:embed data/study_content.json
var studyContentJSON []byte

//go:embed all:web/dist
var webDist embed.FS

// studyData is parsed once at startup from study_content.json.
var studyData struct {
	Domains []struct {
		ID        int      `json:"id"`
		Title     string   `json:"title"`
		Content   string   `json:"content"`
		InfraRefs []string `json:"infra_refs"`
	} `json:"domains"`
	InfraFiles map[string]string `json:"infra_files"`
	DocFiles   map[string]string `json:"doc_files"`
}

func main() {
	if err := json.Unmarshal(studyContentJSON, &studyData); err != nil {
		log.Fatalf("parse study_content.json: %v", err)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/api/questions", handleQuestions)
	mux.HandleFunc("/api/study", handleStudyList)
	mux.HandleFunc("/api/study/", handleStudyDomain)
	mux.HandleFunc("/api/infra/", handleInfraFile)
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

// handleStudyList returns the list of domains (id, title, infra_refs) without full content.
func handleStudyList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	type domainSummary struct {
		ID        int      `json:"id"`
		Title     string   `json:"title"`
		InfraRefs []string `json:"infra_refs"`
	}
	summaries := make([]domainSummary, len(studyData.Domains))
	for i, d := range studyData.Domains {
		summaries[i] = domainSummary{ID: d.ID, Title: d.Title, InfraRefs: d.InfraRefs}
	}
	b, _ := json.Marshal(map[string]any{"domains": summaries})
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.Write(b)
}

// handleStudyDomain returns full markdown content for /api/study/{id}.
func handleStudyDomain(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	idStr := strings.TrimPrefix(r.URL.Path, "/api/study/")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid domain id", http.StatusBadRequest)
		return
	}
	for _, d := range studyData.Domains {
		if d.ID == id {
			b, _ := json.Marshal(map[string]any{
				"id":         d.ID,
				"title":      d.Title,
				"content":    d.Content,
				"infra_refs": d.InfraRefs,
			})
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
			w.Header().Set("Cache-Control", "public, max-age=300")
			w.Write(b)
			return
		}
	}
	http.Error(w, "domain not found", http.StatusNotFound)
}

// handleInfraFile serves a .tf file content for /api/infra/{filename}.
func handleInfraFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	filename := strings.TrimPrefix(r.URL.Path, "/api/infra/")
	if !strings.HasSuffix(filename, ".tf") {
		http.Error(w, "only .tf files are served", http.StatusBadRequest)
		return
	}
	content, ok := studyData.InfraFiles[filename]
	if !ok {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}
	b, _ := json.Marshal(map[string]string{"filename": filename, "content": content})
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.Write(b)
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

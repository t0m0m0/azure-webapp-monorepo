// gen-study parses AZ-104_STUDY_GUIDE.md + infra/*.tf and writes study_content.json.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type StudyContent struct {
	Domains    []DomainContent   `json:"domains"`
	InfraFiles map[string]string `json:"infra_files"`
	DocFiles   map[string]string `json:"doc_files"`
}

type DomainContent struct {
	ID        int      `json:"id"`
	Title     string   `json:"title"`
	Content   string   `json:"content"`
	InfraRefs []string `json:"infra_refs"`
}

var reDomainHeader = regexp.MustCompile(`(?m)^# Domain (\d+): (.+)$`)
var reTFRef = regexp.MustCompile(`[\w]+\.tf`)

func main() {
	guideBytes, err := os.ReadFile("../../docs/AZ-104_STUDY_GUIDE.md")
	if err != nil {
		fmt.Fprintf(os.Stderr, "read study guide: %v\n", err)
		os.Exit(1)
	}

	domains := splitByDomain(string(guideBytes))

	infraFiles := map[string]string{}
	tfPaths, _ := filepath.Glob("../../infra/*.tf")
	for _, p := range tfPaths {
		content, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		infraFiles[filepath.Base(p)] = string(content)
	}

	docFiles := map[string]string{}
	docPaths, _ := filepath.Glob("../../docs/*.md")
	for _, p := range docPaths {
		name := filepath.Base(p)
		if name == "AZ-104_STUDY_GUIDE.md" {
			continue // already inlined per-domain
		}
		content, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		docFiles[name] = string(content)
	}

	for i, d := range domains {
		refs := reTFRef.FindAllString(d.Content, -1)
		seen := map[string]bool{}
		var unique []string
		for _, r := range refs {
			if infraFiles[r] != "" && !seen[r] {
				seen[r] = true
				unique = append(unique, r)
			}
		}
		domains[i].InfraRefs = unique
	}

	out := StudyContent{Domains: domains, InfraFiles: infraFiles, DocFiles: docFiles}
	b, err := json.Marshal(out)
	if err != nil {
		fmt.Fprintf(os.Stderr, "marshal: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile("../data/study_content.json", b, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "write: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("wrote %d domains, %d infra files, %d doc files\n",
		len(domains), len(infraFiles), len(docFiles))
}

func splitByDomain(guide string) []DomainContent {
	matches := reDomainHeader.FindAllStringIndex(guide, -1)
	if len(matches) == 0 {
		return nil
	}
	var domains []DomainContent
	for i, m := range matches {
		header := guide[m[0]:m[1]]
		subs := reDomainHeader.FindStringSubmatch(header)
		if len(subs) < 3 {
			continue
		}
		id, _ := strconv.Atoi(subs[1])
		title := strings.TrimSpace(subs[2])
		if idx := strings.Index(title, " ("); idx > 0 {
			title = title[:idx]
		}

		var content string
		start := m[1]
		if i+1 < len(matches) {
			content = guide[start:matches[i+1][0]]
		} else {
			content = guide[start:]
		}
		domains = append(domains, DomainContent{
			ID:      id,
			Title:   title,
			Content: strings.TrimSpace(content),
		})
	}
	return domains
}

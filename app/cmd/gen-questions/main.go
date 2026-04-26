package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/example/azure-webapp/internal/parser"
)

func main() {
	in := flag.String("in", "../docs/AZ-104_STUDY_GUIDE.md", "path to AZ-104 study guide markdown")
	out := flag.String("out", "data/questions.json", "output JSON path")
	check := flag.Bool("check", false, "compare generated JSON with existing file and exit non-zero if different")
	flag.Parse()

	mdBytes, err := os.ReadFile(*in)
	if err != nil {
		fail("read input: %v", err)
	}

	ds, err := parser.Parse(string(mdBytes))
	if err != nil {
		fail("parse: %v", err)
	}

	// Enrich domain summaries from AZ-104_STUDY_GUIDE (optional — left empty if not captured).
	// For now the parser collects only title/weight; we could extend it later.

	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(ds); err != nil {
		fail("encode: %v", err)
	}

	generated := buf.Bytes()

	if *check {
		existing, err := os.ReadFile(*out)
		if err != nil {
			fail("read existing %s: %v", *out, err)
		}
		var have, want parser.Dataset
		if err := json.Unmarshal(existing, &have); err != nil {
			fail("unmarshal existing: %v", err)
		}
		if err := json.Unmarshal(generated, &want); err != nil {
			fail("unmarshal generated: %v", err)
		}
		if !datasetsEqual(&have, &want) {
			fmt.Fprintln(os.Stderr, "questions.json is out of date — run 'make gen-questions'")
			os.Exit(1)
		}
		fmt.Fprintln(os.Stderr, "questions.json is up to date")
		return
	}

	if err := os.WriteFile(*out, generated, 0o644); err != nil {
		fail("write output: %v", err)
	}
	fmt.Fprintf(os.Stderr, "wrote %s (%d domains, %d questions, %d mock)\n",
		*out, len(ds.Domains), len(ds.Questions), len(ds.MockExam))
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "gen-questions: "+format+"\n", args...)
	os.Exit(1)
}

func datasetsEqual(a, b *parser.Dataset) bool {
	ajson, _ := json.Marshal(a)
	bjson, _ := json.Marshal(b)
	return bytes.Equal(ajson, bjson)
}

package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParse_Sample(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("testdata", "sample.md"))
	if err != nil {
		t.Fatal(err)
	}
	ds, err := Parse(string(data))
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}

	if got, want := len(ds.Domains), 2; got != want {
		t.Errorf("domain count: got %d want %d", got, want)
	}
	if ds.Domains[0].ID != 1 || ds.Domains[0].Title != "IDとガバナンスの管理" || ds.Domains[0].Weight != "20-25%" {
		t.Errorf("domain 1 mismatch: %+v", ds.Domains[0])
	}

	// 3 practice questions (d1-q1, d1-q2, d2-q1) + 2 mock
	if got, want := len(ds.Questions), 5; got != want {
		t.Fatalf("question count: got %d want %d", got, want)
	}

	d1q1 := ds.Questions[0]
	if d1q1.ID != "d1-q1" {
		t.Errorf("d1-q1 id: %s", d1q1.ID)
	}
	if d1q1.Domain != 1 {
		t.Errorf("d1-q1 domain: %d", d1q1.Domain)
	}
	if d1q1.Answer != "C" {
		t.Errorf("d1-q1 answer: %s", d1q1.Answer)
	}
	if len(d1q1.Options) != 4 {
		t.Errorf("d1-q1 options: %d", len(d1q1.Options))
	}
	if d1q1.Options[2].Key != "C" || d1q1.Options[2].Text != "Deny" {
		t.Errorf("d1-q1 option C: %+v", d1q1.Options[2])
	}
	if d1q1.Reference != "governance.tf" {
		t.Errorf("d1-q1 reference: %q", d1q1.Reference)
	}
	if d1q1.Explanation == "" {
		t.Errorf("d1-q1 explanation missing")
	}

	mock1 := ds.Questions[3]
	if mock1.ID != "mock-q1" {
		t.Errorf("mock-q1 id: %s", mock1.ID)
	}
	if mock1.Domain != 0 {
		t.Errorf("mock-q1 domain: %d", mock1.Domain)
	}
	if mock1.Answer != "B" {
		t.Errorf("mock-q1 answer: %s", mock1.Answer)
	}

	if got, want := len(ds.MockExam), 2; got != want {
		t.Errorf("mock exam refs: got %d want %d", got, want)
	}
	if ds.MockExam[0] != "mock-q1" {
		t.Errorf("mockExam[0]: %s", ds.MockExam[0])
	}
}

func TestParse_RealStudyGuide(t *testing.T) {
	path := filepath.Join("..", "..", "..", "docs", "AZ-104_STUDY_GUIDE.md")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Skipf("study guide not found: %v", err)
	}
	ds, err := Parse(string(data))
	if err != nil {
		t.Fatalf("parse real guide: %v", err)
	}

	if len(ds.Domains) != 5 {
		t.Errorf("expected 5 domains, got %d", len(ds.Domains))
	}

	// Expect at least 30 domain-scoped questions + 20 mock = 50+
	domainQs := 0
	mockQs := 0
	for _, q := range ds.Questions {
		if q.Domain == 0 {
			mockQs++
		} else {
			domainQs++
		}
		if q.Answer == "" {
			t.Errorf("question %s has no answer", q.ID)
		}
		if len(q.Options) < 2 {
			t.Errorf("question %s has %d options", q.ID, len(q.Options))
		}
		if q.Text == "" {
			t.Errorf("question %s has empty text", q.ID)
		}
	}
	if domainQs < 25 {
		t.Errorf("expected >=25 domain questions, got %d", domainQs)
	}
	if mockQs < 15 {
		t.Errorf("expected >=15 mock questions, got %d", mockQs)
	}
	if len(ds.MockExam) != mockQs {
		t.Errorf("mockExam list (%d) does not match mock questions (%d)", len(ds.MockExam), mockQs)
	}

	t.Logf("parsed %d domain questions, %d mock questions", domainQs, mockQs)
}

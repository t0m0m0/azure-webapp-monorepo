package parser

import (
	"bufio"
	"fmt"
	"regexp"
	"strings"
)

type Option struct {
	Key  string `json:"key"`
	Text string `json:"text"`
}

type Question struct {
	ID          string   `json:"id"`
	Domain      int      `json:"domain"` // 1-5 for domain questions, 0 for mock exam
	Number      int      `json:"number"`
	Text        string   `json:"text"`
	Options     []Option `json:"options"`
	Answer      string   `json:"answer"`
	Explanation string   `json:"explanation"`
	Reference   string   `json:"reference,omitempty"`
}

type Domain struct {
	ID      int    `json:"id"`
	Title   string `json:"title"`
	Weight  string `json:"weight"`
	Summary string `json:"summary,omitempty"`
}

type Dataset struct {
	Domains   []Domain   `json:"domains"`
	Questions []Question `json:"questions"`
	MockExam  []string   `json:"mockExam"`
}

var (
	domainHeadingRe = regexp.MustCompile(`^#\s+Domain\s+(\d+):\s*(.+?)\s*\(([^)]+)\)\s*$`)
	mockHeadingRe   = regexp.MustCompile(`^#\s+総合模擬問題`)
	practiceHeadRe  = regexp.MustCompile(`^##\s+Domain\s+\d+\s+練習問題`)
	questionHeadRe  = regexp.MustCompile(`^###\s+問題(\d+)\s*$`)
	sectionHeadRe   = regexp.MustCompile(`^#{1,6}\s+`)
	optionRe        = regexp.MustCompile(`^([A-E])\)\s+(.+?)\s*$`)
	detailsOpenRe   = regexp.MustCompile(`^<details>\s*$`)
	detailsCloseRe  = regexp.MustCompile(`^</details>\s*$`)
	summaryRe       = regexp.MustCompile(`<summary>(.*?)</summary>`)
	correctInBodyRe = regexp.MustCompile(`\*\*正解[:：]\s*([A-E])\)?`)
	answerInSumRe   = regexp.MustCompile(`解答[:：]\s*([A-E])\)?`)
	referenceRe     = regexp.MustCompile("\\*\\*参照[:：]\\*\\*\\s*`([^`]+)`")
)

// Parse extracts all domains and questions from the given AZ-104 study guide markdown.
func Parse(md string) (*Dataset, error) {
	ds := &Dataset{}
	scanner := bufio.NewScanner(strings.NewReader(md))
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)

	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	currentDomain := 0 // 0 = not in a domain yet / 0 during mock exam
	inMock := false

	i := 0
	for i < len(lines) {
		line := lines[i]

		if m := domainHeadingRe.FindStringSubmatch(line); m != nil {
			id := atoi(m[1])
			ds.Domains = append(ds.Domains, Domain{
				ID:     id,
				Title:  strings.TrimSpace(m[2]),
				Weight: strings.TrimSpace(m[3]),
			})
			currentDomain = id
			inMock = false
			i++
			continue
		}

		if mockHeadingRe.MatchString(line) {
			inMock = true
			currentDomain = 0
			i++
			continue
		}

		// Only capture questions that appear inside a practice-problem section or mock exam.
		// We detect question starts anywhere, but domain questions are scoped by the practice heading.
		if qm := questionHeadRe.FindStringSubmatch(line); qm != nil {
			number := atoi(qm[1])
			end := findBlockEnd(lines, i+1)
			q, err := parseQuestionBlock(lines[i+1 : end])
			if err != nil {
				return nil, fmt.Errorf("question %d (line %d): %w", number, i+1, err)
			}
			q.Number = number
			if inMock {
				q.Domain = 0
				q.ID = fmt.Sprintf("mock-q%d", number)
				ds.MockExam = append(ds.MockExam, q.ID)
			} else if currentDomain > 0 && isInPracticeSection(lines, i) {
				q.Domain = currentDomain
				q.ID = fmt.Sprintf("d%d-q%d", currentDomain, number)
			} else {
				// Skip questions that are not inside a practice or mock section (defensive)
				i = end
				continue
			}
			ds.Questions = append(ds.Questions, *q)
			i = end
			continue
		}

		i++
	}

	return ds, nil
}

// isInPracticeSection walks backwards from idx to find the nearest `## ` heading
// and returns true if it matches the "Domain N 練習問題" pattern.
func isInPracticeSection(lines []string, idx int) bool {
	for j := idx - 1; j >= 0; j-- {
		l := lines[j]
		if strings.HasPrefix(l, "## ") {
			return practiceHeadRe.MatchString(l)
		}
		if strings.HasPrefix(l, "# ") {
			// Hit a top-level heading before a `## ` — not in a practice section.
			return false
		}
	}
	return false
}

// findBlockEnd returns the line index where the question block ends,
// which is the start of the next `### ` or higher-level heading.
func findBlockEnd(lines []string, start int) int {
	for j := start; j < len(lines); j++ {
		l := lines[j]
		if sectionHeadRe.MatchString(l) {
			// Next heading — end of this question.
			return j
		}
	}
	return len(lines)
}

func parseQuestionBlock(block []string) (*Question, error) {
	q := &Question{}
	// Phase 1: question text until first option line
	var textLines []string
	i := 0
	for i < len(block) {
		l := block[i]
		if optionRe.MatchString(strings.TrimSpace(l)) {
			break
		}
		textLines = append(textLines, l)
		i++
	}
	q.Text = strings.TrimSpace(strings.Join(textLines, "\n"))
	if q.Text == "" {
		return nil, fmt.Errorf("empty question text")
	}

	// Phase 2: options (A-E, consecutive lines, possibly separated by blank lines)
	for i < len(block) {
		trimmed := strings.TrimSpace(block[i])
		if trimmed == "" {
			i++
			continue
		}
		m := optionRe.FindStringSubmatch(trimmed)
		if m == nil {
			break
		}
		q.Options = append(q.Options, Option{Key: m[1], Text: strings.TrimSpace(m[2])})
		i++
	}
	if len(q.Options) < 2 {
		return nil, fmt.Errorf("expected at least 2 options, got %d", len(q.Options))
	}

	// Phase 3: find <details> ... </details>
	detailsStart := -1
	detailsEnd := -1
	for j := i; j < len(block); j++ {
		if detailsOpenRe.MatchString(strings.TrimSpace(block[j])) {
			detailsStart = j
			break
		}
	}
	if detailsStart == -1 {
		return nil, fmt.Errorf("missing <details> block")
	}
	for j := detailsStart + 1; j < len(block); j++ {
		if detailsCloseRe.MatchString(strings.TrimSpace(block[j])) {
			detailsEnd = j
			break
		}
	}
	if detailsEnd == -1 {
		return nil, fmt.Errorf("missing </details> closing tag")
	}

	detailsBody := block[detailsStart+1 : detailsEnd]

	// Extract summary line (may span a single line)
	var summaryText string
	bodyStart := 0
	for j, l := range detailsBody {
		if sm := summaryRe.FindStringSubmatch(l); sm != nil {
			summaryText = sm[1]
			bodyStart = j + 1
			break
		}
	}

	// Extract answer letter — prefer **正解: X** (Format A), fallback to 解答: X in summary (Format B)
	joined := strings.Join(detailsBody, "\n")
	if m := correctInBodyRe.FindStringSubmatch(joined); m != nil {
		q.Answer = m[1]
	} else if m := answerInSumRe.FindStringSubmatch(summaryText); m != nil {
		q.Answer = m[1]
	} else {
		return nil, fmt.Errorf("could not determine answer letter")
	}

	// Extract reference (optional)
	if m := referenceRe.FindStringSubmatch(joined); m != nil {
		q.Reference = m[1]
	}

	// Extract explanation: body after summary, stripping Format-A markers and 参照 line.
	explLines := make([]string, 0, len(detailsBody))
	for _, l := range detailsBody[bodyStart:] {
		trimmed := strings.TrimSpace(l)
		if trimmed == "" {
			explLines = append(explLines, "")
			continue
		}
		// Drop lines that only contain the bold **正解: ...** marker (already captured).
		if correctInBodyRe.MatchString(trimmed) && strings.HasPrefix(trimmed, "**正解") && strings.HasSuffix(trimmed, "**") {
			continue
		}
		// Drop the 参照 line (already captured).
		if referenceRe.MatchString(trimmed) {
			continue
		}
		explLines = append(explLines, l)
	}
	q.Explanation = strings.TrimSpace(collapseBlankLines(strings.Join(explLines, "\n")))

	return q, nil
}

func collapseBlankLines(s string) string {
	// Replace 3+ consecutive newlines with 2.
	re := regexp.MustCompile(`\n{3,}`)
	return re.ReplaceAllString(s, "\n\n")
}

func atoi(s string) int {
	n := 0
	for _, r := range s {
		if r < '0' || r > '9' {
			return 0
		}
		n = n*10 + int(r-'0')
	}
	return n
}

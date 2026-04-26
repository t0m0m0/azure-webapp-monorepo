import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loadDataset, type Question } from '../api/client';
import QuestionCard from '../components/QuestionCard';
import Timer from '../components/Timer';
import { recordExam, type ExamResult } from '../storage/progress';

const LIMIT_SEC = 30 * 60;

export default function MockExam() {
  const nav = useNavigate();
  const [questions, setQuestions] = useState<Question[] | null>(null);
  const [idx, setIdx] = useState(0);
  const [picks, setPicks] = useState<Record<string, string>>({});
  const [startedAt] = useState(() => Date.now());
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    loadDataset()
      .then((ds) => {
        const mock = ds.questions.filter((q) => ds.mockExam.includes(q.id));
        setQuestions(mock);
      })
      .catch((e) => setErr(String(e)));
  }, []);

  const submit = useCallback(() => {
    if (!questions) return;
    let correct = 0;
    const byDomain: ExamResult['byDomain'] = {};
    for (const q of questions) {
      const picked = picks[q.id];
      const ok = picked === q.answer;
      if (ok) correct++;
      // Mock questions have domain=0; keep a bucket anyway.
      const key = q.domain;
      byDomain[key] = byDomain[key] ?? { correct: 0, total: 0 };
      byDomain[key].total++;
      if (ok) byDomain[key].correct++;
    }
    const result: ExamResult = {
      id: `exam-${Date.now()}`,
      at: Date.now(),
      total: questions.length,
      correct,
      durationSec: Math.floor((Date.now() - startedAt) / 1000),
      byDomain,
      answers: picks,
    };
    recordExam(result);
    nav(`/exam/result/${result.id}`);
  }, [questions, picks, startedAt, nav]);

  const answeredCount = useMemo(() => Object.keys(picks).length, [picks]);

  if (err) return <div className="error">{err}</div>;
  if (!questions) return <div className="loading">読み込み中…</div>;
  if (questions.length === 0) return <div className="empty">模擬試験の問題がありません</div>;

  const current = questions[idx];
  const isLast = idx >= questions.length - 1;

  return (
    <div className="exam">
      <div className="exam-head">
        <h2>模擬試験</h2>
        <div className="exam-meta">
          <span>{idx + 1} / {questions.length}</span>
          <span>回答済 {answeredCount}/{questions.length}</span>
          <Timer startedAt={startedAt} limitSec={LIMIT_SEC} onExpire={submit} />
        </div>
      </div>

      <QuestionCard
        key={current.id}
        question={current}
        mode="exam"
        preselected={picks[current.id]}
        onPick={(k) => setPicks((p) => ({ ...p, [current.id]: k }))}
      />

      <div className="exam-nav">
        <button
          type="button"
          onClick={() => setIdx((i) => Math.max(0, i - 1))}
          disabled={idx === 0}
        >
          ← 前
        </button>
        <div className="question-jump">
          {questions.map((q, i) => (
            <button
              key={q.id}
              type="button"
              className={`jump ${i === idx ? 'active' : ''} ${picks[q.id] ? 'answered' : ''}`}
              onClick={() => setIdx(i)}
            >
              {i + 1}
            </button>
          ))}
        </div>
        {!isLast ? (
          <button type="button" onClick={() => setIdx((i) => i + 1)}>次 →</button>
        ) : (
          <button type="button" className="cta" onClick={submit}>採点する</button>
        )}
      </div>
    </div>
  );
}

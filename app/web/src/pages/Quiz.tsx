import { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { loadDataset, type Question } from '../api/client';
import QuestionCard from '../components/QuestionCard';
import { recordAttempt } from '../storage/progress';

export default function Quiz() {
  const { domain } = useParams<{ domain: string }>();
  const domainId = Number(domain);
  const [questions, setQuestions] = useState<Question[] | null>(null);
  const [idx, setIdx] = useState(0);
  const [stats, setStats] = useState({ correct: 0, answered: 0 });
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    loadDataset()
      .then((ds) => {
        const list = ds.questions
          .filter((q) => q.domain === domainId)
          .sort(() => Math.random() - 0.5);
        setQuestions(list);
        setIdx(0);
        setStats({ correct: 0, answered: 0 });
      })
      .catch((e) => setErr(String(e)));
  }, [domainId]);

  const domainTitle = useMemo(() => {
    return `Domain ${domainId}`;
  }, [domainId]);

  if (err) return <div className="error">{err}</div>;
  if (!questions) return <div className="loading">読み込み中…</div>;
  if (questions.length === 0) {
    return (
      <div className="empty">
        このドメインの問題が見つかりません。
        <Link to="/">ホームへ戻る</Link>
      </div>
    );
  }

  const current = questions[idx];
  const isLast = idx >= questions.length - 1;

  return (
    <div className="quiz">
      <div className="quiz-head">
        <h2>{domainTitle} クイズ</h2>
        <div className="quiz-progress">
          {idx + 1} / {questions.length} 問 (正答 {stats.correct}/{stats.answered})
        </div>
      </div>

      <QuestionCard
        key={current.id}
        question={current}
        mode="quiz"
        onAnswer={(correct) => {
          recordAttempt(current.id, correct);
          setStats((s) => ({
            correct: s.correct + (correct ? 1 : 0),
            answered: s.answered + 1,
          }));
        }}
      />

      <div className="quiz-nav">
        {!isLast ? (
          <button className="cta" onClick={() => setIdx((i) => i + 1)}>
            次の問題へ →
          </button>
        ) : (
          <>
            <div className="quiz-complete">
              お疲れさまでした。正答率 {stats.answered > 0
                ? Math.round((stats.correct / stats.answered) * 100)
                : 0}%
            </div>
            <Link to="/" className="cta">ホームへ戻る</Link>
          </>
        )}
      </div>
    </div>
  );
}

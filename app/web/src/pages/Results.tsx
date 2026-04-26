import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { loadDataset, type Dataset } from '../api/client';
import { load } from '../storage/progress';
import QuestionCard from '../components/QuestionCard';

export default function Results() {
  const { id } = useParams<{ id: string }>();
  const [data, setData] = useState<Dataset | null>(null);
  const progress = load();
  const exam = progress.exams.find((e) => e.id === id);

  useEffect(() => {
    loadDataset().then(setData);
  }, []);

  if (!exam) {
    return (
      <div className="error">
        結果が見つかりません (id={id})。<Link to="/">ホーム</Link>
      </div>
    );
  }
  if (!data) return <div className="loading">読み込み中…</div>;

  const pct = Math.round((exam.correct / exam.total) * 100);
  const passed = pct >= 70; // AZ-104 pass mark is 700/1000
  const mins = Math.floor(exam.durationSec / 60);
  const secs = exam.durationSec % 60;

  const wrong = data.questions.filter(
    (q) => data.mockExam.includes(q.id) && exam.answers[q.id] !== q.answer,
  );

  return (
    <div className="results">
      <h2>模擬試験結果</h2>
      <div className={`score ${passed ? 'pass' : 'fail'}`}>
        <div className="score-big">{exam.correct} / {exam.total}</div>
        <div className="score-pct">{pct}%</div>
        <div className="score-label">{passed ? '合格ライン到達' : '要復習'}</div>
      </div>
      <div className="exam-timing">
        所要時間: {mins}分{secs}秒 ・ 実施日時: {new Date(exam.at).toLocaleString('ja-JP')}
      </div>

      {wrong.length > 0 && (
        <>
          <h3>誤答した問題 ({wrong.length}問)</h3>
          <div className="wrong-list">
            {wrong.map((q) => (
              <QuestionCard
                key={q.id}
                question={q}
                mode="review"
                preselected={exam.answers[q.id]}
              />
            ))}
          </div>
        </>
      )}

      <div className="results-actions">
        <Link to="/exam" className="cta">もう一度受ける</Link>
        <Link to="/">ホームへ戻る</Link>
      </div>
    </div>
  );
}

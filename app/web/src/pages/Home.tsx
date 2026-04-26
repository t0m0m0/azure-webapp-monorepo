import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { loadDataset, type Dataset } from '../api/client';
import { domainStats, load as loadProgress, reset } from '../storage/progress';

export default function Home() {
  const [data, setData] = useState<Dataset | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const progress = loadProgress();

  useEffect(() => {
    loadDataset().then(setData).catch((e) => setErr(String(e)));
  }, []);

  if (err) return <div className="error">データ読込エラー: {err}</div>;
  if (!data) return <div className="loading">読み込み中…</div>;

  return (
    <div className="home">
      <h1>ドメイン別学習</h1>
      <p className="intro">
        AZ-104 の5ドメインについて、既存の練習問題を対話的に解けます。
        模擬試験はタイマー付き20問です。
      </p>
      <div className="domain-grid">
        {data.domains.map((d) => {
          const qs = data.questions.filter((q) => q.domain === d.id).map((q) => q.id);
          const stats = domainStats(progress, d.id, qs);
          const pct = stats.total > 0 ? Math.round((stats.correct / stats.total) * 100) : 0;
          return (
            <Link key={d.id} to={`/quiz/${d.id}`} className="domain-card">
              <div className="domain-card-head">
                <span className="domain-id">Domain {d.id}</span>
                <span className="domain-weight">{d.weight}</span>
              </div>
              <div className="domain-title">{d.title}</div>
              <div className="domain-stats">
                {stats.answered}/{stats.total} 問回答済 (最新正答率 {pct}%)
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${pct}%` }} />
              </div>
            </Link>
          );
        })}
      </div>

      <h2>模擬試験</h2>
      <p>
        20問・制限時間30分。実際のAZ-104試験の形式に近い混合出題です。
      </p>
      <Link to="/exam" className="cta">模擬試験を開始</Link>

      {progress.exams.length > 0 && (
        <>
          <h2>最近の模擬試験結果</h2>
          <ul className="exam-history">
            {progress.exams.slice(0, 5).map((e) => (
              <li key={e.id}>
                <Link to={`/exam/result/${e.id}`}>
                  {new Date(e.at).toLocaleString('ja-JP')} — {e.correct}/{e.total}
                  {' '}({Math.round((e.correct / e.total) * 100)}%)
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}

      <div className="reset-area">
        <button
          type="button"
          className="reset-btn"
          onClick={() => {
            if (confirm('学習進捗をすべて削除しますか？')) {
              reset();
              location.reload();
            }
          }}
        >
          進捗をリセット
        </button>
      </div>
    </div>
  );
}

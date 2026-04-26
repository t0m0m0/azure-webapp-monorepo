import { useState } from 'react';
import type { Question } from '../api/client';

type Props = {
  question: Question;
  /** Quiz: click option → immediate feedback, then locked. */
  mode?: 'quiz' | 'exam' | 'review';
  onAnswer?: (correct: boolean, picked: string) => void;
  /** Exam/Review: pre-selected option key. */
  preselected?: string;
  onPick?: (picked: string) => void;
};

export default function QuestionCard({
  question,
  mode = 'quiz',
  onAnswer,
  preselected,
  onPick,
}: Props) {
  const [picked, setPicked] = useState<string | undefined>(preselected);
  const [answered, setAnswered] = useState<boolean>(mode === 'review');

  const handlePick = (key: string) => {
    if (mode === 'review') return;
    if (mode === 'quiz' && answered) return;
    setPicked(key);
    if (mode === 'exam') {
      onPick?.(key);
      return;
    }
    // quiz mode: lock and reveal
    setAnswered(true);
    onAnswer?.(key === question.answer, key);
  };

  const showResult = (mode === 'quiz' && answered) || mode === 'review';
  const locked = showResult;

  return (
    <article className="question">
      <div className="question-meta">
        <span className="domain-chip">
          {question.domain === 0 ? '模擬試験' : `ドメイン${question.domain}`}
        </span>
        <span className="question-number">問題 {question.number}</span>
      </div>
      <h3 className="question-text">{question.text}</h3>
      <ul className="options">
        {question.options.map((opt) => {
          const isPicked = picked === opt.key;
          const isCorrect = opt.key === question.answer;
          let cls = 'option';
          if (isPicked) cls += ' picked';
          if (showResult && isCorrect) cls += ' correct';
          if (showResult && isPicked && !isCorrect) cls += ' wrong';
          return (
            <li key={opt.key}>
              <button
                type="button"
                className={cls}
                onClick={() => handlePick(opt.key)}
                disabled={locked}
              >
                <span className="option-key">{opt.key})</span>
                <span className="option-text">{opt.text}</span>
              </button>
            </li>
          );
        })}
      </ul>
      {showResult && (
        <div className={`explanation ${picked === question.answer ? 'ok' : 'ng'}`}>
          <div className="verdict">
            {picked === question.answer ? '✓ 正解' : `✗ 不正解 (正答: ${question.answer})`}
          </div>
          <pre className="explanation-body">{question.explanation}</pre>
          {question.reference && (
            <div className="reference">参照: <code>{question.reference}</code></div>
          )}
        </div>
      )}
    </article>
  );
}

const KEY = 'az104-progress-v1';

export type Attempt = { correct: boolean; at: number };

export type ExamResult = {
  id: string;
  at: number;
  total: number;
  correct: number;
  durationSec: number;
  byDomain: Record<number, { correct: number; total: number }>;
  answers: Record<string, string>; // questionId -> user's picked option key
};

export type Progress = {
  attempts: Record<string, Attempt[]>; // questionId -> history
  exams: ExamResult[];
};

const empty: Progress = { attempts: {}, exams: [] };

export function load(): Progress {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...empty };
    const parsed = JSON.parse(raw) as Progress;
    return { attempts: parsed.attempts ?? {}, exams: parsed.exams ?? [] };
  } catch {
    return { ...empty };
  }
}

export function save(p: Progress): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(p));
  } catch {
    // storage full / disabled — silently ignore
  }
}

export function recordAttempt(questionId: string, correct: boolean): Progress {
  const p = load();
  const list = p.attempts[questionId] ?? [];
  list.push({ correct, at: Date.now() });
  p.attempts[questionId] = list;
  save(p);
  return p;
}

export function recordExam(result: ExamResult): Progress {
  const p = load();
  p.exams = [result, ...p.exams].slice(0, 20);
  save(p);
  return p;
}

export function domainStats(p: Progress, domain: number, questionIds: string[]) {
  let answered = 0;
  let correct = 0;
  for (const id of questionIds) {
    const attempts = p.attempts[id];
    if (!attempts || attempts.length === 0) continue;
    answered++;
    const last = attempts[attempts.length - 1];
    if (last.correct) correct++;
  }
  return { domain, answered, total: questionIds.length, correct };
}

export function reset(): void {
  localStorage.removeItem(KEY);
}

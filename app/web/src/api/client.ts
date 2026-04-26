export type Option = { key: string; text: string };

export type Question = {
  id: string;
  domain: number;
  number: number;
  text: string;
  options: Option[];
  answer: string;
  explanation: string;
  reference?: string;
};

export type Domain = {
  id: number;
  title: string;
  weight: string;
  summary?: string;
};

export type Dataset = {
  domains: Domain[];
  questions: Question[];
  mockExam: string[];
};

let cache: Promise<Dataset> | null = null;

export function loadDataset(): Promise<Dataset> {
  if (!cache) {
    cache = fetch('/api/questions')
      .then((r) => {
        if (!r.ok) throw new Error(`questions ${r.status}`);
        return r.json() as Promise<Dataset>;
      })
      .catch((err) => {
        cache = null;
        throw err;
      });
  }
  return cache;
}

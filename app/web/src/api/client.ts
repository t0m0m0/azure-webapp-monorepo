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

export type StudyDomain = {
  id: number;
  title: string;
  infra_refs: string[];
};

export type StudyDomainContent = {
  id: number;
  title: string;
  content: string;
  infra_refs: string[];
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

let studyListCache: Promise<{ domains: StudyDomain[] }> | null = null;

export function loadStudyList(): Promise<{ domains: StudyDomain[] }> {
  if (!studyListCache) {
    studyListCache = fetch('/api/study')
      .then((r) => {
        if (!r.ok) throw new Error(`study ${r.status}`);
        return r.json() as Promise<{ domains: StudyDomain[] }>;
      })
      .catch((err) => {
        studyListCache = null;
        throw err;
      });
  }
  return studyListCache;
}

const studyDomainCache = new Map<number, Promise<StudyDomainContent>>();

export function loadStudyDomain(id: number): Promise<StudyDomainContent> {
  if (!studyDomainCache.has(id)) {
    const p = fetch(`/api/study/${id}`)
      .then((r) => {
        if (!r.ok) throw new Error(`study/${id} ${r.status}`);
        return r.json() as Promise<StudyDomainContent>;
      })
      .catch((err) => {
        studyDomainCache.delete(id);
        throw err;
      });
    studyDomainCache.set(id, p);
  }
  return studyDomainCache.get(id)!;
}

const infraCache = new Map<string, Promise<{ filename: string; content: string }>>();

export function loadInfraFile(filename: string): Promise<{ filename: string; content: string }> {
  if (!infraCache.has(filename)) {
    const p = fetch(`/api/infra/${filename}`)
      .then((r) => {
        if (!r.ok) throw new Error(`infra/${filename} ${r.status}`);
        return r.json() as Promise<{ filename: string; content: string }>;
      })
      .catch((err) => {
        infraCache.delete(filename);
        throw err;
      });
    infraCache.set(filename, p);
  }
  return infraCache.get(filename)!;
}

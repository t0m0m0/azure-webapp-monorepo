import { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { marked } from 'marked';
import {
  loadStudyList,
  loadStudyDomain,
  loadInfraFile,
  type StudyDomain,
  type StudyDomainContent,
} from '../api/client';

marked.use({ gfm: true, breaks: false });

function slugify(text: string): string {
  return text
    .replace(/<[^>]+>/g, '')
    .trim()
    .replace(/[\s　]+/g, '-')
    .replace(/[^\w　-鿿-]/g, '');
}

function renderMarkdown(md: string): string {
  const html = marked.parse(md, { async: false }) as string;
  return html.replace(/<h([23])>(.*?)<\/h\1>/g, (_, level, inner) => {
    const id = slugify(inner);
    return `<h${level} id="${id}">${inner}</h${level}>`;
  });
}

type TocEntry = { title: string; anchor: string };

function extractToc(md: string): TocEntry[] {
  return [...md.matchAll(/^## (.+)$/gm)].map((m) => ({
    title: m[1].trim(),
    anchor: slugify(m[1].trim()),
  }));
}

export default function StudyContent() {
  const { domainId } = useParams<{ domainId: string }>();
  const id = Number(domainId) || 1;

  const [domains, setDomains] = useState<StudyDomain[]>([]);
  const [content, setContent] = useState<StudyDomainContent | null>(null);
  const [infraContents, setInfraContents] = useState<Record<string, string>>({});
  const [openFile, setOpenFile] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    loadStudyList()
      .then((d) => setDomains(d.domains))
      .catch((e) => setErr(String(e)));
  }, []);

  useEffect(() => {
    setContent(null);
    setOpenFile(null);
    setErr(null);
    loadStudyDomain(id)
      .then(setContent)
      .catch((e) => setErr(String(e)));
  }, [id]);

  const html = useMemo(() => (content ? renderMarkdown(content.content) : ''), [content]);
  const toc = useMemo(() => (content ? extractToc(content.content) : []), [content]);

  const toggleInfraFile = async (filename: string) => {
    if (openFile === filename) {
      setOpenFile(null);
      return;
    }
    setOpenFile(filename);
    if (!infraContents[filename]) {
      try {
        const result = await loadInfraFile(filename);
        setInfraContents((prev) => ({ ...prev, [filename]: result.content }));
      } catch {
        setInfraContents((prev) => ({ ...prev, [filename]: '(読み込みエラー)' }));
      }
    }
  };

  return (
    <div className="study-page">
      <aside className="study-sidebar">
        <p className="sidebar-section-label">ドメイン</p>
        {domains.map((d) => (
          <Link
            key={d.id}
            to={`/study/${d.id}`}
            className={`sidebar-domain-link ${d.id === id ? 'active' : ''}`}
          >
            <span className="sidebar-domain-num">Domain {d.id}</span>
            <span className="sidebar-domain-name">{d.title}</span>
          </Link>
        ))}

        {toc.length > 0 && (
          <>
            <p className="sidebar-section-label" style={{ marginTop: '1.25rem' }}>目次</p>
            {toc.map((s) => (
              <a key={s.anchor} href={`#${s.anchor}`} className="sidebar-toc-link">
                {s.title}
              </a>
            ))}
          </>
        )}
      </aside>

      <div className="study-main">
        {err && <div className="error">読込エラー: {err}</div>}
        {!content && !err && <div className="loading">読み込み中…</div>}
        {content && (
          <>
            <h1 className="study-domain-heading">
              Domain {content.id}: {content.title}
            </h1>

            <div
              className="markdown-body"
              // content is generated from our own controlled study guide — not user input
              dangerouslySetInnerHTML={{ __html: html }}
            />

            {content.infra_refs.length > 0 && (
              <section className="infra-section">
                <h2 className="infra-section-title">関連 Terraform ファイル</h2>
                <p className="infra-section-desc">
                  このドメインの学習内容で参照されている実際の Terraform コードを確認できます。
                </p>
                {content.infra_refs.map((filename) => (
                  <div key={filename} className="infra-file">
                    <button
                      type="button"
                      className="infra-toggle"
                      onClick={() => toggleInfraFile(filename)}
                    >
                      <span className="infra-filename">📄 {filename}</span>
                      <span className="infra-chevron">{openFile === filename ? '▲' : '▼'}</span>
                    </button>
                    {openFile === filename && (
                      <pre className="infra-code">
                        <code>{infraContents[filename] ?? '読み込み中…'}</code>
                      </pre>
                    )}
                  </div>
                ))}
              </section>
            )}
          </>
        )}
      </div>
    </div>
  );
}

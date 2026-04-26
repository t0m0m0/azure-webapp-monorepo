import { Link, Route, Routes } from 'react-router-dom';
import Home from './pages/Home';
import Quiz from './pages/Quiz';
import MockExam from './pages/MockExam';
import Results from './pages/Results';

export default function App() {
  return (
    <div className="app">
      <header className="app-header">
        <Link to="/" className="logo">AZ-104 学習アプリ</Link>
        <nav>
          <Link to="/">ホーム</Link>
          <Link to="/exam">模擬試験</Link>
        </nav>
      </header>
      <main className="app-main">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/quiz/:domain" element={<Quiz />} />
          <Route path="/exam" element={<MockExam />} />
          <Route path="/exam/result/:id" element={<Results />} />
          <Route path="*" element={<Home />} />
        </Routes>
      </main>
      <footer className="app-footer">
        学習進捗はブラウザのlocalStorageに保存されます
      </footer>
    </div>
  );
}

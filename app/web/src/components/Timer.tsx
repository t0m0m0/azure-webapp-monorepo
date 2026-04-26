import { useEffect, useState } from 'react';

type Props = {
  startedAt: number;
  limitSec: number;
  onExpire: () => void;
};

export default function Timer({ startedAt, limitSec, onExpire }: Props) {
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  const elapsed = Math.floor((now - startedAt) / 1000);
  const remaining = Math.max(0, limitSec - elapsed);

  useEffect(() => {
    if (remaining === 0) onExpire();
  }, [remaining, onExpire]);

  const mm = Math.floor(remaining / 60);
  const ss = remaining % 60;
  const warn = remaining < 60;

  return (
    <div className={`timer ${warn ? 'warn' : ''}`}>
      残り {mm}:{ss.toString().padStart(2, '0')}
    </div>
  );
}

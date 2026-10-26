import { useEffect, useMemo, useState } from 'react';
import { confidence } from '../domain/fusion';
import { fetchAlerts, fetchModelCard, type Alert, type ContextWithConfig, type ModelCard } from '../infrastructure/dataClient';
import { pct } from './format';

const REPO = (import.meta.env.VITE_REPO_URL as string | undefined)?.replace(/\/$/, '');
const TAU: Record<string, number> = { gbfs: 30, weather: 360, air: 180, traffic: 45 };
const SOURCE_LABEL: Record<string, string> = { gbfs: 'BiciMAD (GBFS)', weather: 'Meteorología (Open-Meteo)', air: 'Calidad del aire (NO₂)', traffic: 'Tráfico (informo)' };

function issueUrl(a: Alert): string | null {
  return REPO ? `${REPO}/issues?q=${encodeURIComponent(`label:"alert:${a.id}"`)}` : null;
}

function editUrl(file: string): string | null {
  return REPO ? `${REPO}/edit/main/config/${file}` : null;
}

function LinkOr({ href, label, fallback, ghost }: { href: string | null; label: string; fallback?: string; ghost?: boolean }) {
  if (!href) return fallback ? <span className="muted small">{fallback}</span> : null;
  return <a className={ghost ? 'btn ghost' : 'btn'} href={href} target="_blank" rel="noreferrer">{label}</a>;
}

function DemandChart({ days }: { days: { date: string; p10: number; p50: number; p90: number }[] }) {
  const w = 320;
  const h = 120;
  const max = Math.max(...days.map((d) => d.p90)) * 1.05;
  const x = (i: number) => 24 + (i * (w - 36)) / Math.max(1, days.length - 1);
  const y = (v: number) => h - 18 - (v / max) * (h - 30);
  const band = [...days.map((d, i) => `${x(i)},${y(d.p90)}`), ...days.map((_, i) => `${x(days.length - 1 - i)},${y(days[days.length - 1 - i].p10)}`)].join(' ');
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="chart" role="img" aria-label="Previsión de viajes BiciMAD, 7 días, con intervalo P10–P90">
      <polygon points={band} fill="var(--blue10)" />
      <polyline points={days.map((d, i) => `${x(i)},${y(d.p50)}`).join(' ')} fill="none" stroke="var(--blue)" strokeWidth="2" />
      {days.map((d, i) => (
        <g key={d.date}>
          <circle cx={x(i)} cy={y(d.p50)} r="2.5" fill="var(--blue)" />
          <text x={x(i)} y={h - 4} fontSize="8" textAnchor="middle" fill="var(--grey6)">{d.date.slice(5)}</text>
        </g>
      ))}
    </svg>
  );
}

export function OpsConsole({ ctx }: { ctx: ContextWithConfig | null }) {
  const [alerts, setAlerts] = useState<Alert[] | null>(null);
  const [card, setCard] = useState<ModelCard | null>(null);
  const [simP, setSimP] = useState(ctx?.thresholds.station_empty_alert?.value ?? 0.15);

  useEffect(() => {
    fetchAlerts().then((a) => setAlerts(a.alerts)).catch(() => setAlerts([]));
    fetchModelCard().then(setCard).catch(() => setCard(null));
  }, []);

  const simulated = useMemo(() => {
    if (!ctx) return 0;
    const s = ctx.stations;
    return s.id.filter((_, i) => s.renting[i] === 1 && s.p_bike_30[i] < simP).length;
  }, [ctx, simP]);

  if (!ctx) return <p className="pad">Sin datos de contexto.</p>;
  const minStations = 5;
  const m = card?.metrics;

  return (
    <div className="ops pad">
      <p className="hint">
        Consola de solo lectura. El sistema <strong>propone</strong>; el técnico <strong>decide</strong> en GitHub
        (etiquetas en la Issue y Pull Request sobre <code>config/</code>). Nada se aplica automáticamente.
      </p>

      <h3>Fuentes de datos</h3>
      <table className="table">
        <thead><tr><th>Fuente</th><th>Estado</th><th>Antigüedad</th><th>Confianza</th></tr></thead>
        <tbody>
          {Object.entries(ctx.sources).map(([k, s]) => (
            <tr key={k}>
              <td>{SOURCE_LABEL[k] ?? k}</td>
              <td className={s.ok ? 'ok' : 'risk'}>{s.ok ? 'OK' : 'Caída'}</td>
              <td>{s.age_min === null ? '—' : `${Math.round(s.age_min)} min`}</td>
              <td>{pct(confidence(s, TAU[k] ?? 60))}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="muted small">Contexto generado: {new Date(ctx.generated).toLocaleString('es-ES')}. La confianza decae con la antigüedad (fusión ponderada).</p>

      <h3>Alertas ({alerts?.length ?? '…'})</h3>
      {alerts?.length === 0 && <p className="muted">Sin alertas: ningún indicador supera su umbral.</p>}
      {alerts?.map((a) => (
        <article key={a.id} className={`alert sev-${a.severity}`}>
          <header><span className="sev">{a.severity}</span> <strong>{a.title}</strong></header>
          <p>{a.detail}</p>
          <p className="small">Indicador <code>{a.key}</code> = {a.value} · umbral {a.threshold}</p>
          <p className="small"><strong>Acción sugerida (no aplicada):</strong> {a.suggested_action}</p>
          <div className="actions">
            <LinkOr href={issueUrl(a)} label="Decidir en la Issue" fallback="Configure VITE_REPO_URL para enlazar Issues" />
            <LinkOr href={editUrl('overrides.yaml')} label="Proponer cambio (PR)" ghost />
          </div>
        </article>
      ))}

      <h3>Umbrales vigentes</h3>
      <table className="table">
        <thead><tr><th>Umbral</th><th>Tipo</th><th>Valor</th></tr></thead>
        <tbody>
          {Object.entries(ctx.thresholds).map(([k, t]) => (
            <tr key={k} title={t.description}>
              <td><code>{k}</code></td>
              <td>{t.kind === 'alert' ? 'Alerta → técnico' : 'Aviso al usuario'}</td>
              <td>{t.value}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="sim">
        <h4>Simulador «qué pasaría si» (local, no aplica cambios)</h4>
        <label htmlFor="simp">P(bici a 30 min) mínima por estación: <strong>{simP.toFixed(2)}</strong></label>
        <input id="simp" type="range" min="0.05" max="0.6" step="0.01" value={simP} onChange={(e) => setSimP(Number(e.target.value))} />
        <p>
          Con este valor, <strong>{simulated}</strong> estaciones quedarían por debajo →{' '}
          {simulated >= minStations ? <span className="risk">se generaría alerta</span> : <span className="ok">no se generaría alerta</span>} (mín. {minStations}).
        </p>
        <LinkOr href={editUrl('thresholds.yaml')} label="Proponer este umbral (PR)" ghost />
      </div>

      <h3>Previsión de demanda BiciMAD</h3>
      {ctx.demand.ok && ctx.demand.days ? (
        <>
          <p>Hoy: <strong>{ctx.demand.p50?.toLocaleString('es-ES')}</strong> viajes (P10–P90: {ctx.demand.p10?.toLocaleString('es-ES')}–{ctx.demand.p90?.toLocaleString('es-ES')}) · presión {ctx.pressure.toFixed(2)}</p>
          <DemandChart days={ctx.demand.days} />
        </>
      ) : <p className="muted">Previsión no disponible.</p>}
      {m && (
        <table className="table">
          <thead><tr><th>Métrica (backtesting, 6 meses)</th><th>Valor</th></tr></thead>
          <tbody>
            <tr><td>MAE modelo (viajes/día)</td><td>{Math.round(m.mae_model).toLocaleString('es-ES')}</td></tr>
            <tr><td>MAE climatología</td><td>{Math.round(m.mae_climatology).toLocaleString('es-ES')}</td></tr>
            <tr><td>MAE naïve estacional (cota con lags)</td><td>{Math.round(m.mae_seasonal_naive).toLocaleString('es-ES')}</td></tr>
            <tr><td>Cobertura P10–P90 (objetivo 80 %)</td><td>{pct(m.coverage_80_conformal)} (sin calibrar {pct(m.coverage_80_raw)})</td></tr>
          </tbody>
        </table>
      )}
      <h4>Deriva de datos (PSI)</h4>
      <table className="table">
        <tbody>
          {Object.entries(ctx.drift_psi).map(([f, v]) => (
            <tr key={f}><td>{f}</td><td className={v > (ctx.thresholds.drift_psi_alert?.value ?? 0.2) ? 'risk' : 'ok'}>{v.toFixed(2)}</td></tr>
          ))}
        </tbody>
      </table>
      {card && <p className="muted small">Modelo {card.name} · {card.method} · entrenado {card.training_range.join(' → ')} · promoción: {card.promotion}</p>}
    </div>
  );
}

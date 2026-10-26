import { legMode } from '../domain/emissions';
import type { RankedJourney } from '../domain/ranking';
import type { NetworkData } from '../domain/types';
import { euros, grams, hhmm, legTitle, minutes, MODE_COLOR, MODE_LABEL, pct, textOn } from './format';

const BADGE: Record<RankedJourney['badges'][number], string> = {
  fastest: 'Más rápida',
  cheapest: 'Más barata',
  greenest: 'Menos CO₂',
  reliable: 'Más fiable',
};

interface Props {
  item: RankedJourney;
  rank: number;
  network: NetworkData;
  selected: boolean;
  onSelect: () => void;
}

export function JourneyCard({ item, rank, network, selected, onSelect }: Props) {
  const { journey: j, assessment: a } = item;
  const saving = Math.max(0, j.carCo2g - j.co2g);
  const relClass = a.reliability >= 0.8 ? 'ok' : a.reliability >= 0.5 ? 'warn' : 'risk';
  return (
    <article className={`card ${selected ? 'selected' : ''}`} aria-labelledby={`j${rank}`}>
      <button className="card-head" onClick={onSelect} aria-expanded={selected}>
        <div className="card-title" id={`j${rank}`}>
          <span className="rank">{rank}</span>
          <strong>{hhmm(j.dep)} → {hhmm(j.arr)}</strong>
          <span className="muted">· {minutes(j.arr - j.dep)}</span>
        </div>
        <div className="modes" aria-label="Modos">
          {j.legs.filter((l) => !(l.kind === 'walk' && l.arr - l.dep < 120)).map((l, i) => {
            const mode = legMode(l);
            const label = l.kind === 'ride' ? network.routes[l.route].short : MODE_LABEL[mode];
            const color = l.kind === 'ride' ? network.routes[l.route].color : MODE_COLOR[mode];
            return <span key={i} className="mode" style={{ background: color, color: textOn(color) }} title={MODE_LABEL[mode]}>{label}</span>;
          })}
        </div>
        <dl className="metrics">
          <div><dt>Coste</dt><dd>{euros(j.costCents)}</dd></div>
          <div><dt>Emisiones</dt><dd>{grams(j.co2g)} CO₂e</dd></div>
          <div><dt>Fiabilidad</dt><dd className={relClass}>{pct(a.reliability)}</dd></div>
          <div><dt>Esperado</dt><dd>{minutes(a.expectedDurationS)}</dd></div>
        </dl>
        <div className="badges">
          {item.badges.map((b) => <span key={b} className={`badge ${b}`}>{BADGE[b]}</span>)}
          {a.bikeRisk && <span className="badge risk">Bici poco fiable</span>}
          {saving > 0 && <span className="badge saving">−{grams(saving)} vs coche</span>}
        </div>
      </button>
      {selected && (
        <div className="card-body">
          <ol className="legs">
            {j.legs.map((l, i) => (
              <li key={i} style={{ borderColor: l.kind === 'ride' ? network.routes[l.route].color : MODE_COLOR[legMode(l)] }}>
                <span className="time">{hhmm(l.dep)}</span> {legTitle(l, network)} <span className="muted">({minutes(l.arr - l.dep)})</span>
              </li>
            ))}
          </ol>
          {a.factors.length > 0 && (
            <>
              <h4>Por qué (fusión de datos)</h4>
              <ul className="factors">
                {a.factors.map((f, i) => (
                  <li key={i} className={f.impact < 0 ? 'neg' : 'pos'}>
                    <strong>{f.source}:</strong> {f.text} <span className="muted">· confianza {pct(f.confidence)}</span>
                  </li>
                ))}
              </ul>
            </>
          )}
          <p className="muted small">Confort de tramos activos: {pct(a.comfort)} · Coste según perfil tarifario seleccionado.</p>
        </div>
      )}
    </article>
  );
}

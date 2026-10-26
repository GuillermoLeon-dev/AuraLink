import { useState } from 'react';
import { secondsSinceMidnight, usePlanner } from '../application/usePlanner';
import type { LatLon, Place } from '../domain/types';
import { JourneyCard } from './JourneyCard';
import { MapView } from './MapView';
import { OpsConsole } from './OpsConsole';
import { PlannerPanel } from './PlannerPanel';
import { PrivacyBanner, PrivacyDetails } from './PrivacyNotice';

type Tab = 'plan' | 'ops' | 'privacy';

const pickedPlace = (p: LatLon, label: string): Place => ({ ...p, label });

export function App() {
  const planner = usePlanner();
  const [tab, setTab] = useState<Tab>('plan');
  const [origin, setOrigin] = useState<Place | null>(null);
  const [dest, setDest] = useState<Place | null>(null);
  const [departure, setDeparture] = useState(() => Math.ceil(secondsSinceMidnight() / 300) * 300);
  const [fareProfile, setFareProfile] = useState('single');
  const [selected, setSelected] = useState(0);
  const [showStations, setShowStations] = useState(false);

  const onPick = (p: LatLon) => {
    if (tab !== 'plan') return;
    if (!origin || (origin && dest)) {
      setOrigin(pickedPlace(p, 'Punto en el mapa (origen)'));
      setDest(null);
      planner.clear();
    } else {
      setDest(pickedPlace(p, 'Punto en el mapa (destino)'));
    }
  };

  const submit = () => {
    if (!origin || !dest) return;
    setSelected(0);
    void planner.plan({ origin, dest, departure, fareProfile });
  };

  const selectedJourney = planner.ranked[selected]?.journey ?? null;
  const network = planner.network;

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="logo" aria-hidden="true">A</span>
          <span><strong>Aura Link</strong> <span className="muted">· rutas multimodales sostenibles · Madrid</span></span>
        </div>
        <nav aria-label="Secciones">
          {(['plan', 'ops', 'privacy'] as Tab[]).map((t) => (
            <button key={t} className={tab === t ? 'tab active' : 'tab'} onClick={() => setTab(t)} aria-current={tab === t}>
              {{ plan: 'Planificar', ops: 'Consola técnica', privacy: 'Privacidad' }[t]}
            </button>
          ))}
        </nav>
      </header>

      <main className="layout">
        <section className="side" aria-live="polite">
          {planner.state === 'loading' && <p className="pad">Cargando red de transporte…</p>}
          {planner.state === 'error' && <p className="pad error">No se pudo cargar la red: {planner.error}</p>}
          {planner.state === 'ready' && network && tab === 'plan' && planner.ctx && (
            <>
              <PlannerPanel
                network={network}
                fareProfiles={planner.ctx.config.fares.profiles}
                origin={origin}
                dest={dest}
                setOrigin={setOrigin}
                setDest={setDest}
                departure={departure}
                setDeparture={setDeparture}
                fareProfile={fareProfile}
                setFareProfile={setFareProfile}
                preference={planner.preference}
                setPreference={planner.setPreference}
                onSubmit={submit}
                busy={planner.busy}
              />
              {planner.ctx.notices.map((n) => <p key={n.key} className="notice">{n.message}</p>)}
              {planner.results && (
                <div className="results">
                  <p className="muted small pad-x">
                    {planner.ranked.length} alternativas no dominadas (tiempo · coste · CO₂) en {Math.round(planner.results.ms)} ms, calculadas en tu dispositivo.
                  </p>
                  {planner.ranked.length === 0 && <p className="pad">No hay alternativas a esa hora. Pruebe otra hora o puntos más cercanos a la red.</p>}
                  {planner.ranked.map((item, i) => (
                    <JourneyCard key={i} item={item} rank={i + 1} network={network} selected={i === selected} onSelect={() => setSelected(i)} />
                  ))}
                </div>
              )}
            </>
          )}
          {tab === 'ops' && <OpsConsole ctx={planner.ctx} />}
          {tab === 'privacy' && <PrivacyDetails />}
        </section>
        <section className="mapwrap">
          <MapView
            network={planner.network}
            ctx={planner.ctx}
            journey={tab === 'plan' ? selectedJourney : null}
            origin={origin}
            dest={dest}
            showStations={showStations || tab === 'ops'}
            onPick={onPick}
          />
          <label className="map-toggle">
            <input type="checkbox" checked={showStations} onChange={(e) => setShowStations(e.target.checked)} /> Estaciones BiciMAD (P. bici a 30 min)
          </label>
        </section>
      </main>
      <PrivacyBanner onMore={() => setTab('privacy')} />
    </div>
  );
}

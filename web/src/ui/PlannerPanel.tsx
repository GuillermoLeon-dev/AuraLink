import { useMemo, useState } from 'react';
import { PREFERENCES, type Preference } from '../domain/ranking';
import type { NetworkData, Place } from '../domain/types';
import { hhmm } from './format';

interface Props {
  network: NetworkData;
  fareProfiles: Record<string, { label: string }>;
  origin: Place | null;
  dest: Place | null;
  setOrigin: (p: Place | null) => void;
  setDest: (p: Place | null) => void;
  departure: number;
  setDeparture: (s: number) => void;
  fareProfile: string;
  setFareProfile: (f: string) => void;
  preference: Preference;
  setPreference: (p: Preference) => void;
  onSubmit: () => void;
  busy: boolean;
}

/** Índice local de lugares (paradas y estaciones): la búsqueda no sale del navegador. */
function usePlaceIndex(net: NetworkData): Map<string, Place> {
  return useMemo(() => {
    const idx = new Map<string, Place>();
    net.stops.name.forEach((name, i) => {
      const feed = net.stops.id[i].split(':')[0];
      const label = `${name} (${feed === 'emt' ? 'bus' : feed === 'ml' ? 'Metro Ligero' : 'Metro'})`;
      if (!idx.has(label)) idx.set(label, { lat: net.stops.lat[i], lon: net.stops.lon[i], label: name });
    });
    net.bike.name.forEach((name, i) => idx.set(`${name} (BiciMAD)`, { lat: net.bike.lat[i], lon: net.bike.lon[i], label: name }));
    return idx;
  }, [net]);
}

function PlaceField({ id, label, value, onChange, index }: { id: string; label: string; value: Place | null; onChange: (p: Place | null) => void; index: Map<string, Place> }) {
  const [text, setText] = useState('');
  const shown = value ? value.label : text;
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        list={`${id}-list`}
        value={shown}
        placeholder="Parada, estación o pulse en el mapa"
        autoComplete="off"
        onChange={(e) => {
          const p = index.get(e.target.value);
          if (p) onChange(p);
          else {
            onChange(null);
            setText(e.target.value);
          }
        }}
      />
      <datalist id={`${id}-list`}>
        {text.length >= 2 &&
          [...index.keys()]
            .filter((k) => k.toLowerCase().includes(text.toLowerCase()))
            .slice(0, 30)
            .map((k) => <option key={k} value={k} />)}
      </datalist>
    </div>
  );
}

export function PlannerPanel(props: Props) {
  const index = usePlaceIndex(props.network);
  const [geoError, setGeoError] = useState<string | null>(null);

  const useMyLocation = () => {
    setGeoError(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => props.setOrigin({ lat: pos.coords.latitude, lon: pos.coords.longitude, label: 'Mi ubicación' }),
      () => setGeoError('No se pudo obtener la ubicación (permiso denegado o no disponible).'),
      { enableHighAccuracy: false, maximumAge: 60_000, timeout: 10_000 },
    );
  };

  return (
    <form
      className="planner"
      onSubmit={(e) => {
        e.preventDefault();
        props.onSubmit();
      }}
    >
      <PlaceField id="origin" label="Origen" value={props.origin} onChange={props.setOrigin} index={index} />
      <button type="button" className="link" onClick={useMyLocation}>
        Usar mi ubicación (se procesa solo en este dispositivo)
      </button>
      {geoError && <p className="hint error">{geoError}</p>}
      <PlaceField id="dest" label="Destino" value={props.dest} onChange={props.setDest} index={index} />
      <div className="row">
        <div className="field">
          <label htmlFor="time">Salida</label>
          <input
            id="time"
            type="time"
            value={hhmm(props.departure)}
            onChange={(e) => {
              const [h, m] = e.target.value.split(':').map(Number);
              props.setDeparture(h * 3600 + m * 60);
            }}
          />
        </div>
        <div className="field">
          <label htmlFor="fare">Billete</label>
          <select id="fare" value={props.fareProfile} onChange={(e) => props.setFareProfile(e.target.value)}>
            {Object.entries(props.fareProfiles).map(([k, v]) => (
              <option key={k} value={k}>{v.label}</option>
            ))}
          </select>
        </div>
      </div>
      <fieldset className="prefs">
        <legend>Prioridad</legend>
        {(Object.keys(PREFERENCES) as Preference[]).map((p) => (
          <label key={p} className={props.preference === p ? 'chip active' : 'chip'}>
            <input type="radio" name="pref" value={p} checked={props.preference === p} onChange={() => props.setPreference(p)} />
            {PREFERENCES[p].label}
          </label>
        ))}
      </fieldset>
      <button type="submit" className="primary" disabled={!props.origin || !props.dest || props.busy}>
        {props.busy ? 'Calculando…' : 'Buscar rutas'}
      </button>
      <p className="hint">Horarios de un día laborable tipo (GTFS). Pulse en el mapa: primero origen, luego destino.</p>
    </form>
  );
}

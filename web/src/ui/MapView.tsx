import maplibregl, { type GeoJSONSource, type Map as MlMap } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useEffect, useRef } from 'react';
import { legMode } from '../domain/emissions';
import type { ContextData } from '../domain/fusion';
import type { Journey, LatLon, NetworkData, Place } from '../domain/types';
import { MODE_COLOR } from './format';

/** Estilo vectorial abierto sin claves ni cookies (OpenFreeMap, datos © OpenStreetMap). */
const STYLE_URL = 'https://tiles.openfreemap.org/styles/positron';
const MADRID: [number, number] = [-3.7038, 40.4168];

interface Props {
  network: NetworkData | null;
  ctx: ContextData | null;
  journey: Journey | null;
  origin: Place | null;
  dest: Place | null;
  showStations: boolean;
  onPick: (p: LatLon) => void;
}

const emptyFc = (): GeoJSON.FeatureCollection => ({ type: 'FeatureCollection', features: [] });

function journeyGeoJson(j: Journey, net: NetworkData): GeoJSON.FeatureCollection {
  const features: GeoJSON.Feature[] = j.legs.map((leg) => {
    let coords: [number, number][];
    if (leg.kind === 'ride') {
      const p = net.patterns[leg.pattern];
      coords = p.s.slice(leg.boardPos, leg.alightPos + 1).map((s) => [net.stops.lon[s], net.stops.lat[s]]);
    } else if (leg.kind === 'bike') {
      coords = [
        [net.bike.lon[leg.fromStation], net.bike.lat[leg.fromStation]],
        [net.bike.lon[leg.toStation], net.bike.lat[leg.toStation]],
      ];
    } else {
      coords = [[leg.from.lon, leg.from.lat], [leg.to.lon, leg.to.lat]];
    }
    const mode = legMode(leg);
    return {
      type: 'Feature',
      properties: { color: leg.kind === 'ride' ? net.routes[leg.route].color : MODE_COLOR[mode], dashed: leg.kind === 'walk' ? 1 : 0 },
      geometry: { type: 'LineString', coordinates: coords },
    };
  });
  return { type: 'FeatureCollection', features };
}

function stationsGeoJson(net: NetworkData, ctx: ContextData | null): GeoJSON.FeatureCollection {
  const p = new Map<string, number>();
  ctx?.stations.id.forEach((id, i) => p.set(id, ctx.stations.p_bike_30[i]));
  return {
    type: 'FeatureCollection',
    features: net.bike.id.map((id, i) => ({
      type: 'Feature',
      properties: { p: p.get(id) ?? -1, name: net.bike.name[i] },
      geometry: { type: 'Point', coordinates: [net.bike.lon[i], net.bike.lat[i]] },
    })),
  };
}

export function MapView({ network, ctx, journey, origin, dest, showStations, onPick }: Props) {
  const container = useRef<HTMLDivElement>(null);
  const map = useRef<MlMap | null>(null);
  const markers = useRef<maplibregl.Marker[]>([]);
  const onPickRef = useRef(onPick);
  onPickRef.current = onPick;

  useEffect(() => {
    if (!container.current) return;
    const m = new maplibregl.Map({
      container: container.current,
      style: STYLE_URL,
      center: MADRID,
      zoom: 12,
      attributionControl: { compact: true, customAttribution: 'Powered by CRTM · EMT Madrid · BiciMAD' },
    });
    m.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
    m.on('load', () => {
      m.addSource('journey', { type: 'geojson', data: emptyFc() });
      m.addSource('stations', { type: 'geojson', data: emptyFc() });
      m.addLayer({
        id: 'stations', type: 'circle', source: 'stations',
        paint: {
          'circle-radius': ['interpolate', ['linear'], ['zoom'], 11, 2.5, 15, 6],
          'circle-color': ['case', ['<', ['get', 'p'], 0], '#B0B6CA', ['<', ['get', 'p'], 0.3], '#D22A1E', ['<', ['get', 'p'], 0.6], '#EAC344', '#00796B'],
          'circle-stroke-width': 1, 'circle-stroke-color': '#FFFFFF',
        },
      });
      m.addLayer({
        id: 'journey-solid', type: 'line', source: 'journey', filter: ['==', ['get', 'dashed'], 0],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': 6 },
      });
      m.addLayer({
        id: 'journey-walk', type: 'line', source: 'journey', filter: ['==', ['get', 'dashed'], 1],
        layout: { 'line-cap': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': 3, 'line-dasharray': [1, 2] },
      });
    });
    m.on('click', (e) => onPickRef.current({ lat: e.lngLat.lat, lon: e.lngLat.lng }));
    map.current = m;
    return () => m.remove();
  }, []);

  useEffect(() => {
    const m = map.current;
    if (!m || !network) return;
    const apply = () => {
      (m.getSource('stations') as GeoJSONSource | undefined)?.setData(showStations ? stationsGeoJson(network, ctx) : emptyFc());
    };
    if (m.isStyleLoaded()) apply();
    else m.once('load', apply);
  }, [network, ctx, showStations]);

  useEffect(() => {
    const m = map.current;
    if (!m || !network) return;
    const apply = () => {
      (m.getSource('journey') as GeoJSONSource | undefined)?.setData(journey ? journeyGeoJson(journey, network) : emptyFc());
      if (journey) {
        const b = new maplibregl.LngLatBounds();
        journeyGeoJson(journey, network).features.forEach((f) =>
          (f.geometry as GeoJSON.LineString).coordinates.forEach((c) => b.extend(c as [number, number])),
        );
        m.fitBounds(b, { padding: 60, maxZoom: 15, duration: 600 });
      }
    };
    if (m.isStyleLoaded()) apply();
    else m.once('load', apply);
  }, [journey, network]);

  useEffect(() => {
    markers.current.forEach((mk) => mk.remove());
    markers.current = [];
    const m = map.current;
    if (!m) return;
    const add = (p: Place | null, cls: string, label: string) => {
      if (!p) return;
      const el = document.createElement('div');
      el.className = `pin ${cls}`;
      el.setAttribute('aria-label', label);
      el.textContent = cls === 'pin-origin' ? 'A' : 'B';
      markers.current.push(new maplibregl.Marker({ element: el }).setLngLat([p.lon, p.lat]).addTo(m));
    };
    add(origin, 'pin-origin', 'Origen');
    add(dest, 'pin-dest', 'Destino');
  }, [origin, dest]);

  return <div ref={container} className="map" role="application" aria-label="Mapa de Madrid. Pulse para fijar origen y destino." />;
}

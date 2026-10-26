import type { Leg, Mode, NetworkData } from '../domain/types';

export const hhmm = (sec: number): string => {
  const s = ((sec % 86_400) + 86_400) % 86_400;
  return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}`;
};

export const minutes = (sec: number): string => `${Math.max(1, Math.round(sec / 60))} min`;
export const euros = (cents: number): string => (cents === 0 ? '0 €' : `${(cents / 100).toFixed(2).replace('.', ',')} €`);
export const grams = (g: number): string => (g >= 1000 ? `${(g / 1000).toFixed(1).replace('.', ',')} kg` : `${Math.round(g)} g`);
export const pct = (p: number): string => `${Math.round(p * 100)} %`;

export const MODE_LABEL: Record<Mode, string> = {
  walk: 'A pie',
  bike_share: 'BiciMAD',
  metro: 'Metro',
  light_rail: 'Metro Ligero',
  bus: 'Bus EMT',
};

/** Colores de modo derivados de la paleta Mística (contraste AA sobre blanco). */
export const MODE_COLOR: Record<Mode, string> = {
  walk: '#58617A',
  bike_share: '#00796B',
  metro: '#0066FF',
  light_rail: '#7F258E',
  bus: '#D22A1E',
};

export function legTitle(leg: Leg, net: NetworkData): string {
  if (leg.kind === 'walk') return `A pie hasta ${leg.toLabel}`;
  if (leg.kind === 'bike') return `BiciMAD: ${net.bike.name[leg.fromStation]} → ${net.bike.name[leg.toStation]}`;
  const route = net.routes[leg.route];
  const p = net.patterns[leg.pattern];
  const to = net.stops.name[p.s[leg.alightPos]];
  const from = net.stops.name[p.s[leg.boardPos]];
  const n = leg.alightPos - leg.boardPos;
  return `${MODE_LABEL[route.mode]} ${route.short}: ${from} → ${to} (${n} ${n === 1 ? 'parada' : 'paradas'})`;
}

/** Color de texto legible (WCAG) sobre un color de línea arbitrario del GTFS. */
export function textOn(hex: string): string {
  const n = parseInt(hex.replace('#', ''), 16);
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? '#031A34' : '#FFFFFF';
}

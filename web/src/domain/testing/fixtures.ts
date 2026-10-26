import type { EmissionFactors, FareConfig, NetworkData } from '../types';

export const FARES_SINGLE: FareConfig = {
  metro: { base: 150, included_stations: 5, per_extra_station: 10, max: 200 },
  light_rail: { flat: 150 },
  bus: { flat: 150 },
  bike_share: { first_30_min: 200, per_extra_30_min: 200 },
};

export const EMISSIONS: EmissionFactors = {
  metro: 27.8,
  light_rail: 28.6,
  bus: 103.9,
  bike_share: 0,
  walk: 0,
  car_reference: 166,
};

/**
 * Red sintética en línea recta (este-oeste, ~1,1 km entre paradas):
 * - Metro M: paradas 0→1→2→3, cada 10 min, 2 min entre paradas.
 * - Bus B:   paradas 0→4→3, cada 5 min, más lento (6 min por tramo) y más caro en CO2.
 * Estaciones de bici junto a 0 y 3.
 */
export function syntheticNetwork(): NetworkData {
  const lon = [-3.75, -3.737, -3.724, -3.711, -3.73];
  const lat = [40.42, 40.42, 40.42, 40.42, 40.4205];
  const trips = (start: number, every: number, n: number): [number, number][] =>
    Array.from({ length: n }, (_, i) => [start + i * every, 1000]);
  return {
    version: 1,
    generated: 'test',
    weekday: 'tuesday',
    attribution: 'test',
    stops: { id: ['a', 'b', 'c', 'd', 'e'], name: ['A', 'B', 'C', 'D', 'E'], lat, lon },
    routes: [
      { id: 'M', short: 'M', long: 'Metro', mode: 'metro', color: '#0066FF', feed: 'metro' },
      { id: 'B', short: 'B', long: 'Bus', mode: 'bus', color: '#D22A1E', feed: 'emt' },
    ],
    patterns: [
      { r: 0, s: [0, 1, 2, 3], t: [0, 120, 240, 360], d: [0, 1100, 2200, 3300], trips: trips(8 * 3600, 600, 12) },
      { r: 1, s: [0, 4, 3], t: [0, 360, 720], d: [0, 1650, 3300], trips: trips(8 * 3600, 300, 24) },
    ],
    transfers: { start: [0, 0, 0, 0, 0, 0], to: [], sec: [] },
    bike: { id: ['b0', 'b3'], name: ['Bici A', 'Bici D'], lat: [40.4202, 40.4202], lon: [-3.7502, -3.7108], capacity: [20, 20] },
  };
}

/** Tipos del dominio. Sin dependencias de UI, mapa ni red (Clean Architecture). */

export type TransitMode = 'metro' | 'light_rail' | 'bus';
export type Mode = TransitMode | 'walk' | 'bike_share';

export interface LatLon {
  lat: number;
  lon: number;
}

/** Formato de `network.json` generado por `auralink-ml compile-network`. */
export interface NetworkData {
  version: number;
  generated: string;
  weekday: string;
  attribution: string;
  stops: { id: string[]; name: string[]; lat: number[]; lon: number[] };
  routes: RouteInfo[];
  patterns: PatternData[];
  transfers: { start: number[]; to: number[]; sec: number[] };
  bike: { id: string[]; name: string[]; lat: number[]; lon: number[]; capacity: number[] };
}

export interface RouteInfo {
  id: string;
  short: string;
  long: string;
  mode: TransitMode;
  color: string;
  feed: string;
}

export interface PatternData {
  /** índice de ruta */
  r: number;
  /** paradas (índices) */
  s: number[];
  /** segundos acumulados desde la primera parada (viaje representativo) */
  t: number[];
  /** metros acumulados */
  d: number[];
  /** [salida en origen (s desde medianoche), factor de duración × 1000] ordenados por salida */
  trips: [number, number][];
}

/** Place = punto elegido por el usuario (nunca sale del dispositivo). */
export interface Place extends LatLon {
  label: string;
}

export type Leg =
  | { kind: 'walk'; from: LatLon; to: LatLon; dep: number; arr: number; distM: number; toLabel: string }
  | {
      kind: 'bike';
      fromStation: number;
      toStation: number;
      dep: number;
      arr: number;
      distM: number;
    }
  | {
      kind: 'ride';
      pattern: number;
      route: number;
      mode: TransitMode;
      boardPos: number;
      alightPos: number;
      dep: number;
      arr: number;
      distM: number;
    };

/** Criterios optimizados simultáneamente. */
export interface Criteria {
  /** llegada, s desde medianoche */
  arr: number;
  /** céntimos de euro (estimación durante la búsqueda) */
  cost: number;
  /** gCO2e */
  co2: number;
}

export interface Journey {
  dep: number;
  arr: number;
  legs: Leg[];
  /** coste exacto según el perfil tarifario */
  costCents: number;
  co2g: number;
  /** emisiones del mismo trayecto en coche (referencia de ahorro) */
  carCo2g: number;
  transfers: number;
}

export interface FareConfig {
  metro: { base?: number; included_stations?: number; per_extra_station?: number; max?: number; flat?: number };
  light_rail: { flat: number };
  bus: { flat: number };
  bike_share: { first_30_min: number; per_extra_30_min: number };
}

export interface EmissionFactors {
  metro: number;
  light_rail: number;
  bus: number;
  bike_share: number;
  walk: number;
  car_reference: number;
}

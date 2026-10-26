import type { FareConfig, Leg, TransitMode } from './types';

/**
 * Coste aproximado al subir a un vehículo durante la búsqueda McRAPTOR.
 * `inMetro` indica que el viaje viene de un tramo de Metro solo seguido de transbordos a pie:
 * el transbordo Metro→Metro no se paga de nuevo. El suplemento por estaciones se calcula
 * de forma exacta al reconstruir el viaje (`journeyFare`).
 */
export function boardingCost(fares: FareConfig, mode: TransitMode, inMetro: boolean): number {
  if (mode === 'metro') {
    if (inMetro) return 0;
    return fares.metro.flat ?? fares.metro.base ?? 0;
  }
  return mode === 'light_rail' ? fares.light_rail.flat : fares.bus.flat;
}

export function bikeShareCost(fares: FareConfig, durationS: number): number {
  const blocks = Math.max(1, Math.ceil(durationS / 1800));
  return fares.bike_share.first_30_min + (blocks - 1) * fares.bike_share.per_extra_30_min;
}

function metroFare(fares: FareConfig, stations: number): number {
  const m = fares.metro;
  if (m.flat !== undefined) return m.flat;
  const base = m.base ?? 0;
  const extra = Math.max(0, stations - (m.included_stations ?? 0)) * (m.per_extra_station ?? 0);
  return Math.min(base + extra, m.max ?? Number.POSITIVE_INFINITY);
}

/** Coste exacto del viaje: los tramos de Metro encadenados (solo con transbordo a pie) son un único billete. */
export function journeyFare(fares: FareConfig, legs: Leg[]): number {
  let total = 0;
  let metroStations = 0;
  const flushMetro = (): void => {
    if (metroStations > 0) total += metroFare(fares, metroStations);
    metroStations = 0;
  };
  for (const leg of legs) {
    if (leg.kind === 'walk') continue;
    if (leg.kind === 'ride' && leg.mode === 'metro') {
      metroStations += leg.alightPos - leg.boardPos;
      continue;
    }
    flushMetro();
    total += leg.kind === 'bike' ? bikeShareCost(fares, leg.arr - leg.dep) : boardingCost(fares, leg.mode, false);
  }
  flushMetro();
  return total;
}

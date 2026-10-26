import { GridIndex } from './geo';
import type { NetworkData, PatternData, RouteInfo } from './types';

const STATION_NEAR_STOP_M = 300;

/** Red preparada para consultas: índices espaciales y de patrones por parada. */
export class PreparedNetwork {
  readonly stopIndex: GridIndex;
  readonly bikeIndex: GridIndex;
  /** para cada parada, los (patrón, posición) que pasan por ella */
  readonly stopPatterns: { p: number; pos: number }[][];
  /** estación BiciMAD más cercana a cada parada (≤ 300 m) o -1 */
  readonly nearestStation: Int32Array;
  readonly nearestStationM: Float64Array;
  /** parada servida por Metro o Metro Ligero */
  readonly isRailStop: Uint8Array;

  constructor(readonly data: NetworkData) {
    const { stops, bike, patterns, routes } = data;
    this.stopIndex = new GridIndex(stops.lat, stops.lon, 400);
    this.bikeIndex = new GridIndex(bike.lat, bike.lon, 400);
    this.stopPatterns = stops.id.map(() => []);
    this.isRailStop = new Uint8Array(stops.id.length);
    patterns.forEach((pattern, p) => {
      const rail = routes[pattern.r].mode !== 'bus';
      pattern.s.forEach((stop, pos) => {
        this.stopPatterns[stop].push({ p, pos });
        if (rail) this.isRailStop[stop] = 1;
      });
    });
    this.nearestStation = new Int32Array(stops.id.length).fill(-1);
    this.nearestStationM = new Float64Array(stops.id.length);
    for (let s = 0; s < stops.id.length; s++) {
      const [first] = this.bikeIndex.within({ lat: stops.lat[s], lon: stops.lon[s] }, STATION_NEAR_STOP_M);
      if (first) {
        this.nearestStation[s] = first.idx;
        this.nearestStationM[s] = first.distM;
      }
    }
  }

  pattern(p: number): PatternData {
    return this.data.patterns[p];
  }

  route(p: number): RouteInfo {
    return this.data.routes[this.data.patterns[p].r];
  }

  stopPos(s: number): { lat: number; lon: number } {
    return { lat: this.data.stops.lat[s], lon: this.data.stops.lon[s] };
  }

  stationPos(b: number): { lat: number; lon: number } {
    return { lat: this.data.bike.lat[b], lon: this.data.bike.lon[b] };
  }

  /** Hora (s) del viaje `trip` del patrón `p` en la posición `pos`. */
  tripTime(p: number, trip: number, pos: number): number {
    const pattern = this.data.patterns[p];
    const [dep, factor] = pattern.trips[trip];
    return dep + Math.round((pattern.t[pos] * factor) / 1000);
  }

  /** Primer viaje del patrón que sale de `pos` a partir de `time`; -1 si no hay. */
  earliestTrip(p: number, pos: number, time: number): number {
    const trips = this.data.patterns[p].trips;
    let lo = 0;
    let hi = trips.length;
    while (lo < hi) {
      const mid = (lo + hi) >>> 1;
      if (this.tripTime(p, mid, pos) < time) lo = mid + 1;
      else hi = mid;
    }
    // las plantillas con distinto factor pueden no ser FIFO: se revisan unas pocas siguientes
    let best = -1;
    let bestTime = Number.POSITIVE_INFINITY;
    for (let i = Math.max(0, lo - 2); i < Math.min(trips.length, lo + 3); i++) {
      const t = this.tripTime(p, i, pos);
      if (t >= time && t < bestTime) {
        best = i;
        bestTime = t;
      }
    }
    return best;
  }
}

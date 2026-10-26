import type { LatLon } from './types';

const EARTH_RADIUS_M = 6_371_000;
const toRad = (deg: number): number => (deg * Math.PI) / 180;

export function haversineM(a: LatLon, b: LatLon): number {
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/** Parámetros de movilidad activa (documentados en AURA-DOC-02). */
export const ACTIVE = {
  detourFactor: 1.3,
  walkSpeedMps: 4.8 / 3.6,
  bikeSpeedMps: 15 / 3.6,
  /** desanclar o anclar una bici */
  dockHandlingS: 60,
} as const;

export const walkSeconds = (straightM: number): number =>
  Math.ceil((straightM * ACTIVE.detourFactor) / ACTIVE.walkSpeedMps);

export const bikeSeconds = (straightM: number): number =>
  Math.ceil((straightM * ACTIVE.detourFactor) / ACTIVE.bikeSpeedMps);

/** Índice espacial en rejilla para búsquedas de vecinos en O(k). */
export class GridIndex {
  private readonly cells = new Map<string, number[]>();
  private readonly cellDeg: number;

  constructor(
    private readonly lat: ArrayLike<number>,
    private readonly lon: ArrayLike<number>,
    cellM = 500,
  ) {
    this.cellDeg = cellM / 111_000;
    for (let i = 0; i < lat.length; i++) {
      const key = this.key(lat[i], lon[i]);
      const bucket = this.cells.get(key);
      if (bucket) bucket.push(i);
      else this.cells.set(key, [i]);
    }
  }

  private key(lat: number, lon: number): string {
    return `${Math.floor(lat / this.cellDeg)}:${Math.floor(lon / (this.cellDeg * 1.3))}`;
  }

  /** Índices a menos de `radiusM`, ordenados por distancia. */
  within(p: LatLon, radiusM: number): { idx: number; distM: number }[] {
    const span = Math.ceil(radiusM / (this.cellDeg * 111_000)) + 1;
    const cy = Math.floor(p.lat / this.cellDeg);
    const cx = Math.floor(p.lon / (this.cellDeg * 1.3));
    const out: { idx: number; distM: number }[] = [];
    for (let dy = -span; dy <= span; dy++) {
      for (let dx = -span; dx <= span; dx++) {
        for (const i of this.cells.get(`${cy + dy}:${cx + dx}`) ?? []) {
          const distM = haversineM(p, { lat: this.lat[i], lon: this.lon[i] });
          if (distM <= radiusM) out.push({ idx: i, distM });
        }
      }
    }
    return out.sort((a, b) => a.distM - b.distM);
  }
}

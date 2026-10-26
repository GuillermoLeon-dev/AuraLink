/**
 * Prueba de integración y rendimiento sobre la red real compilada (`public/data/network.json`).
 * Se omite si la red no se ha generado (`auralink-ml compile-network`).
 */
import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { PreparedNetwork } from './network';
import { planJourneys } from './raptor';
import { EMISSIONS, FARES_SINGLE } from './testing/fixtures';
import type { NetworkData } from './types';

const path = new URL('../../public/data/network.json', import.meta.url);
const available = existsSync(path);

describe.skipIf(!available)('red real de Madrid', () => {
  const data = available ? (JSON.parse(readFileSync(path, 'utf-8')) as NetworkData) : null;
  const net = data ? new PreparedNetwork(data) : null;
  const cases = [
    { name: 'Sol → Ciudad Universitaria', o: { lat: 40.4169, lon: -3.7035, label: 'Sol' }, d: { lat: 40.4446, lon: -3.7267, label: 'C. Universitaria' } },
    { name: 'Atocha → Plaza de Castilla', o: { lat: 40.4066, lon: -3.6892, label: 'Atocha' }, d: { lat: 40.4669, lon: -3.6889, label: 'Pza. Castilla' } },
    { name: 'Moncloa → Las Tablas', o: { lat: 40.4351, lon: -3.7190, label: 'Moncloa' }, d: { lat: 40.5045, lon: -3.6690, label: 'Las Tablas' } },
  ];

  for (const c of cases) {
    it(`${c.name}: alternativas multimodales en < 2 s`, () => {
      const t0 = performance.now();
      const journeys = planJourneys(net!, c.o, c.d, 8 * 3600 + 30 * 60, { fares: FARES_SINGLE, emissions: EMISSIONS });
      const ms = performance.now() - t0;
      const summary = journeys.map((j) => ({
        min: Math.round((j.arr - j.dep) / 60),
        eur: j.costCents / 100,
        co2: Math.round(j.co2g),
        modes: j.legs.map((l) => (l.kind === 'ride' ? `${l.mode}:${data!.routes[l.route].short}` : l.kind)).join('>'),
      }));
      console.info(c.name, `${ms.toFixed(0)} ms`, JSON.stringify(summary));
      expect(journeys.length).toBeGreaterThan(1);
      expect(journeys.some((j) => j.legs.some((l) => l.kind === 'ride'))).toBe(true);
      expect(ms).toBeLessThan(2000);
    });
  }
});

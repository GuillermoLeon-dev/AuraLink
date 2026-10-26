import { describe, expect, it } from 'vitest';
import { journeyFare } from './fares';
import { PreparedNetwork } from './network';
import { planJourneys } from './raptor';
import { EMISSIONS, FARES_SINGLE, syntheticNetwork } from './testing/fixtures';
import type { Leg } from './types';

const net = new PreparedNetwork(syntheticNetwork());
const at = (h: number, m = 0): number => h * 3600 + m * 60;
const A = { lat: 40.4201, lon: -3.7501, label: 'Origen' };
const D = { lat: 40.4201, lon: -3.7109, label: 'Destino' };

describe('McRAPTOR', () => {
  const journeys = planJourneys(net, A, D, at(8, 1), { fares: FARES_SINGLE, emissions: EMISSIONS, maxDirectWalkM: 0 });

  it('devuelve un frente de Pareto no vacío y ordenado por llegada', () => {
    expect(journeys.length).toBeGreaterThan(0);
    for (let i = 1; i < journeys.length; i++) expect(journeys[i].arr).toBeGreaterThanOrEqual(journeys[i - 1].arr);
  });

  it('ninguna alternativa domina a otra (tiempo, coste, CO2)', () => {
    for (const a of journeys) {
      for (const b of journeys) {
        if (a === b) continue;
        const dominates = a.arr <= b.arr && a.costCents <= b.costCents && a.co2g + 10 <= b.co2g;
        expect(dominates).toBe(false);
      }
    }
  });

  it('encuentra el metro, que es más rápido y emite menos que el bus', () => {
    const metro = journeys.find((j) => j.legs.some((l) => l.kind === 'ride' && l.mode === 'metro'));
    expect(metro).toBeDefined();
    const bus = journeys.find((j) => j.legs.every((l) => l.kind !== 'ride' || l.mode === 'bus') && j.legs.some((l) => l.kind === 'ride'));
    if (bus) expect(metro!.co2g).toBeLessThan(bus.co2g);
  });

  it('ofrece la bici pública directa como alternativa de cero emisiones', () => {
    const bike = journeys.find((j) => j.legs.some((l) => l.kind === 'bike'));
    expect(bike).toBeDefined();
    expect(bike!.co2g).toBe(0);
    expect(bike!.costCents).toBe(200);
  });

  it('respeta la exclusión de estaciones decidida por el técnico', () => {
    const noBike = planJourneys(net, A, D, at(8, 1), {
      fares: FARES_SINGLE,
      emissions: EMISSIONS,
      maxDirectWalkM: 0,
      stationUsable: () => false,
    });
    expect(noBike.some((j) => j.legs.some((l) => l.kind === 'bike'))).toBe(false);
  });

  it('los tramos son contiguos en el tiempo', () => {
    for (const j of journeys) {
      for (let i = 1; i < j.legs.length; i++) expect(j.legs[i].dep).toBeGreaterThanOrEqual(j.legs[i - 1].arr);
    }
  });
});

describe('tarifas', () => {
  const ride = (boardPos: number, alightPos: number): Leg => ({
    kind: 'ride', pattern: 0, route: 0, mode: 'metro', boardPos, alightPos, dep: 0, arr: 1, distM: 0,
  });
  const walk: Leg = { kind: 'walk', from: { lat: 0, lon: 0 }, to: { lat: 0, lon: 0 }, dep: 0, arr: 0, distM: 0, toLabel: '' };

  it('metro: 1,50 € hasta 5 estaciones y +0,10 € por estación con tope de 2,00 €', () => {
    expect(journeyFare(FARES_SINGLE, [ride(0, 3)])).toBe(150);
    expect(journeyFare(FARES_SINGLE, [ride(0, 7)])).toBe(170);
    expect(journeyFare(FARES_SINGLE, [ride(0, 20)])).toBe(200);
  });

  it('transbordo Metro→Metro a pie es un único billete', () => {
    expect(journeyFare(FARES_SINGLE, [ride(0, 3), walk, ride(0, 3)])).toBe(160);
  });
});

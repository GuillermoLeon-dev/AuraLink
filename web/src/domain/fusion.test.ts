import { describe, expect, it } from 'vitest';
import { assessJourney, confidence, probAtLeastOne, StationLookup, type ContextData } from './fusion';
import { PreparedNetwork } from './network';
import { rankJourneys } from './ranking';
import { syntheticNetwork } from './testing/fixtures';
import type { Journey } from './types';

const net = new PreparedNetwork(syntheticNetwork());

function ctx(overrides: Partial<ContextData> = {}): ContextData {
  const fresh = { ok: true, updated: 'x', age_min: 1, error: null };
  return {
    generated: 'x',
    sources: { gbfs: fresh, weather: fresh, air: fresh, traffic: fresh },
    stations: { id: ['b0', 'b3'], bikes: [0, 10], docks: [20, 0], renting: [1, 1], returning: [1, 1], mu: [0, 0], sigma2: [0.02, 0.02], p_bike_30: [0, 1], p_dock_30: [1, 0] },
    pressure: 1,
    weather: { ok: true, time: ['t'], precip: [0], temp: [18], wind: [5] },
    air: { ok: true, no2_mean: 40 },
    traffic: { ok: true, congestion_index: 10 },
    demand: { ok: true },
    drift_psi: {},
    notices: [],
    thresholds: { bike_availability_notice: { kind: 'notice', value: 0.6, description: '' }, rain_notice: { kind: 'notice', value: 0.5, description: '' } },
    overrides: {},
    ...overrides,
  };
}

const bikeJourney: Journey = {
  dep: 28_800, arr: 30_000, costCents: 200, co2g: 0, carCo2g: 700, transfers: 0,
  legs: [
    { kind: 'walk', from: { lat: 0, lon: 0 }, to: { lat: 0, lon: 0 }, dep: 28_800, arr: 28_900, distM: 100, toLabel: '' },
    { kind: 'bike', fromStation: 0, toStation: 1, dep: 28_900, arr: 29_900, distM: 3000 },
    { kind: 'walk', from: { lat: 0, lon: 0 }, to: { lat: 0, lon: 0 }, dep: 29_900, arr: 30_000, distM: 100, toLabel: '' },
  ],
};

describe('data fusion', () => {
  it('estación vacía y anclaje lleno → baja fiabilidad, riesgo y contingencia', () => {
    const c = ctx();
    const a = assessJourney(bikeJourney, { ctx: c, stations: new StationLookup(c), net, nowSec: 28_800 });
    expect(a.reliability).toBeLessThan(0.1);
    expect(a.bikeRisk).toBe(true);
    expect(a.expectedDurationS).toBeGreaterThan(bikeJourney.arr - bikeJourney.dep);
    expect(a.factors.some((f) => f.source === 'BiciMAD')).toBe(true);
  });

  it('sin datos frescos de BiciMAD la probabilidad se contrae a 0,5 (no inventa certeza)', () => {
    const c = ctx({ sources: { ...ctx().sources, gbfs: { ok: false, updated: null, age_min: null, error: 'caída' } } });
    const a = assessJourney(bikeJourney, { ctx: c, stations: new StationLookup(c), net, nowSec: 28_800 });
    expect(a.reliability).toBeCloseTo(0.25, 2);
  });

  it('la lluvia reduce el confort de los tramos activos', () => {
    const dry = ctx();
    const wet = ctx({ weather: { ok: true, time: ['t'], precip: [3], temp: [15], wind: [5] } });
    const aDry = assessJourney(bikeJourney, { ctx: dry, stations: new StationLookup(dry), net, nowSec: 28_800 });
    const aWet = assessJourney(bikeJourney, { ctx: wet, stations: new StationLookup(wet), net, nowSec: 28_800 });
    expect(aWet.comfort).toBeLessThan(aDry.comfort);
  });

  it('la confianza decae con la antigüedad del dato', () => {
    expect(confidence({ ok: true, updated: 'x', age_min: 0, error: null }, 30)).toBe(1);
    expect(confidence({ ok: true, updated: 'x', age_min: 30, error: null }, 30)).toBeCloseTo(Math.exp(-1));
    expect(confidence({ ok: false, updated: null, age_min: null, error: 'x' }, 30)).toBe(0);
  });

  it('el nowcast coincide con la implementación Python (valor de referencia)', () => {
    // auralink_ml.forecasting.nowcast.prob_at_least_one(10, -0.1, 0.3, 60) = 0.793688949951041
    expect(probAtLeastOne(10, -0.1, 0.3, 60)).toBeCloseTo(0.793688949951041, 5);
  });
});

describe('ranking', () => {
  const metro: Journey = { ...bikeJourney, costCents: 150, co2g: 90, arr: 29_700, legs: [] };
  const fast = { journey: metro, assessment: { reliability: 1, comfort: 1, expectedDurationS: 900, factors: [], bikeRisk: false } };
  const green = { journey: bikeJourney, assessment: { reliability: 0.9, comfort: 1, expectedDurationS: 1300, factors: [], bikeRisk: false } };

  it('la preferencia cambia el orden sin recalcular rutas', () => {
    expect(rankJourneys([fast, green], 'fastest')[0].journey).toBe(metro);
    expect(rankJourneys([fast, green], 'greenest')[0].journey).toBe(bikeJourney);
  });

  it('marca la mejor alternativa en cada criterio', () => {
    const ranked = rankJourneys([fast, green], 'balanced');
    expect(ranked.find((r) => r.journey === metro)!.badges).toContain('fastest');
    expect(ranked.find((r) => r.journey === bikeJourney)!.badges).toContain('greenest');
  });
});

/**
 * Data fusion a nivel de decisión, ponderada por confianza.
 *
 * Cada fuente aporta una evidencia (probabilidad o penalización) y una confianza c ∈ [0, 1]
 * que decae con la antigüedad del dato: c = exp(−edad / τ). Una fuente caída o vieja pesa
 * menos automáticamente; nunca se inventa un valor. Todas las contribuciones se explican.
 */
import type { PreparedNetwork } from './network';
import type { Journey, Leg } from './types';

export interface SourceStatus {
  ok: boolean;
  updated: string | null;
  age_min: number | null;
  error: string | null;
}

export interface ThresholdInfo {
  kind: 'alert' | 'notice';
  value: number;
  description: string;
}

export interface ContextData {
  generated: string;
  sources: Record<'gbfs' | 'weather' | 'air' | 'traffic', SourceStatus>;
  stations: {
    id: string[];
    bikes: number[];
    docks: number[];
    renting: number[];
    returning: number[];
    mu: number[];
    sigma2: number[];
    p_bike_30: number[];
    p_dock_30: number[];
  };
  pressure: number;
  weather: { ok: boolean; time?: string[]; precip?: number[]; temp?: number[]; wind?: number[] };
  air: { ok: boolean; no2_mean?: number | null; no2_max?: number | null; stations?: number; hour?: number };
  traffic: { ok: boolean; congestion_index?: number | null; points?: number };
  demand: { ok: boolean; date?: string; p10?: number; p50?: number; p90?: number; rel_width?: number; pressure?: number; days?: { date: string; p10: number; p50: number; p90: number }[]; model?: string };
  drift_psi: Record<string, number>;
  notices: { key: string; message: string; value: number }[];
  thresholds: Record<string, ThresholdInfo>;
  overrides: { excluded_bike_stations?: { station_id: string; issue?: number; until?: string }[]; exposure_notice_active?: boolean; promoted_demand_model?: string };
}

export interface StationState {
  bikes: number;
  docks: number;
  renting: boolean;
  returning: boolean;
  mu: number;
  sigma2: number;
}

/** τ por fuente (minutos): a partir de ~τ la confianza cae a 1/e. */
const TAU_MIN = { gbfs: 30, weather: 360, air: 180, traffic: 45 } as const;
/** Coste esperado (s) de no encontrar bici/anclaje: buscar otra estación. */
export const CONTINGENCY_S = 8 * 60;

export function confidence(src: SourceStatus | undefined, tauMin: number): number {
  if (!src?.ok || src.age_min === null) return 0;
  return Math.exp(-Math.max(0, src.age_min) / tauMin);
}

const phi = (x: number): number => 0.5 * (1 + erf(x / Math.SQRT2));

function erf(x: number): number {
  // Abramowitz-Stegun 7.1.26 (error < 1.5e-7)
  const s = Math.sign(x);
  const t = 1 / (1 + 0.3275911 * Math.abs(x));
  const y = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x);
  return s * y;
}

/** Misma fórmula que `auralink_ml.forecasting.nowcast.prob_at_least_one`. */
export function probAtLeastOne(level: number, drift: number, sigma2: number, minutes: number): number {
  const mean = level + drift * minutes;
  const sd = Math.sqrt(Math.max(sigma2 * minutes, 0) + 0.25);
  return 1 - phi((0.5 - mean) / sd);
}

export class StationLookup {
  private readonly byId = new Map<string, StationState>();

  constructor(ctx: ContextData | null) {
    const s = ctx?.stations;
    if (!s) return;
    s.id.forEach((id, i) => {
      this.byId.set(id, {
        bikes: s.bikes[i], docks: s.docks[i], renting: s.renting[i] === 1, returning: s.returning[i] === 1, mu: s.mu[i], sigma2: s.sigma2[i],
      });
    });
  }

  get(id: string): StationState | undefined {
    return this.byId.get(id);
  }
}

export interface Factor {
  source: 'BiciMAD' | 'Meteorología' | 'Calidad del aire' | 'Tráfico' | 'Demanda' | 'Técnico';
  text: string;
  /** −1 (muy negativo) … +1 */
  impact: number;
  confidence: number;
}

export interface Assessment {
  /** probabilidad de completar el viaje como está planificado */
  reliability: number;
  /** 0 (incómodo) … 1 */
  comfort: number;
  expectedDurationS: number;
  factors: Factor[];
  /** algún tramo en bici por debajo del umbral de aviso */
  bikeRisk: boolean;
}

export interface FusionInputs {
  ctx: ContextData | null;
  stations: StationLookup;
  net: PreparedNetwork;
  /** segundos desde medianoche "ahora" (horizonte del nowcast) */
  nowSec: number;
}

function hourlyAt(ctx: ContextData, isoHourOffset: number): { precip: number; temp: number; wind: number } | null {
  const w = ctx.weather;
  if (!w.ok || !w.time?.length) return null;
  const i = Math.min(Math.max(0, isoHourOffset), w.time.length - 1);
  return { precip: w.precip?.[i] ?? 0, temp: w.temp?.[i] ?? 15, wind: w.wind?.[i] ?? 0 };
}

const activeSeconds = (legs: Leg[]): number =>
  legs.filter((l) => l.kind !== 'ride').reduce((a, l) => a + (l.arr - l.dep), 0);

export function assessJourney(j: Journey, { ctx, stations, net, nowSec }: FusionInputs): Assessment {
  const factors: Factor[] = [];
  let reliability = 1;
  let extraS = 0;
  let bikeRisk = false;
  const notice = ctx?.thresholds.bike_availability_notice?.value ?? 0.6;
  const dockNotice = ctx?.thresholds.dock_availability_notice?.value ?? 0.6;
  const pressure = ctx?.demand.ok ? (ctx.pressure ?? 1) : 1;
  const cBike = confidence(ctx?.sources.gbfs, TAU_MIN.gbfs);

  // --- BiciMAD: nowcast de bici al recoger y anclaje al devolver
  for (const leg of j.legs) {
    if (leg.kind !== 'bike') continue;
    const pick = stations.get(net.data.bike.id[leg.fromStation]);
    const drop = stations.get(net.data.bike.id[leg.toStation]);
    const hPick = Math.max(0, (leg.dep - nowSec) / 60);
    const hDrop = Math.max(0, (leg.arr - nowSec) / 60);
    const pBike = pick && pick.renting ? probAtLeastOne(pick.bikes, pick.mu, pick.sigma2 * pressure, hPick) : 0.5;
    const pDock = drop && drop.returning ? probAtLeastOne(drop.docks, -drop.mu, drop.sigma2 * pressure, hDrop) : 0.5;
    // sin dato fresco, la probabilidad se contrae hacia 0,5 (no informativa)
    const pB = cBike * pBike + (1 - cBike) * 0.5;
    const pD = cBike * pDock + (1 - cBike) * 0.5;
    reliability *= pB * pD;
    extraS += (1 - pB) * CONTINGENCY_S + (1 - pD) * CONTINGENCY_S;
    if (pB < notice || pD < dockNotice) bikeRisk = true;
    factors.push({
      source: 'BiciMAD',
      text: `P(bici en ${net.data.bike.name[leg.fromStation]}) = ${(pB * 100).toFixed(0)} % · P(anclaje en ${net.data.bike.name[leg.toStation]}) = ${(pD * 100).toFixed(0)} %`,
      impact: Math.min(pB, pD) >= notice ? 0.2 : -0.6,
      confidence: cBike,
    });
    if (pressure > 1.1) {
      factors.push({ source: 'Demanda', text: `Demanda prevista ${(pressure * 100 - 100).toFixed(0)} % sobre la semana: más rotación en estaciones`, impact: -0.2, confidence: 0.6 });
    }
  }

  // --- Tráfico: retraso esperado en tramos de bus
  const cTraffic = confidence(ctx?.sources.traffic, TAU_MIN.traffic);
  const ci = ctx?.traffic.congestion_index ?? null;
  const busS = j.legs.filter((l) => l.kind === 'ride' && l.mode === 'bus').reduce((a, l) => a + (l.arr - l.dep), 0);
  if (busS > 0 && ci !== null) {
    const delay = busS * 0.5 * (ci / 100) * cTraffic;
    extraS += delay;
    reliability *= 1 - 0.3 * (ci / 100) * cTraffic;
    if (ci >= (ctx?.thresholds.traffic_congestion_notice?.value ?? 40)) {
      factors.push({ source: 'Tráfico', text: `Tráfico denso (índice ${ci.toFixed(0)}/100): +${Math.round(delay / 60)} min esperados en bus`, impact: -0.5, confidence: cTraffic });
    }
  }

  // --- Confort de los tramos activos (a pie / bici): meteorología y calidad del aire
  const active = activeSeconds(j.legs);
  const share = j.arr > j.dep ? active / (j.arr - j.dep) : 0;
  let comfort = 1;
  if (ctx && share > 0) {
    const hourOffset = Math.floor((j.dep - nowSec) / 3600);
    const w = hourlyAt(ctx, hourOffset);
    const cW = confidence(ctx.sources.weather, TAU_MIN.weather);
    if (w) {
      if (w.precip >= (ctx.thresholds.rain_notice?.value ?? 0.5)) {
        comfort -= 0.5 * share * cW;
        factors.push({ source: 'Meteorología', text: `Lluvia prevista ${w.precip.toFixed(1)} mm/h durante los tramos activos`, impact: -0.7, confidence: cW });
      }
      if (w.temp >= 32 || w.temp <= 3) {
        comfort -= 0.3 * share * cW;
        factors.push({ source: 'Meteorología', text: `Temperatura extrema (${w.temp.toFixed(0)} °C)`, impact: -0.5, confidence: cW });
      }
      const hasBike = j.legs.some((l) => l.kind === 'bike');
      if (hasBike && w.wind >= 35) {
        comfort -= 0.2 * cW;
        factors.push({ source: 'Meteorología', text: `Viento fuerte (${w.wind.toFixed(0)} km/h) en bici`, impact: -0.4, confidence: cW });
      }
    }
    const cA = confidence(ctx.sources.air, TAU_MIN.air);
    const no2 = ctx.air.no2_mean ?? null;
    if (ctx.overrides.exposure_notice_active || (no2 !== null && no2 > (ctx.thresholds.no2_alert?.value ?? 100))) {
      comfort -= 0.3 * share * (ctx.overrides.exposure_notice_active ? 1 : cA);
      factors.push({
        source: ctx.overrides.exposure_notice_active ? 'Técnico' : 'Calidad del aire',
        text: `NO₂ elevado (${no2?.toFixed(0) ?? '—'} µg/m³): exposición en tramos activos`,
        impact: -0.5,
        confidence: ctx.overrides.exposure_notice_active ? 1 : cA,
      });
    }
  }

  return {
    reliability: clamp01(reliability),
    comfort: clamp01(comfort),
    expectedDurationS: j.arr - j.dep + Math.round(extraS),
    factors,
    bikeRisk,
  };
}

const clamp01 = (x: number): number => Math.min(1, Math.max(0, x));

/** Estaciones que el técnico ha excluido o que no están operativas: el router no las usa. */
export function stationUsability(ctx: ContextData | null, net: PreparedNetwork, stations: StationLookup) {
  const excluded = new Set((ctx?.overrides.excluded_bike_stations ?? []).map((e) => String(e.station_id)));
  return (station: number, use: 'pickup' | 'dropoff'): boolean => {
    const id = net.data.bike.id[station];
    if (excluded.has(id)) return false;
    const st = stations.get(id);
    if (!st) return true; // sin dato: se permite y la fusión lo marcará con baja confianza
    return use === 'pickup' ? st.renting : st.returning;
  };
}

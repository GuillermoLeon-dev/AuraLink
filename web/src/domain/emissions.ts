import { ACTIVE } from './geo';
import type { EmissionFactors, Leg, Mode } from './types';

export function legMode(leg: Leg): Mode {
  if (leg.kind === 'ride') return leg.mode;
  return leg.kind === 'bike' ? 'bike_share' : 'walk';
}

/** gCO2e de un tramo: distancia recorrida × factor del modo (g/pkm). */
export function legCo2(factors: EmissionFactors, leg: Leg): number {
  const km = leg.kind === 'ride' ? leg.distM / 1000 : (leg.distM * ACTIVE.detourFactor) / 1000;
  return km * factors[legMode(leg)];
}

export const journeyCo2 = (factors: EmissionFactors, legs: Leg[]): number =>
  legs.reduce((acc, leg) => acc + legCo2(factors, leg), 0);

/** Emisiones del mismo origen-destino en coche (distancia en línea recta × rodeo). */
export const carCo2 = (factors: EmissionFactors, straightM: number): number =>
  ((straightM * ACTIVE.detourFactor) / 1000) * factors.car_reference;

import type { Assessment } from './fusion';
import type { Journey } from './types';

export type Preference = 'balanced' | 'fastest' | 'cheapest' | 'greenest';

export const PREFERENCES: Record<Preference, { label: string; time: number; cost: number; co2: number }> = {
  balanced: { label: 'Equilibrada', time: 1, cost: 0.6, co2: 0.6 },
  fastest: { label: 'Más rápida', time: 1, cost: 0.05, co2: 0.05 },
  cheapest: { label: 'Más barata', time: 0.25, cost: 1, co2: 0.05 },
  greenest: { label: 'Más verde', time: 0.25, cost: 0.05, co2: 1 },
};

export interface RankedJourney {
  journey: Journey;
  assessment: Assessment;
  score: number;
  /** etiquetas "mejor en…" dentro del frente */
  badges: ('fastest' | 'cheapest' | 'greenest' | 'reliable')[];
}

const norm = (x: number, min: number, max: number): number => (max > min ? (x - min) / (max - min) : 0);

/**
 * Puntuación (menor = mejor): suma ponderada de criterios normalizados min–max dentro del
 * frente de Pareto, usando la duración *esperada* (incluye contingencias de la fusión) y
 * penalizando baja fiabilidad y confort. Cambiar de preferencia no recalcula rutas.
 */
export function rankJourneys(items: { journey: Journey; assessment: Assessment }[], pref: Preference): RankedJourney[] {
  if (items.length === 0) return [];
  const w = PREFERENCES[pref];
  const t = items.map((i) => i.assessment.expectedDurationS);
  const c = items.map((i) => i.journey.costCents);
  const e = items.map((i) => i.journey.co2g);
  const [tMin, tMax, cMin, cMax, eMin, eMax] = [Math.min(...t), Math.max(...t), Math.min(...c), Math.max(...c), Math.min(...e), Math.max(...e)];
  const bestRel = Math.max(...items.map((i) => i.assessment.reliability));

  return items
    .map((i, k) => {
      const score =
        w.time * norm(t[k], tMin, tMax) +
        w.cost * norm(c[k], cMin, cMax) +
        w.co2 * norm(e[k], eMin, eMax) +
        0.8 * (1 - i.assessment.reliability) +
        0.3 * (1 - i.assessment.comfort);
      const badges: RankedJourney['badges'] = [];
      if (t[k] === tMin) badges.push('fastest');
      if (c[k] === cMin) badges.push('cheapest');
      if (e[k] === eMin) badges.push('greenest');
      if (i.assessment.reliability === bestRel && bestRel >= 0.9) badges.push('reliable');
      return { ...i, score, badges };
    })
    .sort((a, b) => a.score - b.score);
}

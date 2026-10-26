import type { Criteria } from './types';

/** Tolerancias de dominancia ε: evitan bolsas enormes por diferencias irrelevantes. */
export const EPSILON = { costCents: 5, co2g: 10 } as const;

/** `a` domina (o empata) a `b` en todos los criterios, con tolerancia ε en coste y CO₂. */
export function weaklyDominates(a: Criteria, b: Criteria): boolean {
  return a.arr <= b.arr && a.cost <= b.cost + EPSILON.costCents && a.co2 <= b.co2 + EPSILON.co2g;
}

/**
 * Bolsa de Pareto acotada. Inserta `label` si no está dominado; elimina los que domina.
 * Devuelve `true` si se insertó (la parada debe marcarse para la siguiente ronda).
 */
export function mergeIntoBag<T extends Criteria>(bag: T[], label: T, maxSize = 8): boolean {
  for (const existing of bag) {
    if (weaklyDominates(existing, label)) return false;
  }
  for (let i = bag.length - 1; i >= 0; i--) {
    if (weaklyDominates(label, bag[i])) bag.splice(i, 1);
  }
  bag.push(label);
  if (bag.length > maxSize) {
    // descarta la etiqueta más tardía: preserva diversidad de coste/CO2 entre las más rápidas
    let worst = 0;
    for (let i = 1; i < bag.length; i++) if (bag[i].arr > bag[worst].arr) worst = i;
    bag.splice(worst, 1);
    return bag.includes(label);
  }
  return true;
}

/** Filtra una lista a su frente de Pareto (sin tolerancia). */
export function paretoFront<T>(items: T[], key: (t: T) => Criteria): T[] {
  return items.filter((a, i) =>
    !items.some((b, j) => {
      if (i === j) return false;
      const ka = key(a);
      const kb = key(b);
      const notWorse = kb.arr <= ka.arr && kb.cost <= ka.cost && kb.co2 <= ka.co2;
      const better = kb.arr < ka.arr || kb.cost < ka.cost || kb.co2 < ka.co2;
      return notWorse && (better || j < i);
    }),
  );
}

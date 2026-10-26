/**
 * McRAPTOR multicriterio (llegada, coste, CO₂) con acceso/egreso a pie y en bici pública.
 * Referencia: Delling, Pajor y Werneck, "Round-Based Public Transit Routing", Transp. Sci. 2015.
 *
 * Cada ronda k añade un vehículo más. Por parada se mantiene una bolsa de Pareto con
 * tolerancia ε (ver `pareto.ts`) y se poda contra la bolsa del destino (target pruning).
 */
import { carCo2, journeyCo2 } from './emissions';
import { boardingCost, bikeShareCost, journeyFare } from './fares';
import { ACTIVE, bikeSeconds, haversineM, walkSeconds } from './geo';
import type { PreparedNetwork } from './network';
import { mergeIntoBag, paretoFront } from './pareto';
import type { Criteria, EmissionFactors, FareConfig, Journey, LatLon, Leg, Place } from './types';

export interface RouterOptions {
  fares: FareConfig;
  emissions: EmissionFactors;
  /** número máximo de vehículos (rondas) */
  maxRides?: number;
  maxWalkAccessM?: number;
  maxBikeAccessM?: number;
  maxDirectWalkM?: number;
  /** estación utilizable (excluidas por el técnico, no operativas...) */
  stationUsable?: (station: number, use: 'pickup' | 'dropoff') => boolean;
}

interface Label extends Criteria {
  prev: Label | null;
  legs: Leg[];
  inMetro: boolean;
  fromRide: boolean;
}

interface RouteBagEntry {
  label: Label;
  trip: number;
  boardPos: number;
  cost: number;
}

interface Egress {
  sec: number;
  cost: number;
  build: (t: number) => Leg[];
}

const STATION_NEAR_PLACE_M = 400;

export function planJourneys(
  net: PreparedNetwork,
  origin: Place,
  dest: Place,
  departure: number,
  options: RouterOptions,
): Journey[] {
  const opts = {
    maxRides: 4,
    maxWalkAccessM: 1000,
    maxBikeAccessM: 6000,
    maxDirectWalkM: 3500,
    stationUsable: () => true,
    ...options,
  };
  const { stops, patterns } = net.data;
  const target: Label[] = [];
  const best = new Map<number, Label[]>();

  const pickup = nearestUsableStation(net, origin, 'pickup', opts.stationUsable);
  const dropoff = nearestUsableStation(net, dest, 'dropoff', opts.stationUsable);

  // --- Opciones directas (sin transporte público) ---
  const directM = haversineM(origin, dest);
  if (directM <= opts.maxDirectWalkM) {
    const arr = departure + walkSeconds(directM);
    mergeIntoBag(target, label(arr, 0, 0, null, [walkLeg(origin, dest, departure, arr, dest.label)], false, false), 16);
  }
  if (pickup && dropoff && pickup.idx !== dropoff.idx) {
    const legs = bikeChain(net, origin, pickup, dropoff, dest, departure);
    const last = legs[legs.length - 1];
    mergeIntoBag(target, label(last.arr, legCost(legs, opts.fares), 0, null, legs, false, false), 16);
  }

  // --- Ronda 0: accesos ---
  let marked = new Set<number>();
  let prevRound = new Map<number, Label[]>();
  const offer = (round: Map<number, Label[]>, stop: number, lab: Label, newly: Set<number>): void => {
    if (target.some((t) => t.arr <= lab.arr && t.cost <= lab.cost && t.co2 <= lab.co2)) return;
    const bestBag = best.get(stop) ?? [];
    if (!mergeIntoBag(bestBag, { ...lab })) return;
    best.set(stop, bestBag);
    const bag = round.get(stop) ?? [];
    if (mergeIntoBag(bag, lab)) {
      round.set(stop, bag);
      newly.add(stop);
    }
  };

  for (const { idx, distM } of net.stopIndex.within(origin, opts.maxWalkAccessM)) {
    const arr = departure + walkSeconds(distM);
    offer(prevRound, idx, label(arr, 0, 0, null, [walkLeg(origin, net.stopPos(idx), departure, arr, stops.name[idx])], false, false), marked);
  }
  if (pickup) {
    for (const { idx } of net.stopIndex.within(origin, opts.maxBikeAccessM)) {
      const station = net.nearestStation[idx];
      if (!net.isRailStop[idx] || station < 0 || station === pickup.idx) continue;
      if (!opts.stationUsable(station, 'dropoff')) continue;
      const legs = bikeChain(net, origin, pickup, { idx: station, distM: net.nearestStationM[idx] }, { ...net.stopPos(idx), label: stops.name[idx] }, departure);
      const arr = legs[legs.length - 1].arr;
      offer(prevRound, idx, label(arr, legCost(legs, opts.fares), 0, null, legs, false, false), marked);
    }
  }

  const egress = buildEgress(net, dest, dropoff, opts);

  // --- Rondas ---
  for (let k = 1; k <= opts.maxRides && marked.size > 0; k++) {
    const round = new Map<number, Label[]>();
    const newly = new Set<number>();
    const queue = new Map<number, number>();
    for (const s of marked) {
      for (const { p, pos } of net.stopPatterns[s]) {
        if (pos < patterns[p].s.length - 1) queue.set(p, Math.min(queue.get(p) ?? pos, pos));
      }
    }

    for (const [p, startPos] of queue) {
      const pattern = patterns[p];
      const route = net.route(p);
      const factor = opts.emissions[route.mode];
      let routeBag: RouteBagEntry[] = [];
      for (let pos = startPos; pos < pattern.s.length; pos++) {
        const stop = pattern.s[pos];
        for (const rb of routeBag) {
          if (pos === rb.boardPos) continue;
          const dep = net.tripTime(p, rb.trip, rb.boardPos);
          const arr = net.tripTime(p, rb.trip, pos);
          const distM = pattern.d[pos] - pattern.d[rb.boardPos];
          const ride: Leg = { kind: 'ride', pattern: p, route: pattern.r, mode: route.mode, boardPos: rb.boardPos, alightPos: pos, dep, arr, distM };
          offer(round, stop, label(arr, rb.cost, rb.label.co2 + (distM / 1000) * factor, rb.label, [ride], route.mode === 'metro', true), newly);
        }
        const boardable = prevRound.get(stop);
        if (boardable && pos < pattern.s.length - 1) {
          for (const lab of boardable) {
            const trip = net.earliestTrip(p, pos, lab.arr);
            if (trip < 0) continue;
            const entry = { label: lab, trip, boardPos: pos, cost: lab.cost + boardingCost(opts.fares, route.mode, lab.inMetro) };
            routeBag = mergeRouteBag(routeBag, entry);
          }
        }
      }
    }

    // transbordos a pie desde llegadas en vehículo
    const { start, to, sec } = net.data.transfers;
    for (const s of [...newly]) {
      for (const lab of round.get(s) ?? []) {
        if (!lab.fromRide) continue;
        for (let e = start[s]; e < start[s + 1]; e++) {
          const t = to[e];
          const arr = lab.arr + sec[e];
          const leg = walkLeg(net.stopPos(s), net.stopPos(t), lab.arr, arr, stops.name[t]);
          offer(round, t, label(arr, lab.cost, lab.co2, lab, [leg], lab.inMetro, false), newly);
        }
      }
    }

    // egresos hacia el destino
    for (const s of newly) {
      for (const lab of round.get(s) ?? []) {
        for (const eg of egress.get(s) ?? []) {
          mergeIntoBag(target, label(lab.arr + eg.sec, lab.cost + eg.cost, lab.co2, lab, eg.build(lab.arr), false, false), 16);
        }
      }
    }
    prevRound = round;
    marked = newly;
  }

  return toJourneys(target, origin, dest, opts);
}

function label(arr: number, cost: number, co2: number, prev: Label | null, legs: Leg[], inMetro: boolean, fromRide: boolean): Label {
  return { arr, cost, co2, prev, legs, inMetro, fromRide };
}

function walkLeg(from: LatLon, to: LatLon, dep: number, arr: number, toLabel: string): Leg {
  return { kind: 'walk', from: { lat: from.lat, lon: from.lon }, to: { lat: to.lat, lon: to.lon }, dep, arr, distM: haversineM(from, to), toLabel };
}

function mergeRouteBag(bag: RouteBagEntry[], entry: RouteBagEntry): RouteBagEntry[] {
  const dominates = (a: RouteBagEntry, b: RouteBagEntry): boolean =>
    a.trip <= b.trip && a.cost <= b.cost && a.label.co2 <= b.label.co2;
  if (bag.some((b) => dominates(b, entry))) return bag;
  return [...bag.filter((b) => !dominates(entry, b)), entry];
}

function nearestUsableStation(
  net: PreparedNetwork,
  place: LatLon,
  use: 'pickup' | 'dropoff',
  usable: (s: number, u: 'pickup' | 'dropoff') => boolean,
): { idx: number; distM: number } | undefined {
  return net.bikeIndex.within(place, STATION_NEAR_PLACE_M).find(({ idx }) => usable(idx, use));
}

/** a pie → estación → bici → estación → a pie */
function bikeChain(
  net: PreparedNetwork,
  from: Place | LatLon,
  pickup: { idx: number; distM: number },
  dropoff: { idx: number; distM: number },
  to: Place,
  departure: number,
): Leg[] {
  const a = net.stationPos(pickup.idx);
  const b = net.stationPos(dropoff.idx);
  const t1 = departure + walkSeconds(pickup.distM);
  const t2 = t1 + ACTIVE.dockHandlingS + bikeSeconds(haversineM(a, b)) + ACTIVE.dockHandlingS;
  const t3 = t2 + walkSeconds(dropoff.distM);
  return [
    walkLeg(from, a, departure, t1, net.data.bike.name[pickup.idx]),
    { kind: 'bike', fromStation: pickup.idx, toStation: dropoff.idx, dep: t1, arr: t2, distM: haversineM(a, b) },
    walkLeg(b, to, t2, t3, to.label),
  ];
}

function legCost(legs: Leg[], fares: FareConfig): number {
  return legs.reduce((acc, l) => (l.kind === 'bike' ? acc + bikeShareCost(fares, l.arr - l.dep) : acc), 0);
}

function buildEgress(
  net: PreparedNetwork,
  dest: Place,
  dropoff: { idx: number; distM: number } | undefined,
  opts: Required<RouterOptions>,
): Map<number, Egress[]> {
  const out = new Map<number, Egress[]>();
  const add = (s: number, e: Egress): void => {
    const list = out.get(s) ?? [];
    list.push(e);
    out.set(s, list);
  };
  for (const { idx, distM } of net.stopIndex.within(dest, opts.maxWalkAccessM)) {
    const sec = walkSeconds(distM);
    add(idx, { sec, cost: 0, build: (t) => [walkLeg(net.stopPos(idx), dest, t, t + sec, dest.label)] });
  }
  if (!dropoff) return out;
  for (const { idx } of net.stopIndex.within(dest, opts.maxBikeAccessM)) {
    const station = net.nearestStation[idx];
    if (!net.isRailStop[idx] || station < 0 || station === dropoff.idx) continue;
    if (!opts.stationUsable(station, 'pickup')) continue;
    const pickup = { idx: station, distM: net.nearestStationM[idx] };
    const probe = bikeChain(net, net.stopPos(idx), pickup, dropoff, dest, 0);
    const sec = probe[probe.length - 1].arr;
    const cost = legCost(probe, opts.fares);
    add(idx, { sec, cost, build: (t) => bikeChain(net, net.stopPos(idx), pickup, dropoff, dest, t) });
  }
  return out;
}

function toJourneys(target: Label[], origin: Place, dest: Place, opts: Required<RouterOptions>): Journey[] {
  const journeys = target.map((t) => {
    const legs: Leg[] = [];
    for (let l: Label | null = t; l; l = l.prev) legs.unshift(...l.legs);
    mergeConsecutiveWalks(legs);
    shiftLeadingActiveLegs(legs);
    const rides = legs.filter((l) => l.kind === 'ride').length;
    return {
      dep: legs[0].dep,
      arr: legs[legs.length - 1].arr,
      legs,
      costCents: journeyFare(opts.fares, legs),
      co2g: journeyCo2(opts.emissions, legs),
      carCo2g: carCo2(opts.emissions, haversineM(origin, dest)),
      transfers: Math.max(0, rides - 1),
    } satisfies Journey;
  });
  const key = (j: Journey): Criteria => ({ arr: j.arr, cost: j.costCents, co2: Math.round(j.co2g / 10) * 10 });
  return practicalFront(paretoFront(journeys, key).sort((a, b) => a.arr - b.arr));
}

/**
 * Dominancia "práctica": descarta alternativas que no mejoran de forma apreciable a otra ya
 * aceptada (≤ 2 min más rápida, ≤ 0,10 € más barata y ≤ 10 % + 10 g menos CO2).
 * Reduce la carga cognitiva sin perder compromisos reales.
 */
export function practicalFront(sortedByArrival: Journey[]): Journey[] {
  const kept: Journey[] = [];
  for (const j of sortedByArrival) {
    const redundant = kept.some(
      (k) => k.arr <= j.arr + 120 && k.costCents <= j.costCents + 10 && k.co2g <= j.co2g * 1.1 + 10,
    );
    if (!redundant) kept.push(j);
  }
  return kept;
}

function mergeConsecutiveWalks(legs: Leg[]): void {
  for (let i = legs.length - 1; i > 0; i--) {
    const a = legs[i - 1];
    const b = legs[i];
    if (a.kind === 'walk' && b.kind === 'walk') {
      legs.splice(i - 1, 2, { ...a, to: b.to, arr: b.arr, distM: a.distM + b.distM, toLabel: b.toLabel });
    }
  }
}

/** Retrasa los tramos a pie/bici iniciales para que el usuario no espere en la parada. */
function shiftLeadingActiveLegs(legs: Leg[]): void {
  const firstRide = legs.findIndex((l) => l.kind === 'ride');
  if (firstRide <= 0) return;
  const slack = legs[firstRide].dep - legs[firstRide - 1].arr;
  if (slack <= 0) return;
  for (let i = 0; i < firstRide; i++) {
    legs[i] = { ...legs[i], dep: legs[i].dep + slack, arr: legs[i].arr + slack };
  }
}

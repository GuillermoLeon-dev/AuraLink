/// <reference lib="webworker" />
/**
 * Web Worker de enrutamiento: carga la red una vez y resuelve consultas fuera del hilo de UI.
 * El origen y el destino llegan por postMessage y nunca salen del dispositivo.
 */
import { PreparedNetwork } from '../domain/network';
import { planJourneys } from '../domain/raptor';
import type { EmissionFactors, FareConfig, Journey, NetworkData, Place } from '../domain/types';

export type WorkerRequest =
  | { type: 'init'; url: string }
  | {
      type: 'plan';
      id: number;
      origin: Place;
      dest: Place;
      departure: number;
      fares: FareConfig;
      emissions: EmissionFactors;
      /** índices de estaciones no utilizables (exclusiones del técnico / no operativas) */
      blockedPickup: number[];
      blockedDropoff: number[];
    };

export type WorkerResponse =
  | { type: 'ready'; network: NetworkData; ms: number }
  | { type: 'result'; id: number; journeys: Journey[]; ms: number }
  | { type: 'error'; id?: number; message: string };

let net: PreparedNetwork | null = null;
const scope = self as unknown as DedicatedWorkerGlobalScope;

scope.onmessage = async (ev: MessageEvent<WorkerRequest>) => {
  const msg = ev.data;
  try {
    if (msg.type === 'init') {
      const t0 = performance.now();
      const data = (await (await fetch(msg.url, { credentials: 'omit' })).json()) as NetworkData;
      net = new PreparedNetwork(data);
      const response: WorkerResponse = { type: 'ready', network: data, ms: performance.now() - t0 };
      scope.postMessage(response);
      return;
    }
    if (!net) throw new Error('red no cargada');
    const t0 = performance.now();
    const pickup = new Set(msg.blockedPickup);
    const dropoff = new Set(msg.blockedDropoff);
    const journeys = planJourneys(net, msg.origin, msg.dest, msg.departure, {
      fares: msg.fares,
      emissions: msg.emissions,
      stationUsable: (s, use) => !(use === 'pickup' ? pickup : dropoff).has(s),
    });
    const response: WorkerResponse = { type: 'result', id: msg.id, journeys, ms: performance.now() - t0 };
    scope.postMessage(response);
  } catch (err) {
    scope.postMessage({ type: 'error', id: msg.type === 'plan' ? msg.id : undefined, message: String(err) } satisfies WorkerResponse);
  }
};

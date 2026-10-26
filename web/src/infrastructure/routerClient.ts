import type { EmissionFactors, FareConfig, Journey, NetworkData, Place } from '../domain/types';
import { networkUrl } from './dataClient';
import type { WorkerRequest, WorkerResponse } from './router.worker';

export interface PlanRequest {
  origin: Place;
  dest: Place;
  departure: number;
  fares: FareConfig;
  emissions: EmissionFactors;
  blockedPickup: number[];
  blockedDropoff: number[];
}

/** Puerto de enrutamiento: envuelve el Worker en una API de promesas. */
export class RouterClient {
  private readonly worker = new Worker(new URL('./router.worker.ts', import.meta.url), { type: 'module' });
  private readonly pending = new Map<number, { resolve: (v: { journeys: Journey[]; ms: number }) => void; reject: (e: Error) => void }>();
  private nextId = 1;
  readonly ready: Promise<{ network: NetworkData; ms: number }>;

  constructor() {
    this.ready = new Promise((resolve, reject) => {
      this.worker.onmessage = (ev: MessageEvent<WorkerResponse>) => {
        const msg = ev.data;
        if (msg.type === 'ready') resolve({ network: msg.network, ms: msg.ms });
        else if (msg.type === 'result') this.pending.get(msg.id)?.resolve({ journeys: msg.journeys, ms: msg.ms });
        else if (msg.id !== undefined) this.pending.get(msg.id)?.reject(new Error(msg.message));
        else reject(new Error(msg.message));
        if (msg.type !== 'ready' && msg.id !== undefined) this.pending.delete(msg.id);
      };
    });
    this.post({ type: 'init', url: new URL(networkUrl(), window.location.href).toString() });
  }

  plan(req: PlanRequest): Promise<{ journeys: Journey[]; ms: number }> {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.post({ type: 'plan', id, ...req });
    });
  }

  dispose(): void {
    this.worker.terminate();
    this.pending.forEach((p) => p.reject(new Error('router cerrado')));
    this.pending.clear();
  }

  private post(msg: WorkerRequest): void {
    this.worker.postMessage(msg);
  }
}

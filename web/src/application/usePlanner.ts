import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { assessJourney, StationLookup, stationUsability } from '../domain/fusion';
import { PreparedNetwork } from '../domain/network';
import { rankJourneys, type Preference, type RankedJourney } from '../domain/ranking';
import type { NetworkData, Place } from '../domain/types';
import { fetchContext, type ContextWithConfig } from '../infrastructure/dataClient';
import { RouterClient } from '../infrastructure/routerClient';

export type LoadState = 'loading' | 'ready' | 'error';

export interface PlanQuery {
  origin: Place;
  dest: Place;
  /** segundos desde medianoche */
  departure: number;
  fareProfile: string;
}

export const secondsSinceMidnight = (d = new Date()): number => d.getHours() * 3600 + d.getMinutes() * 60;

/** Caso de uso "planificar viaje": orquesta Worker (rutas) + fusión + ranking. */
export function usePlanner() {
  const router = useRef<RouterClient | null>(null);
  const [network, setNetwork] = useState<NetworkData | null>(null);
  const [prepared, setPrepared] = useState<PreparedNetwork | null>(null);
  const [ctx, setCtx] = useState<ContextWithConfig | null>(null);
  const [state, setState] = useState<LoadState>('loading');
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<{ query: PlanQuery; items: Omit<RankedJourney, 'score' | 'badges'>[]; ms: number } | null>(null);
  const [preference, setPreference] = useState<Preference>('balanced');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const client = new RouterClient();
    router.current = client;
    let active = true;
    Promise.all([client.ready, fetchContext().catch(() => null)])
      .then(([{ network: net }, context]) => {
        if (!active) return;
        setNetwork(net);
        setPrepared(new PreparedNetwork(net));
        setCtx(context);
        setState('ready');
      })
      .catch((e: unknown) => {
        if (!active) return;
        setError(String(e));
        setState('error');
      });
    return () => {
      active = false;
      client.dispose();
    };
  }, []);

  const stations = useMemo(() => new StationLookup(ctx), [ctx]);

  const plan = useCallback(
    async (query: PlanQuery) => {
      if (!router.current || !prepared || !ctx) return;
      setBusy(true);
      try {
        const usable = stationUsability(ctx, prepared, stations);
        const ids = prepared.data.bike.id.map((_, i) => i);
        const fares = ctx.config.fares.profiles[query.fareProfile] ?? ctx.config.fares.profiles[ctx.config.fares.default_profile];
        const { journeys, ms } = await router.current.plan({
          origin: query.origin,
          dest: query.dest,
          departure: query.departure,
          fares,
          emissions: ctx.config.emissions.factors_g_per_pkm,
          blockedPickup: ids.filter((i) => !usable(i, 'pickup')),
          blockedDropoff: ids.filter((i) => !usable(i, 'dropoff')),
        });
        const nowSec = secondsSinceMidnight();
        const items = journeys.map((journey) => ({
          journey,
          assessment: assessJourney(journey, { ctx, stations, net: prepared, nowSec: Math.min(nowSec, query.departure) }),
        }));
        setResults({ query, items, ms });
      } catch (e) {
        setError(String(e));
      } finally {
        setBusy(false);
      }
    },
    [ctx, prepared, stations],
  );

  const ranked = useMemo(() => (results ? rankJourneys(results.items, preference) : []), [results, preference]);

  return { state, error, network, prepared, ctx, stations, plan, busy, results, ranked, preference, setPreference, clear: () => setResults(null) };
}

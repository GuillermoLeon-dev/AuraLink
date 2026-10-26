"""Utilidades geográficas vectorizadas."""

from __future__ import annotations

import numpy as np
import numpy.typing as npt

EARTH_RADIUS_M = 6_371_000.0

FloatArray = npt.NDArray[np.float64]


def haversine_m(
    lat1: FloatArray | float, lon1: FloatArray | float, lat2: FloatArray | float, lon2: FloatArray | float
) -> FloatArray:
    lat1r, lat2r = np.radians(lat1), np.radians(lat2)
    dlat = lat2r - lat1r
    dlon = np.radians(np.asarray(lon2) - np.asarray(lon1))
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1r) * np.cos(lat2r) * np.sin(dlon / 2) ** 2
    return np.asarray(2 * EARTH_RADIUS_M * np.arcsin(np.sqrt(a)), dtype=np.float64)


def pairs_within(
    lat: FloatArray, lon: FloatArray, radius_m: float
) -> tuple[npt.NDArray[np.int64], npt.NDArray[np.int64], FloatArray]:
    """Pares (i, j), i != j, a menos de ``radius_m`` usando una rejilla espacial (O(n·k))."""
    cell_deg = radius_m / 111_000.0
    gy = np.floor(lat / cell_deg).astype(np.int64)
    gx = np.floor(lon / (cell_deg / np.cos(np.radians(np.mean(lat))))).astype(np.int64)
    buckets: dict[tuple[int, int], list[int]] = {}
    for idx, key in enumerate(zip(gy.tolist(), gx.tolist(), strict=True)):
        buckets.setdefault(key, []).append(idx)

    src: list[int] = []
    dst: list[int] = []
    for (cy, cx), members in buckets.items():
        neighbours = [j for dy in (-1, 0, 1) for dx in (-1, 0, 1) for j in buckets.get((cy + dy, cx + dx), [])]
        nb = np.asarray(neighbours, dtype=np.int64)
        for i in members:
            d = haversine_m(lat[i], lon[i], lat[nb], lon[nb])
            mask = (d <= radius_m) & (nb != i)
            src.extend([i] * int(mask.sum()))
            dst.extend(nb[mask].tolist())
    s = np.asarray(src, dtype=np.int64)
    t = np.asarray(dst, dtype=np.int64)
    return s, t, haversine_m(lat[s], lon[s], lat[t], lon[t])

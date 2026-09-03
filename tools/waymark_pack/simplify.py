"""Geometry simplification (spec 5.2 step 4).

``simplify(tolerance=0.001, preserve_topology=True)``. 0.001 degrees ≈ 100 m. GPS itself
drifts ±20 m, so higher resolution is meaningless and just inflates the pack.
"""

from __future__ import annotations

from .polygon import Ring


def simplify_rings(rings: list[Ring], tolerance_deg: float) -> list[Ring]:
    """Simplify every ring, preserving topology and dropping any that collapse.

    Requires shapely. A ring that simplifies below 3 points (degenerate) is dropped;
    if the outer ring collapses, an empty list is returned and the caller must report it.
    """
    from shapely.geometry import LinearRing

    out: list[Ring] = []
    for ring in rings:
        lr = LinearRing(ring.points)
        simplified = lr.simplify(tolerance_deg, preserve_topology=True)
        coords = list(simplified.coords)
        if len(coords) < 4:  # LinearRing repeats the first point, so 4 coords = 3 vertices
            if not ring.is_hole:
                return []  # outer ring gone -> whole polygon is invalid
            continue       # a vanished hole is fine
        out.append(Ring(is_hole=ring.is_hole, points=coords))
    return out


def close_ring(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """Ensure the first and last point coincide (a closed ring)."""
    if not points:
        return points
    if points[0] != points[-1]:
        return [*points, points[0]]
    return points


def has_unclosed_ring(rings: list[Ring]) -> bool:
    """spec 5.2 step 3 validation: report rings whose ends do not meet."""
    return any(r.points and r.points[0] != r.points[-1] for r in rings)

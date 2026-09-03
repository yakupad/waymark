"""Name normalisation and TÜİK code matching (spec 5.2 step 5, R6).

The İ/ı trap: ``"İSTANBUL".lower()`` in a default locale produces ``"i̇stanbul"`` with a
combining dot; ``"ISTANBUL".lower()`` produces ``"istanbul"`` not ``"ıstanbul"``. Turkish
has a dotless ``ı`` and a dotted ``i``/``İ``. Matching must fold case the Turkish way.

Names are NEVER used as a join key between OSM and TÜİK — 1041 relations yield only 1013
unique names (28 collisions). The join goes through OSM relation id + parent_id, and the
TÜİK link goes through the administrative code. Normalisation here is only for the
code-lookup fallback and for de-duplication reports.
"""

from __future__ import annotations

# Turkish-specific case mapping. Applied before str.casefold() so the ASCII-folding
# rules don't mangle the dotted/dotless i distinction.
_TR_LOWER = str.maketrans(
    {
        "İ": "i",
        "I": "ı",
        "Ş": "ş",
        "Ğ": "ğ",
        "Ü": "ü",
        "Ö": "ö",
        "Ç": "ç",
    }
)

_TR_UPPER = str.maketrans(
    {
        "i": "İ",
        "ı": "I",
        "ş": "Ş",
        "ğ": "Ğ",
        "ü": "Ü",
        "ö": "Ö",
        "ç": "Ç",
    }
)


def tr_lower(text: str) -> str:
    """Lowercase the Turkish way: I→ı, İ→i."""
    return text.translate(_TR_LOWER).lower()


def tr_upper(text: str) -> str:
    """Uppercase the Turkish way: i→İ, ı→I."""
    return text.translate(_TR_UPPER).upper()


def normalize(name: str, locale: str = "tr_TR") -> str:
    """Fold a place name to a comparison key.

    Only ``tr_TR`` is special-cased today; any other locale uses plain casefold. Keeps
    the door open for other regions without branching pipeline code (spec K6).
    """
    collapsed = " ".join(name.split())
    if locale == "tr_TR":
        return tr_lower(collapsed)
    return collapsed.casefold()


def plaka_from_iso3166_2(tag_value: str, prefix: str) -> str | None:
    """Extract the plaka / admin code from an ``ISO3166-2`` tag.

    ``"TR-34"`` with prefix ``"TR-"`` -> ``"34"``. Returns None if the tag does not match.
    """
    if not tag_value or not tag_value.startswith(prefix):
        return None
    code = tag_value[len(prefix) :].strip()
    return code or None


def find_name_collisions(names: list[str], locale: str = "tr_TR") -> dict[str, list[int]]:
    """Group indices of ``names`` that normalise to the same key. 28 expected for TR."""
    buckets: dict[str, list[int]] = {}
    for i, name in enumerate(names):
        buckets.setdefault(normalize(name, locale), []).append(i)
    return {key: idxs for key, idxs in buckets.items() if len(idxs) > 1}

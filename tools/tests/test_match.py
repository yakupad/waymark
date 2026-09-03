"""Name normalisation — spec 5.2 step 5, R6 (the İ/ı trap)."""

from waymark_pack import match


def test_turkish_lowercase_dotless_i():
    # I -> ı (dotless), not i
    assert match.tr_lower("ISPARTA") == "ısparta"
    # İ -> i (dotted)
    assert match.tr_lower("İSTANBUL") == "istanbul"


def test_turkish_lowercase_full_alphabet():
    assert match.tr_lower("ÇANKIRI") == "çankırı"
    assert match.tr_lower("MUĞLA") == "muğla"
    assert match.tr_lower("ŞIRNAK") == "şırnak"
    assert match.tr_lower("GÜMÜŞHANE") == "gümüşhane"


def test_turkish_uppercase_is_inverse_ish():
    assert match.tr_upper("istanbul") == "İSTANBUL"
    assert match.tr_upper("ısparta") == "ISPARTA"


def test_normalize_collapses_whitespace():
    assert match.normalize("  Afyon   Karahisar ") == "afyon karahisar"


def test_normalize_non_turkish_locale_uses_casefold():
    assert match.normalize("ISTANBUL", locale="en_US") == "istanbul"


def test_default_lower_would_get_isparta_wrong():
    # documents *why* we need tr_lower: str.lower() keeps the dot
    assert "ISPARTA".lower() == "isparta"          # wrong for Turkish
    assert match.tr_lower("ISPARTA") == "ısparta"  # right


def test_plaka_extracted_from_iso_tag():
    assert match.plaka_from_iso3166_2("TR-34", "TR-") == "34"
    assert match.plaka_from_iso3166_2("TR-06", "TR-") == "06"
    assert match.plaka_from_iso3166_2("GE-AB", "TR-") is None
    assert match.plaka_from_iso3166_2("", "TR-") is None


def test_find_name_collisions_groups_case_insensitively():
    names = ["Merkez", "MERKEZ", "Eyyübiye", "Şehitkamil"]
    collisions = match.find_name_collisions(names)
    assert list(collisions.values()) == [[0, 1]]

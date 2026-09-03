"""Wikipedia summary fetching (spec 5.2 step 6, İ4, R13).

Only tier 1-2 units get summaries (~1050 rows). Villages do not — spec İ4 (don't invent
history for tiny places) and the size budget. Each language is a separate ``article`` row
(spec schema İ5). At the end the pipeline reports per-language coverage; below
``min_coverage_warn`` the report flags the EN content strategy (R13).

Network is optional: if requests is missing or offline, the pipeline warns and continues
with no summaries.
"""

from __future__ import annotations

import json
import time
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

from .model import Article


@dataclass
class SummaryResult:
    lang: str
    summary: str
    source_url: str


@dataclass
class CoverageReport:
    lang: str
    have: int
    total: int

    @property
    def ratio(self) -> float:
        return self.have / self.total if self.total else 0.0


class ContentFetcher:
    """Fetches article summaries. Injectable ``session`` for tests / offline runs.

    A ``cache_path`` (JSON keyed by ``lang/title``) makes re-runs network-free and the
    build deterministic. Wikimedia rate-limits anonymous clients, so every request is
    throttled and 429s are retried once after a longer wait.
    """

    # Wikimedia asks anonymous tools to identify themselves with a contact URL.
    _UA = "Waymark-pack/1.0 (https://github.com/; offline travel companion)"

    def __init__(
        self, api_template: str, languages: list[str], session=None,
        delay: float = 0.15, cache_path: Path | None = None, offline: bool = False,
    ):
        self.api_template = api_template
        self.languages = languages
        self.delay = delay
        self.offline = offline
        self._session = session
        self._warned = False
        self._cache_path = cache_path
        self._cache: dict[str, dict | None] = _load_json(cache_path) if cache_path else {}
        self._dirty = 0

    def fetch(self, title_by_lang: dict[str, str]) -> list[SummaryResult]:
        """Fetch one entity's summaries. ``title_by_lang`` maps lang -> Wikipedia title."""
        results: list[SummaryResult] = []
        for lang in self.languages:
            title = title_by_lang.get(lang)
            if not title:
                continue
            data = self._summary(lang, title)
            if not data:
                continue
            extract = (data.get("extract") or "").strip()
            if not extract:
                continue
            page_url = (
                data.get("content_urls", {}).get("desktop", {}).get("page")
                or f"https://{lang}.wikipedia.org/wiki/{urllib.parse.quote(title)}"
            )
            results.append(SummaryResult(lang=lang, summary=extract, source_url=page_url))
        return results

    def flush(self) -> None:
        if self._cache_path and self._dirty:
            _save_json(self._cache_path, self._cache)
            self._dirty = 0

    # ---------------------------------------------------------------- internals

    def _summary(self, lang: str, title: str) -> dict | None:
        key = f"{lang}/{title}"
        if key in self._cache:
            return self._cache[key]
        if self.offline:
            return None

        session = self._get_session()
        if session is None:
            return None

        url = self.api_template.format(
            lang=lang, title=urllib.parse.quote(title.replace(" ", "_"))
        )
        data: dict | None = None
        for attempt in range(2):
            time.sleep(self.delay)
            try:
                resp = session.get(url, timeout=20, headers={"User-Agent": self._UA})
            except Exception:  # noqa: BLE001 - transient, treat as miss
                break
            if resp.status_code == 200:
                try:
                    data = resp.json()
                except Exception:  # noqa: BLE001
                    data = None
                break
            if resp.status_code in (429, 503) and attempt == 0:
                time.sleep(2.0)
                continue
            break  # 404 etc. -> genuine miss

        self._cache[key] = data
        self._dirty += 1
        if self._cache_path and self._dirty >= 50:
            self.flush()
        return data

    def _get_session(self):
        if self._session is not None:
            return self._session
        try:
            import requests

            self._session = requests.Session()
        except ImportError:
            if not self._warned:
                print("  content: 'requests' not installed — skipping summaries")
                self._warned = True
            self._session = None
        return self._session


def _load_json(path: Path | None) -> dict:
    if path and path.is_file():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def _save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
        encoding="utf-8",
    )


def coverage(articles: list[Article], entity_ids: set[int], languages: list[str]) -> list[CoverageReport]:
    """Per-language coverage over the set of entities that *should* have content."""
    total = len(entity_ids)
    reports: list[CoverageReport] = []
    for lang in languages:
        have = len({a.entity_id for a in articles if a.lang == lang and a.entity_id in entity_ids})
        reports.append(CoverageReport(lang=lang, have=have, total=total))
    return reports

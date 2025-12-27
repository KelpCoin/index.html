# Law Knowledge Collector (Public Sources)

`collector_law_public.py` ingests openly reusable legal content. It can be run
on Windows (PowerShell scheduler) or any Python environment.

## What it does
- Respects `robots.txt` for every domain before scraping.
- Prefers public domain or open-license sources; warns when the license cannot
  be confirmed.
- Saves normalized plain-text files to `data/` and tracks metadata in
  `data/metadata.jsonl` (`source_url`, `license`, `last_fetched`, `text_path`,
  `label`).
- Avoids logins, paywalls, or any other gated content.

## Running
```powershell
# Optional: create & activate a virtual environment
python -m venv .venv
. .venv/Scripts/Activate.ps1

pip install -r requirements.txt  # or pip install requests beautifulsoup4

python .\collector_law_public.py
```

## Adding new sources
1. Confirm the license allows reuse (public domain, CC-BY, or similar).
2. Verify the URL is reachable without authentication or payment.
3. Ensure `robots.txt` allows the path for the configured user agent.
4. Append a new `Source` entry in `collector_law_public.py` with `url`,
   `license` (use `None` if unknown), and a descriptive `label`.

# CLAUDE.md

Guidance for AI assistants (Claude Code and others) working in this repository.

## What this project is

This is the **"Emotion Detection"** application — the final project for IBM's
*"Developing AI Applications with Python and Flask"* course (project slug
`oaqjp-final-project-emb-ai`). The goal is a small web app that accepts a piece
of text, sends it to IBM Watson's NLP **EmotionPredict** embeddable model, and
returns the detected emotions (`anger`, `disgust`, `fear`, `joy`, `sadness`)
plus the **dominant emotion**.

> **Current state (important):** the repository is still at its *starter*
> stage. Only the front-end template and project scaffolding exist. The Python
> package, Flask server, and tests described below are the **target** structure
> the project is meant to grow into — they have not been committed yet. Treat
> the "Intended structure" section as the spec to build toward, and the
> "Current files" section as ground truth for what exists today.

## Current files

```
.
├── README.md             # Placeholder ("Repository for final project")
├── LICENSE               # Apache License 2.0
├── .gitignore            # Standard Python .gitignore
├── static/
│   └── mywebscript.js    # Front-end: sends text to the server, renders result
└── templates/
    └── index.html        # Bootstrap UI with a text input + "Run" button
```

### Front-end contract (already defined — build the backend to match it)

`static/mywebscript.js` and `templates/index.html` pin down the API the backend
must implement:

- The page has an input `#textToAnalyze` and a button that calls
  `RunSentimentAnalysis()`.
- That function issues `GET emotionDetector?textToAnalyze=<text>` and writes the
  raw `responseText` into `#system_response` via `innerHTML`.

So the Flask backend **must** expose a route at `/emotionDetector` that reads the
`textToAnalyze` query parameter and returns a plain string (not JSON) suitable
for direct HTML insertion.

## Intended structure (the target for this project)

The course project conventionally adds these files. Create them at the repo root
unless told otherwise:

```
EmotionDetection/
├── __init__.py            # exposes emotion_detector
└── emotion_detection.py   # emotion_detector(text_to_analyze) -> dict
server.py                  # Flask app wiring the package to the front-end
test_emotion_detection.py  # unit tests for emotion_detector
requirements.txt           # pinned deps (flask, requests, ...)
```

### `emotion_detector(text_to_analyze)`

- POSTs to the Watson NLP EmotionPredict endpoint:
  `https://sn-watson-emotion.labs.skills.network/v1/watson.runtime.nlp.v1/NlpService/EmotionPredict`
- Header: `{"grpc-metadata-mm-model-id": "emotion_aggregated-workflow_lang_en_stock"}`
- Body: `{"raw_document": {"text": text_to_analyze}}`
- Returns a dict with keys `anger`, `disgust`, `fear`, `joy`, `sadness`, and
  `dominant_emotion` (the key with the highest score).
- **Error handling:** when the API returns HTTP `400` (blank/invalid input),
  return the same dict with every value set to `None`. The server turns this
  into an "Invalid text! Please try again!" message.

### `server.py`

- Flask app rendering `templates/index.html` at `/`.
- Route `/emotionDetector` reads `request.args.get("textToAnalyze")`, calls
  `emotion_detector`, and returns a formatted **string** like:
  `"For the given statement, the system response is 'anger': 0.0, ... and
  'sadness': 0.0. The dominant emotion is joy."`
- If `dominant_emotion is None`, return `"Invalid text! Please try again!"`.

## Development workflow

### Branching & commits

- **Active development branch:** `claude/claude-md-docs-VBpEA`. Do all work here
  and push with `git push -u origin claude/claude-md-docs-VBpEA`.
- Never push to another branch without explicit permission.
- Do **not** open a pull request unless the user explicitly asks.
- Write clear, descriptive commit messages.

### Running locally (once the backend exists)

```bash
pip install -r requirements.txt   # once requirements.txt exists
python server.py                  # serves on http://localhost:5000
```

### Testing & quality (course requirements)

The course grades this project on several deliverables. When adding code, also
satisfy these:

- **Unit tests:** `python -m unittest test_emotion_detection.py` — assert the
  `dominant_emotion` for known sample sentences (e.g. "I am glad..." → `joy`,
  "I am really mad..." → `anger`).
- **Static analysis:** code must score **10/10** with PyLint
  (`pylint server.py`). Add module/function docstrings and keep style clean.
- **Error handling** and **packaging** (the `EmotionDetection/` folder with
  `__init__.py`) are explicit grading items.

> The Watson NLP endpoint above is only reachable from inside the IBM Skills
> Network Cloud IDE lab environment. It will not resolve on the open internet,
> so live calls to `emotion_detector` cannot be exercised here — keep that in
> mind when verifying changes.

## Conventions for AI assistants

- **Match the front-end contract** — the route name (`/emotionDetector`), the
  query param (`textToAnalyze`), and the plain-string response are fixed by the
  existing JS/HTML. Change the backend to fit them, not the reverse.
- **Keep it minimal.** This is a teaching project; prefer the simple, idiomatic
  course solution over abstractions. Don't add frameworks or tooling that the
  course doesn't call for.
- **Preserve PyLint 10/10** when editing Python — docstrings on every module and
  function, no unused imports.
- **Don't commit secrets or virtualenvs** — the `.gitignore` already covers
  `.env`, `venv/`, `__pycache__/`, etc.
- This is an **Apache-2.0** licensed repo; keep the LICENSE intact.

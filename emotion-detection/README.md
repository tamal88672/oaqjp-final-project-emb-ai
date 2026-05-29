# Emotion Detection

A self-contained Flask web application that detects five emotions in text
(anger, disgust, fear, joy, sadness) using a built-in lexicon, with no external
AI or cloud services required.

## What it does

Modeled on the classic IBM "AI-based Web Application" final project (embeddable
emotion detection), this version replaces the Watson NLP cloud API with a local,
keyword-based analyzer. You paste in some text and it returns a normalized score
for each of the five emotions plus the dominant emotion. Because all analysis
happens locally, the app runs fully offline and is a clean way to learn how to
package an analysis library, expose it over a REST API, and wrap it in a web UI.

## Features

- Five-emotion detection: anger, disgust, fear, joy, sadness
- Offline, lexicon-based analyzer (no external API needed)
- Clean, responsive single-page web UI with colored emotion bars
- REST endpoints: an IBM-compatible string response and a raw JSON response
- Robust blank/invalid input handling
- Unit tested with Python's `unittest`

## Project structure

```
emotion-detection/
├── EmotionDetection/
│   ├── __init__.py            # exports emotion_detector
│   └── emotion_detection.py   # lexicon-based analyzer
├── templates/
│   └── index.html             # web UI
├── static/
│   └── mywebscript.js         # frontend logic (fetch + bars)
├── server.py                  # Flask app
├── test_emotion_detection.py  # unit tests
├── requirements.txt
└── README.md
```

## Install & run

```bash
pip install -r requirements.txt
python server.py
```

Then open http://localhost:5050 in your browser.

## API reference

### `GET /emotionDetector?textToAnalyze=<text>`

IBM-compatible endpoint that returns a formatted string:

```
For the given statement, the system response is 'anger': 0.0, 'disgust': 0.0,
'fear': 0.0, 'joy': 1.0 and 'sadness': 0.0. The dominant emotion is joy.
```

For blank or invalid input it returns `Invalid text! Please try again!`

### `GET /api/emotion?text=<text>`

Returns the raw scores as JSON (used by the web UI):

```json
{
  "anger": 0.0,
  "disgust": 0.0,
  "fear": 0.0,
  "joy": 1.0,
  "sadness": 0.0,
  "dominant_emotion": "joy"
}
```

For blank input, every value is `null`.

## Running tests

```bash
python -m unittest test_emotion_detection.py
```

## Note

This project uses a local keyword lexicon to score emotions, so it requires no
external API, account, or network access.

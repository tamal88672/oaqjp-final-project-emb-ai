"""Offline, lexicon-based emotion detector.

Analyzes a piece of text for five emotions (anger, disgust, fear, joy,
sadness) using a built-in keyword lexicon, so it runs fully offline without
any external AI service.
"""

import re

EMOTIONS = ("anger", "disgust", "fear", "joy", "sadness")

EMOTION_LEXICON = {
    "anger": [
        "angry", "anger", "mad", "furious", "fury", "hate", "hated", "hateful",
        "annoyed", "annoying", "irritated", "irritating", "rage", "enraged",
        "outraged", "outrage", "resent", "resentful", "hostile", "frustrated",
        "frustrating", "aggravated", "infuriated", "livid", "bitter", "cross",
        "offended", "irate", "fuming", "agitated", "provoked", "vengeful",
    ],
    "disgust": [
        "disgust", "disgusted", "disgusting", "gross", "grossed", "revolting",
        "revolted", "nasty", "sick", "sickening", "sickened", "awful",
        "horrible", "horrid", "repulsive", "repulsed", "repugnant", "vile",
        "foul", "rotten", "yuck", "yucky", "icky", "nauseating", "nauseous",
        "distasteful", "offensive", "loathsome", "creepy", "filthy", "putrid",
        "stinking", "stench", "repelled",
    ],
    "fear": [
        "afraid", "fear", "fearful", "scared", "scary", "terrified", "terror",
        "terrifying", "anxious", "anxiety", "worried", "worry", "nervous",
        "panic", "panicked", "panicking", "frightened", "frightening", "fright",
        "dread", "dreading", "horror", "horrified", "alarmed", "alarming",
        "threatened", "threatening", "petrified", "spooked", "uneasy",
        "apprehensive", "intimidated", "phobia", "shaken",
    ],
    "joy": [
        "happy", "happiness", "glad", "delighted", "delight", "wonderful",
        "love", "loved", "loving", "lovely", "excited", "exciting", "excitement",
        "great", "awesome", "pleased", "pleasing", "pleasure", "cheerful",
        "cheer", "joy", "joyful", "joyous", "elated", "ecstatic", "thrilled",
        "grateful", "thankful", "blissful", "bliss", "content", "contented",
        "satisfied", "fantastic", "amazing", "smile", "smiling", "celebrate",
        "celebrating", "optimistic", "hopeful", "enjoy", "enjoyed", "enjoying",
        "fun", "good", "best", "brilliant",
    ],
    "sadness": [
        "sad", "sadness", "unhappy", "depressed", "depression", "miserable",
        "misery", "crying", "cry", "cried", "grief", "grieving", "lonely",
        "loneliness", "alone", "heartbroken", "heartbreak", "sorrow",
        "sorrowful", "gloomy", "gloom", "despair", "hopeless", "disappointed",
        "disappointing", "disappointment", "mournful", "mourning", "tearful",
        "tears", "weeping", "downcast", "blue", "melancholy", "regret",
        "regretful", "hurt", "hurting", "devastated", "dejected", "forlorn",
    ],
}


def _tokenize(text):
    """Lowercase the text and split it into alphabetic word tokens."""
    return re.findall(r"[a-z]+", text.lower())


def emotion_detector(text_to_analyze):
    """Return per-emotion scores and the dominant emotion for ``text``.

    Blank or whitespace-only input yields all ``None`` values, mirroring the
    status-400 / blank-entry error handling of the original IBM project.
    """
    blank_result = {emotion: None for emotion in EMOTIONS}
    blank_result["dominant_emotion"] = None

    if not text_to_analyze or not text_to_analyze.strip():
        return blank_result

    tokens = _tokenize(text_to_analyze)
    if not tokens:
        return blank_result

    counts = {emotion: 0 for emotion in EMOTIONS}
    for token in tokens:
        for emotion, words in EMOTION_LEXICON.items():
            if token in words:
                counts[emotion] += 1

    total = sum(counts.values())
    if total == 0:
        result = {emotion: 0.0 for emotion in EMOTIONS}
        result["dominant_emotion"] = None
        return result

    result = {emotion: counts[emotion] / total for emotion in EMOTIONS}
    result["dominant_emotion"] = max(EMOTIONS, key=lambda emotion: result[emotion])
    return result

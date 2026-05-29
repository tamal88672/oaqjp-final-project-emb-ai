"""Flask server exposing the offline emotion detector."""

from flask import Flask, render_template, request, jsonify

from EmotionDetection import emotion_detector

app = Flask("Emotion Detection")


@app.route("/")
def index():
    """Render the single-page UI."""
    return render_template("index.html")


@app.route("/emotionDetector")
def emotion_detector_route():
    """IBM-compatible endpoint returning a formatted response string."""
    text_to_analyze = request.args.get("textToAnalyze", "")
    response = emotion_detector(text_to_analyze)

    if response["dominant_emotion"] is None:
        return "Invalid text! Please try again!"

    return (
        "For the given statement, the system response is "
        f"'anger': {response['anger']}, "
        f"'disgust': {response['disgust']}, "
        f"'fear': {response['fear']}, "
        f"'joy': {response['joy']} and "
        f"'sadness': {response['sadness']}. "
        f"The dominant emotion is {response['dominant_emotion']}."
    )


@app.route("/api/emotion")
def emotion_api():
    """Return the raw emotion scores as JSON for the web UI."""
    text_to_analyze = request.args.get("text", "")
    return jsonify(emotion_detector(text_to_analyze))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050)

const EMOTIONS = [
  { key: "anger", label: "Anger", color: "#e53935" },
  { key: "disgust", label: "Disgust", color: "#43a047" },
  { key: "fear", label: "Fear", color: "#8e24aa" },
  { key: "joy", label: "Joy", color: "#f6bf26" },
  { key: "sadness", label: "Sadness", color: "#1e88e5" },
];

const textInput = document.getElementById("textInput");
const analyzeBtn = document.getElementById("analyzeBtn");
const resultsEl = document.getElementById("results");
const messageEl = document.getElementById("message");

async function analyze() {
  const text = textInput.value.trim();
  resultsEl.innerHTML = "";
  messageEl.textContent = "";
  messageEl.className = "message";

  if (!text) {
    showMessage("Invalid text! Please try again!", "error");
    return;
  }

  analyzeBtn.disabled = true;
  analyzeBtn.textContent = "Analyzing...";

  try {
    const response = await fetch(
      "/api/emotion?text=" + encodeURIComponent(text)
    );
    const data = await response.json();
    render(data);
  } catch (err) {
    showMessage("Something went wrong. Please try again.", "error");
  } finally {
    analyzeBtn.disabled = false;
    analyzeBtn.textContent = "Analyze";
  }
}

function render(data) {
  if (!data.dominant_emotion) {
    showMessage("Invalid text! Please try again!", "error");
    return;
  }

  showMessage(
    "Dominant emotion: " + capitalize(data.dominant_emotion),
    "success"
  );

  EMOTIONS.forEach((emotion) => {
    const score = data[emotion.key] || 0;
    const percent = Math.round(score * 100);
    const isDominant = emotion.key === data.dominant_emotion;

    const row = document.createElement("div");
    row.className = "bar-row" + (isDominant ? " dominant" : "");

    const labelRow = document.createElement("div");
    labelRow.className = "bar-label";
    labelRow.innerHTML =
      "<span>" +
      emotion.label +
      (isDominant ? " &#9733;" : "") +
      "</span><span>" +
      percent +
      "%</span>";

    const track = document.createElement("div");
    track.className = "bar-track";

    const fill = document.createElement("div");
    fill.className = "bar-fill";
    fill.style.backgroundColor = emotion.color;
    fill.style.width = "0%";

    track.appendChild(fill);
    row.appendChild(labelRow);
    row.appendChild(track);
    resultsEl.appendChild(row);

    requestAnimationFrame(() => {
      fill.style.width = percent + "%";
    });
  });
}

function showMessage(text, type) {
  messageEl.textContent = text;
  messageEl.className = "message " + type;
}

function capitalize(word) {
  return word.charAt(0).toUpperCase() + word.slice(1);
}

analyzeBtn.addEventListener("click", analyze);
textInput.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    analyze();
  }
});

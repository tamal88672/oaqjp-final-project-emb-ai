"""Unit tests for the offline emotion detector."""

import unittest

from EmotionDetection import emotion_detector


class TestEmotionDetector(unittest.TestCase):
    def test_joy(self):
        result = emotion_detector("I am so happy and delighted, this is wonderful")
        self.assertEqual(result["dominant_emotion"], "joy")

    def test_anger(self):
        result = emotion_detector("I am so angry and furious, I really hate this")
        self.assertEqual(result["dominant_emotion"], "anger")

    def test_fear(self):
        result = emotion_detector("I am scared and terrified, this is so frightening")
        self.assertEqual(result["dominant_emotion"], "fear")

    def test_sadness(self):
        result = emotion_detector("I am so sad and depressed, I feel miserable and lonely")
        self.assertEqual(result["dominant_emotion"], "sadness")

    def test_disgust(self):
        result = emotion_detector("That is disgusting and gross, absolutely revolting and nasty")
        self.assertEqual(result["dominant_emotion"], "disgust")

    def test_blank_input(self):
        result = emotion_detector("")
        self.assertIsNone(result["dominant_emotion"])
        for emotion in ("anger", "disgust", "fear", "joy", "sadness"):
            self.assertIsNone(result[emotion])

    def test_whitespace_input(self):
        result = emotion_detector("    ")
        self.assertIsNone(result["dominant_emotion"])

    def test_scores_normalized(self):
        result = emotion_detector("happy happy angry")
        total = sum(result[e] for e in ("anger", "disgust", "fear", "joy", "sadness"))
        self.assertAlmostEqual(total, 1.0, places=6)


if __name__ == "__main__":
    unittest.main()

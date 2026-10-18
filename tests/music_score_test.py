"""Offline score validation without audio hardware or a MIDI software dependency."""
from pathlib import Path
import array, json, struct, unittest, wave
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/music'
class Scores(unittest.TestCase):
    def test_four_editable_scores_match_rendered_loop_grid(self):
        reports=json.loads((ROOT/'scores.json').read_text())
        self.assertEqual(len(reports),4)
        unique=set()
        for score in reports:
            with self.subTest(theme=score['theme']):
                raw=(ROOT/f"theme_{score['theme']}.mid").read_bytes()
                self.assertEqual(raw[:4],b'MThd')
                self.assertEqual(struct.unpack('>HHH',raw[8:14]),(1,5,480))
                unique.add(raw)
                with wave.open(str(ROOT/f"theme_{score['theme']}.wav")) as f:
                    self.assertEqual(f.getnchannels(),1)
                    self.assertAlmostEqual(f.getnframes()/f.getframerate(),64*60/score['bpm'],places=3)
                    pcm=array.array('h',f.readframes(f.getnframes()))
                    self.assertLess(max(abs(x) for x in pcm),32700)
                    self.assertLess(abs(pcm[0]-pcm[-1]),330)
                    self.assertGreater(score['rms'],.03)
        self.assertEqual(len(unique),4)
if __name__=='__main__':unittest.main()

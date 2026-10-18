import importlib.util, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('calibrate',Path(__file__).resolve().parents[1]/'scripts/calibrate_medals.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class CalibrationTests(unittest.TestCase):
 def setUp(self):
  self.current={'rules_version':'one','challenges':{'stage/car':{'stage_version':'1','vehicle_revision':'fp1'}}}
  self.runs=[dict(source='human_keyboard',practice=False,penalty=0,reset_count=0,elapsed=t,total_time=t,recorded_at=i+1) for i,t in enumerate([100,95,98])]
  self.profile={'version':1,'challenges':{'stage@1|car@fp1|one':{'recent':self.runs}}}
 def test_best_of_three(self):self.assertEqual(module.propose(self.profile,self.current,'two')['challenges']['stage/car']['reference_seconds'],95)
 def test_version_is_required(self):
  with self.assertRaises(ValueError):module.propose(self.profile,self.current,'one')
 def test_auto_and_recoveries_rejected(self):
  self.runs[0]['source']='autopilot_vgamepad'
  with self.assertRaises(ValueError):module.propose(self.profile,self.current,'two')
 def test_same_run_is_not_three_runs(self):
  for run in self.runs:run['recorded_at']=1
  with self.assertRaises(ValueError):module.propose(self.profile,self.current,'two')
 def test_variant_has_own_baseline(self):
  self.current['challenges']={'stage/car/p150':{'stage_version':'1','vehicle_revision':'fp1-p150'}}
  self.profile['challenges']={'stage@1|car@fp1-p150|one':{'recent':self.runs}}
  self.assertEqual(module.propose(self.profile,self.current,'two')['challenges']['stage/car/p150']['reference_seconds'],95)
 def test_standard_runs_cannot_calibrate_boosted_variant(self):
  self.current['challenges']={'stage/car/p150':{'stage_version':'1','vehicle_revision':'fp1-p150'}}
  with self.assertRaises(ValueError):module.propose(self.profile,self.current,'two')
if __name__=='__main__':unittest.main()

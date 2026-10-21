"""Encode a MovieWriter interval, preserving its frame count and 1x clock."""
import argparse, json, subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('native')
parser.add_argument('metadata')
parser.add_argument('output')
args=parser.parse_args()
meta=json.loads(Path(args.metadata).read_text())
first, count, fps=meta['first_frame'],meta['frames'],meta['fps']
subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',args.native,
 '-vf',f'trim=start_frame={first}:end_frame={first+count},setpts=PTS-STARTPTS',
 '-af',f'atrim=start={first/fps}:end={(first+count)/fps},asetpts=PTS-STARTPTS',
 '-c:v','libx264','-preset','slow','-crf','26','-maxrate','8M','-bufsize','16M',
 '-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',args.output],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_type,nb_read_frames,r_frame_rate,width,height:format=duration,size','-of','json',args.output]))
video=next(s for s in probe['streams'] if s['codec_type']=='video')
assert int(video['nb_read_frames'])==count, probe
assert abs(float(probe['format']['duration'])-count/fps)<.05, probe
Path(args.output).with_suffix('.json').write_text(json.dumps({'capture':meta,'media':probe},indent=2)+'\n')
print(json.dumps(probe))

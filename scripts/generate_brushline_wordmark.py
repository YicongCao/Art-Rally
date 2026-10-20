"""Export accurate, scalable Chakra Petch brand lettering (OFL), never raster text."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[1]
font=TTFont(ROOT/'assets/fonts/ChakraPetch-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap()
def lettering(text,x,y,scale,color):
 paths=[];advance=0
 for ch in text:
  name=cmap[ord(ch)];pen=SVGPathPen(glyphs);glyphs[name].draw(pen)
  paths.append(f'<path transform="translate({advance} 0)" d="{pen.getCommands()}"/>');advance+=font['hmtx'][name][0]
 return f'<g fill="{color}" transform="matrix({scale} 0 {-scale*.16} {-scale} {x} {y})">'+''.join(paths)+'</g>'
logo='<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="220" viewBox="0 0 1400 220"><path fill="#ee572b" d="M10 188 43 26 64 26 31 188Z"/>'+lettering('BRUSHLINE',70,164,.145,'#20252b')+lettering('RALLY',900,164,.145,'#ee572b')+'<path stroke="#ee572b" stroke-width="5" d="M66 195 1320 195"/></svg>'
(ROOT/'assets/brushline/wordmark.svg').write_text(logo)
icon='<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect x="16" y="16" width="480" height="480" rx="92" fill="#20252b"/><path fill="#ee572b" d="M80 405 155 98 202 98 127 405Z"/>'+lettering('B',147,393,.40,'#eee2c5')+'<path d="M155 427 416 427" stroke="#ee572b" stroke-width="16"/></svg>'
(ROOT/'assets/brushline/icon.svg').write_text(icon)

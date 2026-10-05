"""Measured geometry reference, not production raster art."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

root = Path(__file__).resolve().parent
out = root / 'bridge_draft'
out.mkdir(exist_ok=True)
image = Image.new('RGBA', (672, 624), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rectangle((48, 48, 623, 575), fill='#929080')
for x in (48, 576):
    draw.rectangle((x, 96, x + 47, 527), fill='#304b4d')
for x in range(48, 625, 48):
    draw.line((x,48,x,575), fill='#676e67')
for y in range(48, 577, 48):
    draw.line((48,y,623,y), fill='#676e67')
image.save(out / 'geometry_reference.png')
spec = {
 'building_id':'leyton_cargo_bridge', 'display_name':'莱顿城货运石桥',
 'kind':'structure','projection_id':'orthogonal_3q_48_v1','anchor_mode':'bottom_center',
 'visual':{'tile_size':48,'padding_tiles':1,'source_origin_tile':[1,1],
   'clip_to_logic':False,'layers':[
    {'name':'Base','role':'base','source':'res://assets/buildings/leyton_cargo_bridge/visual/source_graybox.png','output':'base.png','z_index':0,'visible':True}]},
 'collision':{'layer':2,'mask':1},
 'sorting':{'mode':'y_sort','y_sort_origin':'bottom_center','z_index':0,'occluder':False,'roof_layer_z':12},
 'tactical':{'cover':0,'cover_level':'low','height_level':0,'blocks_los':False,'enterable':False},
 'plan':{'scale':{'px_per_meter':48,'tile_px':48},'origin_m':[0,0],'footprint_m':[12,11],
  'rooms':[{'id':'deck','label':'露天桥面','x_m':0,'y_m':0,'w_m':12,'h_m':11,'solid':False,'roof':None}],
  'openings':[{'x_m':x,'y_m':y,'w_m':1,'h_m':1} for x in (0,11) for y in (0,10)],
  'doors':[{'id':'north','x_m':1,'y_m':0,'w_m':10,'side':'n','interact':'','target':'outside'},
           {'id':'south','x_m':1,'y_m':10,'w_m':10,'side':'s','interact':'','target':'outside'}]}}
(out / 'building.spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

import os,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'.tools/pylibs'))
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
text=''.join(p.read_text(encoding='utf8') for p in (ROOT/'scripts').glob('*.gd'))
text+=''.join(chr(i) for i in range(32,127))+'←→‹›Ⅱ✓秒第名未设置好友排行榜加载中云端飞奔薄荷天际线一二三四五六七八九十'
font=TTFont(ROOT/'.tools/NotoSansSC.ttf')
options=subset.Options();options.layout_features=['*'];options.name_IDs=['*']
subsetter=subset.Subsetter(options=options);subsetter.populate(text=text);subsetter.subset(font)
instantiateVariableFont(font, {'wght': 600}, inplace=False).save(ROOT/'assets/fonts/skyline.ttf')
instantiateVariableFont(font, {'wght': 850}, inplace=False).save(ROOT/'assets/fonts/skyline_bold.ttf')
print('FONT_OK',os.path.getsize(ROOT/'assets/fonts/skyline.ttf'))

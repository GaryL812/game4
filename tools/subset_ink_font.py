import sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'.tools/pylibs'))
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
text=''.join(p.read_text(encoding='utf8') for p in (ROOT/'scripts').glob('*.gd'))
text+=''.join(chr(i) for i in range(32,127))+'墨行山海云端飞奔云栈烟岚踏云通关一二三四五六七八九十←→‹›Ⅱ✓'
font=TTFont(ROOT/'.tools/NotoSerifSC.ttf')
options=subset.Options();options.layout_features=['*'];options.name_IDs=['*']
worker=subset.Subsetter(options=options);worker.populate(text=text);worker.subset(font)
for weight,name in [(500,'ink'),(800,'ink_bold')]:
    instantiateVariableFont(font,{'wght':weight},inplace=False).save(ROOT/f'assets/fonts/{name}.ttf')
print('INK_FONT_OK')

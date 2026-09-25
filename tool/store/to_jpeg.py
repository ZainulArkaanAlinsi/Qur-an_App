"""Ubah hasil generator (build/play-store-raw) menjadi JPEG untuk Play Console.

Play menerima JPEG atau PNG 24-bit tanpa alfa; JPEG q92 jauh lebih kecil.
Jalankan dari akar proyek: python tool/store/to_jpeg.py
"""
import glob
import os

from PIL import Image

for src in sorted(glob.glob('build/play-store-raw/*/*.png')):
    lang = os.path.basename(os.path.dirname(src))
    name = os.path.splitext(os.path.basename(src))[0]
    dst = os.path.join('docs', 'play-store', lang, name + '.jpg')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    image = Image.open(src).convert('RGB')
    image.save(dst, 'JPEG', quality=92, optimize=True, progressive=True)
    print(dst, image.size, os.path.getsize(dst) // 1024, 'KB')

#!/bin/sh
# Сделать из sicp.xml sicp.tex, а потом sicp.dvi
# !! Следующие две строки можно закомментарить!
#openjade -c /usr/share/sgml/openjade-1.3.1/dsssl/catalog -d sicp-tex.dsl -t sgml sicp.xml
#./drop-garbage *.tex

# Сделать заглушку-индекс
echo > ru-idx.tex

# Прогнать TeX два раза, чтобы все перекрестные ссылки встали на место.
pdflatex sicp
pdflatex sicp

# Породить индекс
cat ru.idx additems.idx | ./idxproc.tcl > ru-idx.tex

# Окончательный прогон TeX, уже вместе с индексом.
pdflatex sicp

#!/bin/sh

VERS="0.0.1"
DATE="2009-08-05"

# Leave the desired layout uncommented.
LAYOUT=layout          # Tables based layout.

ASCIIDOC_HTML="asciidoc --unsafe --backend=xhtml11 --attribute icons --attribute iconsdir=./images/icons --attribute=badges --attribute=revision=$VERS  --attribute=date=$DATE"

$ASCIIDOC_HTML --conf-file=${LAYOUT}.conf --attribute iconsdir=./icons index.txt
$ASCIIDOC_HTML --conf-file=${LAYOUT}.conf --attribute iconsdir=./icons downloads.txt
$ASCIIDOC_HTML --conf-file=${LAYOUT}.conf --attribute iconsdir=./icons installation.txt

cd tutorial
$ASCIIDOC_HTML --conf-file=../${LAYOUT}.conf --attribute iconsdir=../icons -a toc --attribute=styledir=.. index.txt
cd ..

cd manual
# $ASCIIDOC_HTML --conf-file=../${LAYOUT}.conf --attribute iconsdir=../icons -a toc --attribute=styledir=.. index.txt
$ASCIIDOC_HTML --conf-file=../${LAYOUT}.conf  -a iconsdir=../icons -a toc -a latexmath -a styledir=.. index.txt
cd ..

#!/bin/sh

VERS="0.0.1"
DATE="2009-08-05"

# Leave the desired layout uncommented.
LAYOUT=layout          # Tables based layout.

ASCIIDOC_HTML="asciidoc --unsafe --backend=xhtml11 --attribute icons --attribute iconsdir=./images/icons --attribute=badges --attribute=revision=$VERS  --attribute=date=$DATE"

$ASCIIDOC_HTML -f ${LAYOUT}.conf -a iconsdir=./icons index.txt
$ASCIIDOC_HTML -f ${LAYOUT}.conf -a iconsdir=./icons downloads.txt
$ASCIIDOC_HTML -f ${LAYOUT}.conf -a iconsdir=./icons lis_tinyos.txt
$ASCIIDOC_HTML -f ${LAYOUT}.conf -a iconsdir=./icons installation.txt
$ASCIIDOC_HTML -f ${LAYOUT}.conf -a iconsdir=./icons todo.txt

cd publications
$ASCIIDOC_HTML -f ../${LAYOUT}.conf --a iconsdir=../icons -a styledir=.. index.txt
cd ..

cd tutorial
$ASCIIDOC_HTML -f ../${LAYOUT}.conf --a iconsdir=../icons -a styledir=.. index.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf --a iconsdir=../icons -a styledir=.. collatz.txt
cd ..

cd manual
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. index.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. -a latexmath language.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. scoping.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. instrumentation.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. bitlog.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. send_log.txt
$ASCIIDOC_HTML -f ../${LAYOUT}.conf  -a iconsdir=../icons -a styledir=.. parsing.txt
cd ..

# Set up files used by documentation
cp ../install/install.sh code/
cp ../demo/default.lis code/
cp ../demo/demo.c code/
cp ../demo/demo.orig.c code/
cp ../demo/send_log.c code/
git archive --format=tar --prefix=lis-core/ HEAD | gzip > code/lis-core.tgz

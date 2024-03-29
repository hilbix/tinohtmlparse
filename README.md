This Works is placed under the terms of the Copyright Less License,
see file COPYRIGHT.CLL.  USE AT OWN RISK, ABSOLUTELY NO WARRANTY.

However as it ekhtml is linked in statically, binaries must
be compliant to the EKTHML license.

Origin: http://www.scylla-charybdis.com/tool.php/tinohtmlparse
Newest: https://github.com/hilbix/tinohtmlparse


> Note that on Debian you need (and probably others):
>
> sudo apt install build-essential autoconf libtoolize gawk


Compile:
========

This is currently based on ekhtml, a deadly inperfect HTML parser (for
example it does not parse Comments correctly, like in the following:
<!DTD -- comment 1 -- more DTD -- comment 2 -- again DTD />).  Perhaps
sometimes I come around and write a working version (which then shall
be able to sanitize HTML as well), but for now, we keep it as it is.

For easy checkout, I created a cvsimport of ekhtml on GitHub.
Transition to GitHub still is incomplete, but it works as follows:

To compile tinohtmlparse:
	make

This now automatically compiles ekhtml.  To do this manually:

	git submodule update --init
	cd ekhtml; ./autogen.sh; make
	cd ..

Note that tinolib (subdir tino/) is not strictly necessary to compile
tinohtmlparse.


Usage:
======

Usage:
	tinohtmlparse [-r|--raw] [-l|--list] [-o|--old]

--list shows a list of known entities

--raw does not convert these entities to their % representation in
attributes.

--old uses the old output variant.  The new variant separates the
last argument from the previous one with a TAB instead of SPC.

The HTML file is read from stdin and the output is written to stdout.
The parsed lines all look like following template:

TYPE TAG ATTR Q TEXT

The words are separated by SPC or TAB.  The first 4 words are
guaranteed to not contain SPC or TAB ever.  If they are empty it is
guaranteed that no more words or text follows.

- TYPE is a type string (see below)
- TAG usually is the HTML TAG (ekhtml converts this to uppercase)
- ATTR is the attribute name
- Q is a Quote type of the text which follows.
- TEXT is the text and is % escaped such that it is URL compatible

When TYPE is "text" or "comment" then TAG is a number counting the
lines starting with 0, ATTR is an LF flag and Q always is -.

Q can be B for boolean attribs (those without =), N (was not quoted),
' or " (the quote which was used).  There is a form where Quote is two
HEX digits HH, but this never shall show up (it's in case ekhtml send
some unusual quote character).

So you can do

./tinohtmlparse < htmlfile |
./tinohtmlabsurl.sh "BASEURL" |
while read -r type tag name q text
do
	...
done


Output documentation:
=====================

open TAG
close TAG
	Open and closing TAG tags encountered.  TEXT is empty.

attr TAG ATTR Q TEXT
	A named attribute, immediately follows "open".

	TAG is the TAG it belongs to, added for more easy parsing.
	ATTR is the attribute's name.

	The text is URL-escaped with %, that is %xx is the hex
	representation of any unusual character (including SPC).
	For unicode characters there is the representation %uXXXX.

	If HTMLentities (like &amp;) are encountered, they are
	automatically changed into the character representation.
	(if not --raw given.)

text COUNT LF - TEXT
comment COUNT LF - TEXT
	COUNT is the line count.

	LF is either 0 (TEXT does not contain a LF) or 1 (TEXT does
	contain an LF).  Multiple lines are repeated with the line
	count counted up, so there are no complex to parse
	continuation lines.

	In case of the comment form, this is the commented out text.


Notes:
======

People out there partly write deadly HTML code.  tinohtmlparse is
too perfect to handle this - all heuristics are missing.

For example what I already have seen (yes, this are TWO lines):

<img src=" pic
.jpg">

Firefox handles this correctly and loads pic.jpg!  So it silently
trims SPCs from URLs and removes CRs and LFs from within, too.
tinohtmlparse does not do this.  It transforms the URL into
%20pic%0a.jpg, which then probably is not found on the server.

If you need to parse such crap, apply your own heuristics.
tinohtmlparse will never do this for you.

Please also note that before 0.1.4 the SPC was not escaped to
%20, it was output unchanged.  This is fixed now.


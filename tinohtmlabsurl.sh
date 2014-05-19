#!/bin/sh
#
# $Header$
#
# THIS IS NOT PERFECT,
# it does not process a lot of URI attributes for now,
# like applet_codebase, applet_code etc.
#
# This Works is placed under the terms of the Copyright Less License,
# see file COPYRIGHT.CLL.  USE AT OWN RISK, ABSOLUTELY NO WARRANTY.
#
# $Log$
# Revision 1.7  2009-08-03 12:41:26  tino
# Lowercase
#
# Revision 1.6  2009-07-12 22:19:44  tino
# Url-Parser fixed in tinohtmlabsurl.sh
#
# Revision 1.5  2007-12-30 17:57:03  tino
# Placed under the CLL, also one entity code was fixed (&and;)
#
# Revision 1.4  2007-02-12 07:00:02  tino
# Commit for dist, see ChangeLog
#
# Revision 1.3  2006/06/16 20:35:41  tino
# Jump now name anchor, which can be understood better.
# Capability to send all non-URL-lines elsewhere, if you concentrate on URLs
#
# Revision 1.2  2005/02/06 00:17:06  tino
# Only full lines are fed to the parser to make output more easy to parse.
#
# Revision 1.1  2005/02/05 23:07:28  tino
# first commit, tinohtmlparse.c is missing "text" aggregation

if [ 1 != "$#" -a 2 != "$#" ]
then
	echo "Usage: tinohtmlparse | `basename "$0"` BASEURL [/dev/stdout]
	Second argument gives file for non-URL lines" >&2
	exit 1
fi

awk -v BASE="$1" -v NOURLOUT="${2:-/dev/stdout}" '
function shift(x)
{
  sub(/^[^[:space:]]*[[:space:]]/,"",x);
  return x;
}

# http://user:pass@hostname/path/to/index.html?var=data#text
# -type-!!-user---!!-host-!!-path--!!-file---!!-query-!!-anchor-
#
# relative URLs: path does not start with /
# Special characters:
# # starts the anchor anywhere in the URL
# ? starts the query part anywhere in the URL
# @ must preceede host, which must precede /
#
# It does not assume directory structure:
# .. becomes path "" name ".."
# ../.. becomes path "../" name ".."
function parseuri(u, b, c)
{
  delete parsed

  # fetch #anchor
  b	= u;
  gsub(/^[^#]*/, "", b);
  gsub(/#.*$/,"",u);
  parsed["anchor"]=b

  # Fetch ?query
  b	= u;
  gsub(/^[^?]*/, "", b);
  gsub(/\?.*$/,"",u);
  parsed["query"]=b

  # Fetch schema://
  b	= "";
  if (match(u,/^[a-z]*:\/?\/?/))
    {
      b	= substr(u,RSTART,RLENGTH);
      u	= substr(u,RSTART+RLENGTH);
    }
  parsed["type"]=b

  # Fetch host if there is a schema
  c	= ""
  if (b!="")
    {
      b	= u
      gsub(/\/.*$/,"",b);
      gsub(/^[^/]*/,"",u);
      # check user:password@
      if (match(b,/@/))
        {
          c	= substr(b,1,RSTART);
          b	= substr(b,RSTART+1);
        }
    }
  parsed["user"]=c;
  parsed["host"]=b;

  # Now left is path/file
  b	= u
  gsub(/^.*\//,"",b);
  parsed["file"]=b;

  gsub(/[^/]*$/,"",u);
  parsed["path"]=u
}

function dump(t,a,s)
{
  s	= sprintf("# %s", t);

  a="type";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="user";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="host";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="path";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="file";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="query"; s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="anchor";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);

  print s >NOURLOUT
}

function setbase(b)
{
  parseuri(b)

  # Make sure, BASE path starts and ends with /
  # (the latter is the same as base["path"]=="")
  if (parsed["path"]!~/^\// || parsed["path"]!~/\/$/)
    parsed["path"]="/";

  dump("base");

  basetype	= parsed["type"]
  basehost	= parsed["host"]
  basepath	= parsed["path"]
  basefile	= parsed["file"]
  basequery	= parsed["query"]
}

# Make a full URI from a relative one
# The idea is
function makefull(u,p)
{
  parseuri(u)

  dump("1");

  # Bugfix:
  # We have two options here:
  # base: http://example.com/dir/file?query#anchor
  # uri=: ?query
  # Does the result have a file?
  # Browsers think 'yes'
  # This now shall parse #anchor type destinations, too.
  if (parsed["type"]=="" && parsed["host"]=="" && parsed["path"]=="" && parsed["file"]=="" && parsed["query"]=="")
    parsed["query"]=basequery;
  if (parsed["type"]=="" && parsed["host"]=="" && parsed["path"]=="" && parsed["file"]=="")
    parsed["file"]=basefile;

  # This apparently only works when there was no host
  if (parsed["host"]=="" && parsed["path"]!~/^\//)
    parsed["path"] = basepath parsed["path"]

  # Take over type, host and path from BASE URI
  if (parsed["type"]=="")
    parsed["type"]=basetype;
  # Well, what to do when switching from http: to https:?
  # news:whatever has no host!
  if (parsed["host"]=="" && parsed["type"]==basetype)
    parsed["host"]=basehost;

  if (parsed["path"]=="")
    parsed["path"]="/";

  dump("2");

  return tolower(parsed["type"]) parsed["user"] tolower(parsed["host"]) parsed["path"] parsed["file"] parsed["query"] parsed["anchor"];
}

BEGIN	{
	tag["base","href"]=1

	# I am conservative
	# Do not touch background,href,src I do not understand.
	tag["a","href"]=2
	tag["area","href"]=2
	tag["bgsound","src"]=2
	tag["body","background"]=2
	tag["embed","src"]=2
	tag["form","action"]=2
	tag["frame","src"]=2
	tag["iframe","src"]=2
	tag["input","src"]=2
	tag["img","src"]=2
	tag["layer","background"]=2
	tag["layer","src"]=2
	tag["link","href"]=2
	tag["script","src"]=2
	tag["table","background"]=2
	tag["td","background"]=2
	tag["th","background"]=2
	setbase(BASE)
	IGNORECASE=1
	}

$1=="attr" && (t=tag[tolower($2),tolower($3)])!=0	{
	uri=shift(shift(shift(shift($0))))
	if (t==1)
		setbase(uri)
	else
		{
		n=makefull(uri)
		if (uri!=n)
		  {
		    print "# " $0 > NOURLOUT
		    print $1 " " $2 " " $3 " " $4 " " n
		    next
		  }
		print
		next
		}
	}

	{ print >NOURLOUT  }
'

#!/bin/sh
#
# $Header$
#
# Copyright (C)2005 by Valentin Hilbig
# Public Domain as long as Copyright is retained.
# Use at own risk, no warranty!
#
# THIS IS NOT PERFECT,
# it does not process a lot of URI attributes for now,
# like applet_codebase, applet_code etc.
#
# $Log$
# Revision 1.1  2005-02-05 23:07:28  tino
# first commit, tinohtmlparse.c is missing "text" aggregation
#

if [ 1 != "$#" ]
then
	echo "Usage: tinohtmlparse | `basename "$0"` BASEURL" >&2
	exit 1
fi

awk -v BASE="$1" '
function shift(x)
{
  sub(/^[^[:space:]]*[[:space:]]/,"",x);
  return x;
}

# http://user:pass@hostname/path/to/index.html?var=data#text
# -type-!!-user---!!-host-!!-path--!!-file---!!-query-!!-jump-
#
# relative URLs: path does not start with /
# Special characters:
# # starts the jump anywhere in the URL
# ? starts the query part anywhere in the URL
# @ must preceede host, which must precede /
#
# It does not assume directory structure:
# .. becomes path "" name ".."
# ../.. becomes path "../" name ".."
function parseuri(u, b, c)
{
  delete parsed

  # fetch #jump
  b	= u;
  gsub(/^[^#]*/, "", b);
  gsub(/#.*$/,"",u);
  parsed["jump"]=b

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
  a="jump";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);

  print s
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
}

# Make a full URI from a relative one
# The idea is
function makefull(u,p)
{
  parseuri(u)

  dump("1");

  # Take over type, host and path from BASE URI
  if (parsed["type"]=="")
    parsed["type"]=basetype;
  if (parsed["host"]=="")
    parsed["host"]=basehost;
  if (parsed["path"]!~/^\//)
    parsed["path"] = basepath parsed["path"]

  dump("2");

  return parsed["type"] parsed["user"] parsed["host"] parsed["path"] parsed["file"] parsed["query"] parsed["jump"];
}

BEGIN	{
	tag["base","href"]=1

	# I am conservative
	# Don't touch background,href,src I don't understand.
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
		    print "# " $0
		    print $1 " " $2 " " $3 " " $4 " " n
		    next
		  }
		}
	}

	{ print }
'

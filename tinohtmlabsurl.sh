#!/bin/sh
#
# THIS IS NOT PERFECT,
# it does not process a lot of URI attributes for now,
# like applet_codebase, applet_code etc.
#
# This Works is placed under the terms of the Copyright Less License,
# see file COPYRIGHT.CLL.  USE AT OWN RISK, ABSOLUTELY NO WARRANTY.

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

# type\/auth-------------------\/path-------------\/query--\/anchor
# http://user:pass@hostname:port/path/to/index.html?var=data#text
# type/  \user----/\host-------/\dir----/\file----/\query--/\anchor
#
# relative urls:
# - have no type (schema), see RFC3986 5.2
# - do not start with auth (
# Special characters:
# # always starts the anchor, see RFC3986 3.4
# ? always starts the query, see RFC3986 3.5
function parseuri(u, b, c)
{
  delete parsed

  # fetch #anchor (RFC3986 3.5)
  b	= u;
  gsub(/^[^#]*/, "", b);
  gsub(/#.*$/,"",u);
  parsed["anchor"]=b

  # Fetch ?query (RFC3986 3.4)
  b	= u;
  gsub(/^[^?]*/, "", b);
  gsub(/\?.*$/,"",u);
  parsed["query"]=b

  b	= "";
  # Fetch schema: (RFC3986 3.1)
  if (match(u,/^[a-zA-Z][a-zA-Z0-9+.-]*:/))
    {
      b	= tolower(substr(u,RSTART,RLENGTH));
      u	= substr(u,RSTART+RLENGTH);
    }
  parsed["type"] = b;

  b	= ""
  # Fetch host if there is //authority (RFC3986 3.2)
  if (match(u,/^\/\/[^/]*/))
    {
      b	= substr(u,RSTART,RLENGTH);
      u	= substr(u,RSTART+RLENGTH);
      c	= "";
      if (match(b,/@/))
	{
          c	= substr(b,1,RSTART);
          b	= substr(b,RSTART+1);
        }
      b	= c tolower(b);
    }
  parsed["auth"] = b;
  parsed["path"] = u;

  # Split path into dir/file
  # Absolute path:
  # - dir is absolute dirpart (starts and ends in "/")
  # - file is last file part (like "..")
  # Relative path:
  # - dir is empty ("")
  # - file is the relative part
  # Empty path is taken as relative path
  b	= ""
  if (u ~ /^\//)
    {
      b	= u;
      gsub(/[^\/]*$/,"",b);
      gsub(/^.*\//,"",u);
    }
  parsed["dir"] =b;
  parsed["file"]=u;
}

function dump(t,a,s)
{
  s	= sprintf("# %s", t);

  a="type";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="auth";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="dir";   s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="file";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="query"; s=s sprintf(" %s=\"%s\"", a, parsed[a]);
  a="anchor";  s=s sprintf(" %s=\"%s\"", a, parsed[a]);

  print s >NOURLOUT
}

function setbase(b)
{
  parseuri(b)

  # special case, missing base directory is taken as root directory
  if (parsed["dir"]=="")
    parsed["dir"]="/";
  dump("base");

  basetype	= parsed["type"]
  baseauth	= parsed["auth"]
  basedir	= parsed["dir"]
  basefile	= parsed["file"]
  basequery	= parsed["query"]
  # no need for base fragment, RFC3986 5.2.2
}

# Make a full URI from a relative one
# See RFC3986 5.2
function makefull(u,p)
{
  parseuri(u)

  dump("1");

  if (!parsed["type"] || parsed["type"]==basetype)
    {
      parsed["type"] = basetype;
      if (!parsed["auth"])
	{
          parsed["auth"] = baseauth;
          if (!parsed["dir"])
	    {
              parsed["dir"]	= basedir;
	      if (!parsed["file"])
		{
                  parsed["file"]	= basefile;
	          if (!parsed["query"])
		    parsed["query"]	= basequery;
		}
	    }
	}
    }

  dump("2");

  p = parsed["dir"] parsed["file"];
  gsub(/\/\//,"/", p);
  gsub(/\/\.\//,"/", p);
  sub(/\/\.$/,"/", p);
  while (u != p)
    {
      u = p;
      sub(/\/[^\/]*\/\.\.\//,"",p);
      if (u!=p) continue;
      sub(/\/[^\/]*\/\.\.$/,"",p);
      gsub(/^\/\.\.\//,"/", p);
      gsub(/^\/\.\.$/,"/", p);
    }
  return parsed["type"] parsed["auth"] p parsed["query"] parsed["anchor"];
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
		setbase(makefull(uri))
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

/* $Header$
 *
 * Not copyrighted.  Public Domain.
 *
 * Based dirctly on tester.c from ekhtml code.
 *
 * $Log$
 * Revision 1.2  2005-02-06 00:17:06  tino
 * Only full lines are fed to the parser to make output more easy to parse.
 *
 * Revision 1.1  2005/02/05 23:07:28  tino
 * first commit, tinohtmlparse.c is missing "text" aggregation
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>

#include "ekhtml/include/ekhtml.h"

#include "tinohtmlparse_version.h"
 
static void
spc(void)
{ 
  putchar(' ');
}

static void
lf(void)
{ 
  putchar('\n');
}

static void
co(char c)
{
  putchar(c);
  if (c=='\n')
    putchar('+');
}

static void
cp(char c)
{
   putchar(isprint(c) && !isspace(c) ? c : '_');
}

/**********************************************************************/

static void
p_b(const char *s, ...)
{
  va_list list;

  va_start(list, s);
  vprintf(s, list);
  va_end(list);
  spc();
}

static void
p_p(ekhtml_string_t *s)
{
  int	i;

  for (i=0; i<s->len; i++)
    cp(s->str[i]);
}

static void
p_s(ekhtml_string_t *s)
{
  p_p(s);
  spc();
}

static void
p_e(void)
{
  lf();
}

static void
p_t(ekhtml_string_t *s)
{
  int	i, m;

  m	= s->len;
  if (m && s->str[m-1]=='\n')
    m--;
  for (i=0; i<m; i++)
    co(s->str[i]);
}

/* Prefixed Message
 */
static void
p_m(const char *prefix, ekhtml_string_t *s)
{
  int	i;
  int	l;

  for (l=0, i=0; i<s->len; l++)
    {
      int	j;

      printf("%s %d ", prefix, l);
      for (j=i;;j++)
	if (j>=s->len)
	  {
	    printf("0 ");
	    break;
	  }
	else if (s->str[j]=='\n')
	  {
	    printf("1 ");
	    break;
	  }
      printf("- ");
      while (i<j)
        co(s->str[i++]);
      lf();
      i++;
    }
}

/**********************************************************************/

static void
cb_start(void *x, ekhtml_string_t *tag, ekhtml_attr_t *att)
{
  ekhtml_attr_t *attr;

  p_b("open");
  p_p(tag);
  p_e();

  for (attr=att; attr; attr=attr->next)
    {
      p_b("attr");
      p_s(tag);
      p_s(&attr->name);
      if (attr->isBoolean)
        {
	  p_b("B");
	}
      else if (attr->quoteChar)
	{
	  switch (attr->quoteChar)
	    {
	    case '"':
	    case '\'':
	      p_b("%c", attr->quoteChar);
	      break;

	    default:
	      p_b("%02x", (unsigned)(unsigned char)attr->quoteChar);
	      break;
	    }
	}
      else
	{
	  p_b("N");
	}
      p_t(&attr->val);
      p_e();
    }
}

static void
cb_end(void *x, ekhtml_string_t *tag)
{
  p_b("close");
  p_p(tag);
  p_e();
}

static void
cb_comment(void *x, ekhtml_string_t *comment)
{
  p_m("comment", comment);
}

/* ekHTML does not call this with full lines.  Instead it calls this
 * with just the data it has so far.  This is correct, but in our case
 * I don't want to have partial lines in normal situations.
 * This is now "fixed" by feeding full lines into the parser.
 */
static void
cb_data(void *x, ekhtml_string_t *data)
{
  p_m("text", data);
}

/**********************************************************************/

int
main(void)
{
  ekhtml_parser_t	*p;
  ekhtml_string_t	s;
  char			buf[BUFSIZ*10];
  int			fill;

  p = ekhtml_parser_new(NULL);
    
  ekhtml_parser_datacb_set(p, cb_data);
  ekhtml_parser_commentcb_set(p, cb_comment);
  ekhtml_parser_startcb_add(p, NULL, cb_start);
  ekhtml_parser_endcb_add(p, NULL, cb_end);

  fill	= 0;
  for (;;)
    {
      int	n, i, k;

      if (fflush(stdout) || ferror(stdin) || feof(stdout) || ferror(stdout))
        return 1;

      n		= fread(buf+fill, 1, sizeof buf-fill, stdin);
      fill	+= n;

      /* Ugly fix:
       * Only feed full lines to ekhtml,
       * such that cb_data only gets full lines.
       */
      k		= fill;
      if (n)
	for (i=fill; --i>=0; )
	  if (buf[i]=='\n')
	    {
	      k	= i+1;
	      break;
	    }

      s.str	= buf;
      s.len	= k;
      ekhtml_parser_feed(p, &s);
      if (n==0)
	break;

      fill	-= k;
      if (fill)
	memmove(buf, buf+k, fill);

#if 1
      ekhtml_parser_flush(p, 0);
#endif
    }
  ekhtml_parser_flush(p, 1);
  ekhtml_parser_destroy(p);
  return 0;
}

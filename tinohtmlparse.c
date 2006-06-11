/* $Header$
 *
 * Not copyrighted.  Public Domain.
 * NOTE THAT EKHTML IS NOT PD!
 *
 * Based dirctly on tester.c from ekhtml code.
 *
 * $Log$
 * Revision 1.4  2006-06-11 06:57:30  tino
 * Mainly only documentation corrected
 *
 * Revision 1.3  2006/02/12 03:35:41  tino
 * new dist for version with html entitiy parsing
 *
 * Revision 1.2  2005/02/06 00:17:06  tino
 * Only full lines are fed to the parser to make output more easy to parse.
 *
 * Revision 1.1  2005/02/05 23:07:28  tino
 * first commit, tinohtmlparse.c is missing "text" aggregation
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>

#include "ekhtml/include/ekhtml.h"

#include "tinohtmlparse_version.h"

#include "tino_html_entities.h"

static int	raw_mode;
 
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

static void
cx(int c)
{
  co("0123456789abcdef"[((unsigned)c)&0xf]);
}

static void
ce(int c)
{
  if (c<32 || c>126 || c=='%')
    {
      co('%');
      cx(c>>4);
      cx(c);
    }
  else
    co(c);
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

/* Print string,
 * but parse html_entities
 *
 * Well, I assume that it's a link.
 * So UTF8 will be transformed into % notation.
 */
static void
p_ent(ekhtml_string_t *s)
{
  int	i, m;

  m	= s->len;
  for (i=0; i<m; )
    {
      if (!raw_mode && s->str[i]=='&')
	{
	  int	len;
	  int	u;

	  len	= m-i;
	  u	= tino_html_entity_check(s->str+i, &len);
	  if (u>=0)
	    {
	      if (u>0xff)
		{
		  co('%');
		  co('u');
		  cx(u>>12);
		  cx(u>>8);
		  cx(u>>4);
		  cx(u);
		}
	      else
		ce(u);
	      i	+= len;
	      continue;
	    }
	}
      ce(s->str[i++]);
    }
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
      p_ent(&attr->val);
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
main(int argc, char **argv)
{
  ekhtml_parser_t	*p;
  ekhtml_string_t	s;
  char			buf[BUFSIZ*10];
  int			fill;
  int			i;

  raw_mode	= 0;
  for (i=1; i<argc; i++)
    {
      if (!strcmp(argv[1], "-r") || !strcmp(argv[1], "--raw"))
	{
	  raw_mode	= !raw_mode;
	  continue;
	}
      if (!strcmp(argv[1], "-l") || !strcmp(argv[1], "--list"))
	{
	  struct tino_html_entities	*p;

	  for (p=tino_html_entities; p->unicode; p++)
	    printf("%04x\t%5d\t%s\n", p->unicode, p->unicode, p->entity);
	  return 0;
	}
      fprintf(stderr,
	      "Usage: %s [options] < HTMLFILE > parsed_output\n"
	      "\t\tVersion " TINOHTMLPARSE_VERSION " compiled " __DATE__ "\n"
	      "\t--raw\t(also -r) Do not interpret htmlentities\n"
	      "\t\tIf you depend on the broken values, give --raw\n"
	      "\t\tElse tinohtmlparse tries to parse things for HTML entities\n"
	      "\t\tand transfor something clever, which probably is unwanted\n"
	      "\t--list\t(also -l) List known htmlentities (without & and ;)\n"
	      "\t\tNote that &#n; and &#xX; also is known but not listed.\n"
	      , argv[0]
	      );
      return 1;
    }
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

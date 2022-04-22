/* dumphelp
 *   function: help ファイルをバッファへ読み込んだ状態に構成する
 *   usage: ./dumphelp < text > source
 */

#include <stdio.h>
#include <string.h>

#define DC_B "\t\t.dc.b\t"
#define MAXLEN 96

#define QUOTE_START() \
  ({                  \
    if (!in_quote) {  \
      putchar('\'');  \
      in_quote = 1;   \
    }                 \
  })
#define QUOTE_END() \
  ({                \
    if (in_quote) { \
      printf("',"); \
      in_quote = 0; \
    }               \
  })

int main(int argc, char* argv[]) {
  char buf[MAXLEN + 1];

  if (argc != 1)
    return 1;

  while (fgets(buf, sizeof buf, stdin) && buf[0]) {
    if (buf[0] == (char)'.') {
      printf("%s", buf);
    }

    else {
      int len = strlen(buf);
      unsigned char* p;
      int in_quote;

      buf[len - 1] = '\0';

      printf(DC_B "%2d,", len);
      for (in_quote = 0, p = buf; *p; p++) {
        if (*p == (char)'\'') {
          QUOTE_END();
          printf("%d,", *p);
        } else {
          QUOTE_START();
          putchar(*p);
        }
      }
      QUOTE_END();
      printf("CR,%d\n", len);
    }
  } /* end while */

  return 0;
}

/* EOF */

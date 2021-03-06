D               [0-9]
L               [a-zA-Z]
H               [a-fA-F0-9]

%option noyywrap
%x START
%s NORMAL
%{
#include <stdio.h>
#include <string.h>
#include "comp.tab.h"

long hexToDec(char *);
int getReg(char);

int level = 0;
%}
%option yylineno
%%

<INITIAL>.*|\n              {
                                yyless(0);
                                level = 0;
                                BEGIN(START);
                            }
<START>(\t)*                {
                                if (yyleng > level) {
                                    level++;
                                    yyless(0);
                                    return INDENT;
                                } else if (yyleng < level) {
                                    level--;
                                    yyless(0);
                                    return DEDENT;
                                } else {
                                    BEGIN(NORMAL);
                                }
                            }
<START>.                    {
                                yyless(0);
                                if (level > 0) {
                                    level--;
                                    return DEDENT;
                                } else {
                                    BEGIN(NORMAL);
                                }
                            }
<START><<EOF>>              {
                                // yyless(0);
                                if (level > 0) {
                                    level--;
                                    // yyless(0);
                                    return DEDENT;
                                } else {
                                    BEGIN(NORMAL);
                                    // return ENDFILE;
                                }
                            }

"<->>"                      {   yylval.i = 4; return CMP;                        }
"<<->"                      {   yylval.i = 5; return CMP;                        }
">-<"                       {   yylval.i = 0; return CMP;                        }
"<->"                       {   yylval.i = 1; return CMP;                        }

"->>"                       {   yylval.i = 1; return RIGHT_ARROW;                }

"<-"                        {   return LEFT_ARROW;                               }
"->"                        {   yylval.i = 0; return RIGHT_ARROW;                }

">"                         {   yylval.i = 2; return CMP;                        }
"<"                         {   yylval.i = 3; return CMP;                        }

"+"                         {   return '+';                                      }
"-"                         {   return '-';                                      }
"*"                         {   return '*';                                      }
"/"                         {   return '/';                                      }
"%"                         {   return '%';                                      }
"("                         {
                                return '('; // ) for dummy purpose
                            }
")"                         {   return ')';                                      }
":"                         {   return ':';                                      }

{H}+[#]                     {
                                yylval.l = hexToDec(yytext);
                                return CONSTANT;
                            }
{D}+                        {
                                yylval.l = atoi(yytext);
                                return CONSTANT;
                            }
"$"{L}                      {
                                yylval.i = getReg(yytext[1]);
                                return REG;
                            }

[iI][fF]                    {   return IF;                                       }
[eE][lL]                    {   return ELSE;                                     }
[rR][pP]                    {   return REPEAT;                                   }

"\""([^\"])*"\""            {
                                yylval.s = strdup(yytext);
                                return TEXT;
                            }

\n                          {
                                // yylineno++;
                                BEGIN(START);
                                return NL;
                            }

<<EOF>>                     {   return ENDFILE;                              }

[ \v\f]                     {   /* ignore whitespace */                          }

.                           {   return yytext[0];                                }

%%

long hexToDec(char *s)
{
    // } for dummy purpose
    int i = 0;
    long value = 0;
    for (i = 0; s[i] != '#'; i++) {
        value *= 16;
        if (s[i] >= '0' && s[i] <= '9') {
            value += s[i] - '0';
        } else {
            if (s[i] >= 65 && s[i] <= 90)
                s[i] = s[i] + 32;
            value += s[i] - 'a' + 10;
        }
    }

    return value;
}

int getReg(char c)
{
    // } for dummy purpose
    if (c >= 'A' && c <= 'Z') {
        return c - 'A';
    } else if (c >= 'a' && c <= 'z') {
        return c - 'a' + 26;
    }
    return -1;
}

// test flex
// int main(int argc, char **argv)
// {
//     yyin = fopen(argv[1], "r");
    
//     int token;

//     while((token = yylex())) {
//         printf("[%d", token);

//         if (token == 300 || token == 301) {
//             printf(", %s", yytext);
//         }

//         printf("]\n");
//     }

//     fclose(yyin);

//     return 0;
// }
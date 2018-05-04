
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct buffer_t buffer_t;
struct buffer_t {
    char *str;

    buffer_t *next;
} **cur_buf;

typedef struct block_t block_t;
struct block_t {
    block_t *back;

    // int type;               // 0 = if, 1 = else, 2 = repeat
    int id;
    // int right;
    int level;
} *blocks;

typedef struct text_t text_t;
struct text_t {
    int id;
    char *msg;

    struct text_t *next;
} *texts;

typedef struct exp_t exp_t;
struct exp_t {
    int type;               // 0 = operator, 1 = immediate, 2 = register
    long val;
    int pos;               // 0 = left, 1 = right

    struct exp_t *left, *right;
} *exps;

void yyerror(char *);

int len(long);
buffer_t *buf(void);
buffer_t *create_buf(void);

void add_all(char *, char *, long, char *);
void add(char *, char *);
// void add_ins(char *);
void add_label(char *, int);
void add_syscall(void);
void addln(char *);
// void add_space(int);

int create_block(void);
int else_eligible(int);
void check_stm(int, int);
int create_text(char *);
exp_t *create_exp(int, long, exp_t *, exp_t *);
void add_exp(exp_t *);
void add_cmp(int, int);
void print_dec(void);
void print_hex(void);

extern void print(char *, char *);
extern void print_ins(char *);
extern void print_syscall(void);
extern void println(char *);
extern void print_space(int);
extern FILE *fp;

int indent_level = 0;
int cond_id = 0, loop_id = 0, pow_id = 0;

%}

%union {
    struct exp_t *e;
    struct buffer_t *b;
    int i;
    long l;
    char *s;
}

%start file

%token <i>  REG
%token <l>  CONSTANT
%token <s>  TEXT NL
%token      '(' ')'
%token      '^' NEG '*' '/' '%' '+' '-'
%token <i>  CMP
%token      LEFT_ARROW RIGHT_ARROW DRIGHT_ARROW
%token      IF ELSE REPEAT
%token      INDENT DEDENT
%token      END_OF_FILE 0

%type <e>   exp
%type <i>   hex
%type <s>   text
%type <b>   line stm assignexp printexp ifexp elsexp loopexp

%left                                   '+' '-'
%left                                   '*' '/' '%'
%precedence                             NEG
%right                                  '^'

%%

file:
  line END_OF_FILE                      {
                                            // buffer_t *tail = $1;
                                            // while (tail) {
                                            //     // if (tail->str != NULL) {
                                            //         println(tail->str);
                                            //         printf("test");
                                            //     // }
                                            //     tail = tail->next;
                                            // }

                                            // append exit to assembly
                                            print("MOV", "RAX, SYS_EXIT");
                                            print("MOV", "RDI, EXIT_CODE");
                                            print_syscall();
                                            println("");

                                            // print functions
                                            print_dec();
                                            println("");
                                            print_hex();
                                            println("");

                                            // data section
                                            print("section", ".data");

                                            // append constant variable
                                            println("SYS_WRITE       EQU     1");
                                            println("STD_OUT         EQU     1");
                                            println("SYS_EXIT        EQU     60");
                                            println("EXIT_CODE       EQU     0\n");

                                            // append register data ($A - $z)
                                            println("reg             TIMES   52 DQ 0\n");

                                            // append some useful characters
                                            println("nl              DB      0xA");
                                            println("dash            DB      0x2D");

                                            // bss section
                                            println("");
                                            print("section", ".bss");

                                            // append temp of print data
                                            println("number          RESB    20");

                                            // append text data
                                            text_t *t;
                                            for (t = texts; t != NULL; t = t->next) {
                                                fprintf(fp, "t%-14d DB      ", t->id);
                                                fprintf(fp, "%s\n", t->msg);
                                                // TODO: print NEWLINE?
                                            }
                                        }
;

line:
  statement                                   {
                                            // $$ = $1;
                                        }
| line statement                              {
                                            // $1->next = $2;
                                            // $$ = $1;
                                            // printf("=%d/%d=", $1, $2);
                                        }
;

end:
  NL
| END_OF_FILE
;

statement:
  stm                                   {
                                            buffer_t *tail = $1;
                                            while (tail) {
                                                if (tail->str) {
                                                    println(tail->str);
                                                }
                                                tail = tail->next;
                                            }
                                            println("");
                                        }
;

stm:
  assignexp end                         {   $$ = $1;                                    }
| printexp end                          {   $$ = $1;                                    }
| ifexp
| loopexp
;

text:
  %empty                                {   $$ = 0;                                     }
| TEXT                                  {   $$ = $1;                                    }
;

hex:
  %empty                                {   $$ = 0;                                     }
| '#'                                   {   $$ = 1;                                     }
;

exp:
  CONSTANT                              {   $$ = create_exp(1, $1, NULL, NULL);         }
| REG                                   {   $$ = create_exp(2, $1 * 8, NULL, NULL);     }
| exp '+' exp                           {
                                            $1->pos = 0;
                                            $3->pos = 1;
                                            $$ = create_exp(0, '+', $1, $3);
                                        }
| exp '-' exp                           {
                                            $1->pos = 0;
                                            $3->pos = 1;
                                            $$ = create_exp(0, '-', $1, $3);
                                        }
| exp '*' exp                           {
                                            $1->pos = 0;
                                            $3->pos = 1;
                                            $$ = create_exp(0, '*', $1, $3);
                                        }
| exp '/' exp                           {
                                            if ($3) {
                                                $1->pos = 0;
                                                $3->pos = 1;
                                                $$ = create_exp(0, '/', $1, $3);
                                            } else {
                                                yyerror("division by zero");
                                                YYABORT;
                                            }
                                        }
| exp '%' exp                           {
                                            if ($3) {
                                                $1->pos = 0;
                                                $3->pos = 1;
                                                $$ = create_exp(0, '%', $1, $3);
                                            } else {
                                                yyerror("modulo by zero");
                                                YYABORT;
                                            }
                                        }
| '-' exp  %prec NEG                    {
                                            $2->pos = 0;
                                            $$ = create_exp(0, '~', $2, NULL);
                                        }
| '+' exp                               {
                                            yyerror("syntax error");
                                            YYERROR;
                                        }
| exp '^' exp                           {
                                            $1->pos = 0;
                                            $3->pos = 1;
                                            $$ = create_exp(0, '^', $1, $3);
                                        }
| '(' exp ')'                           {   $$ = $2;                                    }
;

printexp:
  exp RIGHT_ARROW hex                   {
                                            $$ = buf();

                                            if ($3) {   // print HEX
                                                add_exp($1);
                                                add("CALL", "print_hex");
                                            } else {    // print DEC
                                                add_exp($1);
                                                add("CALL", "print_dec");
                                            }
                                        }
| text RIGHT_ARROW                      {
                                            $$ = buf();
                                            
                                            // TODO: ->>  |  - > >   addln()
                                            if ($1) {   // print TEXT
                                                // TODO: recheck above
                                                int id = create_text($1);

                                                add("MOV", "RAX, SYS_WRITE");
                                                add("MOV", "RDI, STD_OUT");
                                                // add_ins("MOV");
                                                // fprintf(fp, "RSI, t%d\n", id);
                                                add_all("MOV", "RSI, t", id, "");
                                                // add_ins("MOV");
                                                // fprintf(fp, "RDX, %lu\n", strlen($1) - 2);
                                                add_all("MOV", "RDX, ", strlen($1) - 2, "");
                                                add_syscall();

                                            // print NEWLINE
                                            } else {
                                                add("MOV", "RAX, SYS_WRITE");
                                                add("MOV", "RDI, STD_OUT");
                                                add("MOV", "RSI, nl");
                                                add("MOV", "RDX, 1");
                                                add_syscall();
                                            }
                                        }
;

assignexp:
  REG LEFT_ARROW exp                    {
                                            $$ = buf();
                                            
                                            add_exp($3);
                                            // add_ins("MOV");
                                            // fprintf(fp, "[reg + %d], RAX\n\n", $1 * 8);
                                            add_all("MOV", "[reg + ", $1 * 8, "], RAX\n");
                                        }
;

ifexp:
  IF '(' exp CMP exp ')' ':' NL INDENT stm DEDENT elsexp
                                        {
                                            $$ = buf();
                                            
                                            int id = create_block();

                                            add_exp($3);
                                            add("MOV", "RBX, RAX");
                                            add_exp($5);

                                            add_cmp($4, id);
                                            addln("");

                                            // fprintf(fp, "\nelse%d:\n", id);
                                        }
;

elsexp:
  %empty                                {}
| ELSE ':' NL INDENT stm DEDENT         {
                                            $$ = buf();
                                            
                                        }
;

loopexp:
  REPEAT '(' exp '|' exp ')' ':' NL INDENT stm DEDENT
                                        {
                                            $$ = buf();
                                            
                                            // create_block();
                                            // printf("repeat %d -> %d:\n", $3, $5);
                                        }
;

%%

void yyerror(char *s) {
    fprintf(stderr, "! ERROR: %s\n", s);
}

int len(long num) {
    int n = 0;
    while (num > 0) {
        num /= 10;
        n++;
    }
    return n;
}

buffer_t *buf() {
    *cur_buf = malloc(sizeof(buffer_t));
    (*cur_buf)->str = NULL;
    (*cur_buf)->next = NULL;
    return *cur_buf;
}

buffer_t *create_buf() {
    buffer_t *t = *cur_buf;
    // if (!t->str) {
    //     return t;
    // }
    while (t->next != NULL) {
        t = t->next;
    }
    t->next = malloc(sizeof(buffer_t));
    return t->next;
}

void add_all(char *ins, char *param, long num, char *tail) {
    buffer_t *buff = create_buf();

    char *tmp = malloc(sizeof(char) + 24 + strlen(param) + len(num) + strlen(tail));
    sprintf(tmp, "%16s%-7s %s%ld%s", "", ins, param, num, tail);
    buff->str = tmp;
    buff->next = NULL;
}

void add(char *ins, char *param) {
    buffer_t *buff = create_buf();

    char *tmp = malloc(sizeof(char) + 24 + strlen(param));
    sprintf(tmp, "%16s%-7s %s", "", ins, param);
    buff->str = tmp;
    buff->next = NULL;
}

void add_label(char *label, int num) {
    buffer_t *buff = create_buf();

    char *tmp = malloc(sizeof(char) * 2 + strlen(label) + len(num));
    sprintf(tmp, "%s%d:", label, num);
    buff->str = tmp;
    buff->next = NULL;
}

void add_syscall(void) {
    add("syscall", "");
}

void addln(char *str) {
    buffer_t *buff = create_buf();
    char *tmp = malloc(sizeof(char) + strlen(str));
    sprintf(tmp, "%s", str);
    buff->str = tmp;
    buff->next = NULL;
}

int create_block() {
    block_t *block = (block_t *) malloc(sizeof(block_t));
    block->back = blocks;
    // block->type = type;
    // if (type >= 0 && type <= 1)
        block->id = cond_id++;
    // else if (type == 2)
    //     block->id = loop_id++;
    block->level = indent_level++;
    // indent_level++;

    blocks = block;
    return block->id;
}

int else_eligible(int indent) {
    block_t *t = blocks;

    int i = 0;
    while (t && t->level >= indent) {
        i++;
        if (t->level == indent) {
            return i;
        }
        t = t->back;
    }
    return i;
}

void check_stm(int indent, int is_if) {
    block_t *t = blocks;
    if (is_if)
        indent++;
    while (t && t->level >= indent) {
        blocks = t->back;
        free(t);
        t = blocks;
    }
}

int create_text(char *msg) {
    text_t *t = texts;

    if (t == NULL) {
        texts = (text_t *) malloc(sizeof(text_t));
        t = texts;
        t->id = 0;
    } else {
        while (t->next != NULL)
            t = t->next;
        t->next = (text_t *) malloc(sizeof(text_t));
        t->next->id = t->id + 1;
        t = t->next;
    }
    t->msg = strdup(msg);
    t->next = NULL;

    return t->id;
}

exp_t *create_exp(int type, long val, exp_t *left, exp_t *right) {
    exp_t *exp = (exp_t *) malloc(sizeof(exp_t));
    exp->type = type;
    exp->val = val;
    exp->pos = -1;
    exp->left = left;
    exp->right = right;

    return exp;
}

void add_exp(exp_t *exp) {
    if (exp == NULL)
        return;

    if (exp->left != NULL) {
        // add("PUSH", "RDX");
        add_exp(exp->left);
        // add("POP", "RDX");
    }
    
    if (exp->right != NULL) {
        add("PUSH", "RCX");
        add_exp(exp->right);
        add("POP", "RCX");
    }

    if (exp->type == 0) {           // operator
        if (exp->val == '+') {
            if (exp->pos == -1) {
                add("MOV", "RAX, RCX");
                add("ADD", "RAX, RDX");
            } else if (exp->pos == 0) {
                add("ADD", "RCX, RDX");
            } else if (exp->pos == 1) {
                add("ADD", "RDX, RCX");
            }
        } else if (exp->val == '-') {
            if (exp->pos == -1) {
                add("MOV", "RAX, RCX");
                add("SUB", "RAX, RDX");
            } else if (exp->pos == 0) {
                add("SUB", "RCX, RDX");
            } else if (exp->pos == 1) {
                add("NEG", "RDX");
                add("ADD", "RDX, RCX");
            }
        } else if (exp->val == '*') {
            add("MOV", "RAX, RCX");
            add("IMUL", "RDX");
            if (exp->pos == -1) {
                // done
            } else if (exp->pos == 0) {
                add("MOV", "RCX, RAX");
            } else if (exp->pos == 1) {
                add("MOV", "RDX, RAX");
            }
        } else if (exp->val == '/') {
            add("MOV", "RAX, RCX");
            add("DIV", "RDX");
            if (exp->pos == -1) {
                // done
            } else if (exp->pos == 0) {
                add("MOV", "RCX, RAX");
            } else if (exp->pos == 1) {
                add("MOV", "RDX, RAX");
            }
        } else if (exp->val == '%') {
            add("MOV", "RAX, RCX");
            add("DIV", "RDX");
            if (exp->pos == -1) {
                add("MOV", "RAX, RDX");
            } else if (exp->pos == 0) {
                add("MOV", "RCX, RDX");
            } else if (exp->pos == 1) {
                // done
            }
        } else if (exp->val == '^') {
            add("XOR", "RSI, RSI");
            add("MOV", "RAX, 1");
            add("MOV", "R9, RDX");

            // fprintf(fp, "pow%d:\n", pow_id);
            add_label("pow", pow_id);
            add("MUL", "RCX");
            add("INC", "RSI");

            add("CMP", "RSI, R9");
            // add_ins("JL");
            // fprintf(fp, "pow%d\n", pow_id++);
            add_all("JL", "pow", pow_id++, "");

            if (exp->pos == -1) {
                // done
            } else if (exp->pos == 0) {
                add("MOV", "RCX, RAX");
            } else if (exp->pos == 1) {
                add("MOV", "RDX, RAX");
            }
        } else if (exp->val == '~') {
            add("NEG", "RCX");
            if (exp->pos == -1) {
                add("MOV", "RAX, RCX");
            } else if (exp->pos == 0) {
                // done
            } else if (exp->pos == 1) {
                add("MOV", "RDX, RCX");
            }
        }
        addln("");
    } else if (exp->type == 1) {    // immediate
        // add_ins("MOV");
        if (exp->pos == 0) {    // left arm
            // fprintf(fp, "RCX, %ld\n", exp->val);
            add_all("MOV", "RCX, ", exp->val, "");
        } else if (exp->pos == 1) {                // right arm
            // fprintf(fp, "RDX, %ld\n", exp->val);
            add_all("MOV", "RDX, ", exp->val, "");
        } else {
            // fprintf(fp, "RAX, %ld\n", exp->val);
            add_all("MOV", "RAX, ", exp->val, "");
        }
    } else if (exp->type == 2) {    // register
        // add_ins("MOV");
        if (exp->pos == 0) {    // left arm
            // fprintf(fp, "RCX, [reg + %ld]\n", exp->val);
            add_all("MOV", "RCX, [reg + ", exp->val, "]");
        } else if (exp->pos == 1) {                // right arm
            // fprintf(fp, "RDX, [reg + %ld]\n", exp->val);
            add_all("MOV", "RDX, [reg + ", exp->val, "]");
        } else {                // center
            // fprintf(fp, "RAX, [reg + %ld]\n", exp->val);
            add_all("MOV", "RAX, [reg + ", exp->val, "]");
        }
    }
}

void add_cmp(int op, int id) {
    add("CMP", "RBX, RAX");
    if (op == 0)
        // add_ins("JE");
        add_all("JE", "else", id, "");
    else if(op == 1)
        add_all("JNE", "else", id, "");
    else if(op == 2)
        add_all("JLE", "else", id, "");
    else if(op == 3)
        add_all("JGE", "else", id, "");
    else if(op == 4)
        add_all("JL", "else", id, "");
    else if(op == 5)
        add_all("JG", "else", id, "");
    // fprintf(fp,"else%d\n",id);
}

void print_dec() {      // print RAX
    println("print_dec:");

    // resources
    print("LEA", "R9, [number + 18]");
    print("MOV", "R10, R9");
    print("MOV", "RSI, 10");

    // print newline
    // print("MOV", "byte [R9], 10");
    // print("DEC", "R9");

    // check if RAX is negative
    print("XOR", "RCX, RCX");
    print("CMP", "RAX, 0");
    print("JGE", "pd_lp");
    print("NEG", "RAX");
    print("MOV", "RCX, 1");
    
    // put last digit to stack
    println("pd_lp:");
    print("XOR", "RDX, RDX");
    print("DIV", "RSI");
    print("ADD", "RDX, 0x30");
    print("MOV", "byte [R9], DL");
    print("DEC", "R9");
    // loop
    print("TEST", "RAX, RAX");
    print("JNZ", "pd_lp");

    // print prefix
    print("TEST", "RCX, RCX");
    print("JZ", "pd_dash");
    print("MOV", "byte [R9], 0x2D");          // -
    print("DEC", "R9");

    // calculate digit amount
    println("pd_dash:");
    print("SUB", "R10, R9");

    // print
    print("INC", "R9");
    print("MOV", "RAX, SYS_WRITE");
    print("MOV", "RDI, STD_OUT");
    print("MOV", "RSI, R9");
    print("MOV", "RDX, R10");
    print_syscall();
    print("RET", "");
}

void print_hex() {
    println("print_hex:");

    // resources
    print("LEA", "R9, [number + 18]");
    print("MOV", "R10, R9");
    print("MOV", "RSI, 16");

    // print newline
    // print("MOV", "byte [R9], 10");
    // print("DEC", "R9");

    // check if RAX is negative
    print("CMP", "RAX, 0");
    print("JGE", "ph_lp");
    print("MOV", "RCX, 1");
    
    // put last digit to stack
    println("ph_lp:");
    print("XOR", "RDX, RDX");
    print("DIV", "RSI");

    // condition to add ascii to reminder
    print("CMP", "RDX, 10");
    print("JL", "ph_str");
    print("ADD", "RDX, 0x07");

    println("ph_str:");
    print("ADD", "RDX, 0x30");
    print("MOV", "byte [R9], DL");
    print("DEC", "R9");
    // loop
    print("TEST", "RAX, RAX");
    print("JNZ", "ph_lp");

    // print prefix
    print("MOV", "word [R9 - 1], 0x7830");          // 0x
    print("SUB", "R9, 2");

    // calculate digit amount
    print("SUB", "R10, R9");

    // print
    print("INC", "R9");
    print("MOV", "RAX, SYS_WRITE");
    print("MOV", "RDI, STD_OUT");
    print("MOV", "RSI, R9");
    print("MOV", "RDX, R10");
    print_syscall();
    print("RET", "");
}
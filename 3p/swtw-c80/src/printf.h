/* printf.h: definitions for printf and fprintf to allow multiple args.
 */

#undef printf
#undef fprintf
#undef sprintf
#define printf prnt_1(),prnt_2
#define fprintf prnt_1(),prnt_3
#define sprintf prnt_1(),prnt_4

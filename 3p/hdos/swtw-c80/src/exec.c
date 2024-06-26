
/*
 *	exec.c - execute a command with arguments
 */

char	QCOMMAND[20];

exec(com,arg)
char	*com,*arg; {
	char	i;
	int	fdes;

	QCOMMAND[0] = 0;

	/*	build command	*/

	if(com[3] != ':')
		strcat(QCOMMAND,"SY0:");
	strcat(QCOMMAND,com);
	strcat(QCOMMAND,".ABS");

	if(com[3] != ':')
		for( i = '0' ; i <= '2' ; i++ ) {
			QCOMMAND[2] = i;
			if((fdes = fopen(QCOMMAND,"r")) > 0 ) {
				fclose(fdes);
				link(QCOMMAND,arg);
			}
		}
	else
		if((fdes = fopen(QCOMMAND,"r")) > 0 ) {
			fclose(fdes);
			link(QCOMMAND,arg);
		}
}

strcat(s1, s2)
char *s1, *s2;
{
	char *os1;

	os1 = s1;
	while (*s1++)
		;
	--s1;
	while (*s1++ = *s2++)
		;
	return(os1);
}

strlen(s)
char	*s; {
	int	n;

	n = 0;
	while(*s++)
		n++;
	return(n);
}

char	*stack;

link(com,arg)
char	*com,*arg; {
	int	len;

	len = strlen(arg);
	if(len == 0)
		stack = 8832;
	else {
		stack = 8832 - len - 1;
		stack[0] = 0;
		strcat(stack,arg);	/* push arg onto stack */
	}

#asm
	LHLD	stack
	SPHL
	LXI	H,QCOMMAND
	DB	255,40Q
	DB	255,0
#endasm
}

/* Set IO redirection vectors
 *
 * Version 3.103
 *
 * Date last modified: 7/10/84 13:50 drm
 *
 * "IOREDIR.C"
 *
 */

#include "SETUP30.H"

#define STLNE	5
#define NLNE	12
#define STCOL	35
#define NCOL	5
   
setiored(filename)		/* main entry point for set io redirection */
	char *filename;
	{
	word redvec[5];
	short inp;
 
	clrscr();
	initcur(STLNE,NLNE,STCOL,NCOL,9,8,8,8);
	cpyred(redvec,redirvec);
	prtrhd();
	prtrfix();
	prtrvar(redvec);
	prtcur(filename);
	curline=curcol=0; 
	do
		{
		inp=getrfld(redvec);
		if(inp==WHITE)
			{
			cpyred(redvec,redirvec);
			prtrvar(redvec);
			curline=curcol=0; 
			}
		if(inp==BLUE)
			{
			cpyred(redirvec,redvec);
			if(putredir()==ERROR)
				{
				putwin(1,errmsg(errmsg()));
				bell();
				inp=NULL;
				}
			}
		}
	while(inp!=BLUE && inp!=RED);
	curon();
	return(OK);
	}

cpyred(rvec1,rvec2)			/* copy rvec1 = rvec2	*/
	word *rvec1,*rvec2;
	{
	short i;

	for(i=0;i<5;++i)		/* reverse low and high bytes */
		rvec1[i]=rvec2[i]>>8 | rvec2[i]<<8;
	}

prtrhd()				/* print headings */
	{
	puts("                          I/O Device Redirection\n\n");
	puts("                   Physical     ------------ Logical Name ------------\n");
	puts("      Device #       Name       CONIN:  CONOUT:  AUXIN:  AUXOUT:  LST:\n");
	putwin(3,"   X     = Assign logical device");
	putwin(5,"<DELETE> = Delete assignment");
	}

prtrfix()				/* print fix device number and name */
	{
	short devnum,dev,mod;
	
	cursor((STLNE-1)*getwidth()+1);
	for(devnum=CHIONUM;devnum<CHIONUM+NLNE;++devnum)
		{
		if((dev=searchchr(devnum,&mod))==ERROR)
			printf("        %d        no device\n",devnum);
		else
			printf("        %d          %s\n",devnum,chrptrtbl[mod]->charpart[dev].chrstr);
		}
	}

prtrvar(redvec) 			/* print all variable fields */
	word *redvec;
	{
	for(curcol=0;curcol<NCOL;++curcol)
		prtred(redvec);
	}

prtred(redvec)				/* print redirection field */
	word *redvec;
	{
	short i,mod;

	for(i=0;i<NLNE;++i)
		{
		if(testbit(&redvec[curcol],i)==1)
			prtpos(i,curcol,"X");
		else
			if(searchchr(i+CHIONUM,&mod)==ERROR)
				prtpos(i,curcol," ");
			else
				prtpos(i,curcol,".");
		}
	}

getrfld(redvec) 			/* get recdirection field */
	word *redvec;
	{
	short inp;
	word temp;
	
	currnt();
	curon();
	do
		{
		inp=getcntrl();
		putwin(7,"");
		if(inp==BLUE || inp==RED || inp==WHITE)
			return(inp);
		movcur(inp,NCOL,NLNE);
		currnt();
		}
	while(inp!=NULL);
	inp=toupper(getchr());
	if(inp>=' ' && inp<=0x7E)
		{
		if(chkrvec(redvec)!=ERROR)
			setbit(&redvec[curcol],curline);
		else
			bell();
		}
	else if(inp==DELETE)
		{
		temp=redvec[curcol];
		clearbit(&temp,curline);
		if(temp==0)
			{
			putwin(7,"At least one device required");
			bell();   
			}
		else
			clearbit(&redvec[curcol],curline);
		}
	else if(inp==NULL)
		return(NULL);
	else
		bell();
	curoff();
	prtred(redvec);
	return(NULL);
	}

chkrvec(redvec) 		       /* check vector for input with a log */
	word *redvec;		       /* input device and output with a log */
	{			       /* output device */
	short mod,i,dev;

	if((dev=searchchr(curline+CHIONUM,&mod))==ERROR)
		{
		putwin(7,"Physical device does not exist");
		return(ERROR);
		}
	if(curcol==0 || curcol==2)	/* check logical input device */
		{
		if(!chrptrtbl[mod]->charpart[dev].indev)
			{
			putwin(7,"Physical input device required");
			return(ERROR);
			}
		}
	else				/* check logical output device */
		if(!chrptrtbl[mod]->charpart[dev].outdev)
			{
			putwin(7,"Physical output device required");
			return(ERROR);
			}
	return(OK);
	}

searchchr(devnum,mod)			/* search character table for device */
	short devnum,*mod;		/* number to get device name */
	{
	for(*mod=0;*mod<numchario;++*mod)
		{
		if(devnum>=chrptrtbl[*mod]->compart.phydevnum &&
		devnum<(chrptrtbl[*mod]->compart.phydevnum+chrptrtbl[*mod]->compart.numdev))
			return((devnum-chrptrtbl[*mod]->compart.phydevnum));
		}
	return(ERROR);
	}
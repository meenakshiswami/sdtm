/*program header*/
/*******************************************************************
program name  :
program version:
sas version:
created by:
date:
program purpose:
output:
macro called:
***************************/



libname vm_1 "/home/u60094620/vm project";
libname prog "/home/u60094620/vm project/program";
/*extracting from dm*/
data dm1(keep=STUDYID DOMAIN USUBJID SUBJID siteid brthdtc ageu sex race ethnic subject);
	length sex $1. race $5. ethnic $22.;
	set vm_1.dm;
	studyid='CMP135';
	domain='DM';
	subjid=strip(SUBJECT);
	siteid=Strip(SITENUMBER);
	usubjid=strip(STUDYID)||'-'||SUBJID;
	brthdtc=PUT(mdy(brthdtn_mm, brthdtn_dd, brthdtn_yy), yymmdd10.);

	/*birthdtc=put(input(brthdtn_raw, date11.),yymmdd10.);
	B=PUT(DATEPART(BRTHDTN),YYMMDD10.);*/
	ageu='YEARS';
	sex=SEX;
	race=upcase(RACE);
	ethnic=upcase(ETHNIC);
run;

/*finding rficdtc(consent date) from enr*/
data enr;
	set vm_1.enr;
	rficdtc=put(datepart(cnstdtn), yymmdd10.);
	arm=enrgrp;
	armcd='CMP135_5';
RUN;

/*extracting from ex(finding start and end date)*/
data ex;
	set vm_1.ex;
run;

proc sort data=ex out=ex1;
	by subject exstdtn;
run;
/*start date*/
data ex2(keep=rfstdtc rfxstdtc1 subject exsttm1);
	set ex1;
	by subject exstdtn;
	if first.subject then do;
		rfstdtc=put(datepart(exstdtn), yymmdd10.);
		
		end;
    if first.subject and exdose>0 then do;
		rfxstdtc1=put(datepart(exstdtn), yymmdd10.);
		exsttm1 = exsttm;
		end;
    if not first.subject then delete;
 run;
 
/*end date*/
data ex3(keep=rfxendtc1 subject exsttm2);
	set ex1;
by subject exstdtn;

	if last.subject and exdose>0 then do;
		rfxendtc1=put(datepart(exstdtn), yymmdd10.);
		exsttm2=exsttm;
		end;

	if not last.subject then
		delete;
run;
		
/* finding actarmcd and actarm*/
proc sql;
	create table ex4 as select subject, sum(exdose) as sumdose from ex1 group by 
		subject;
quit;

data ex5;
	set ex4;

	if sumdose>0 then
		do;
			actarmcd='CMP135_5';
			actarm='Group 1';
		end;
run;

/*combining dates and time and actarm*/
proc sort data=ex2;
	by subject;
run;

proc sort data=ex3;
	by subject;
run;

proc sort data=ex5;
	by subject;
	
run;

data final_ex(drop=sumdose);
	merge ex2 ex3 ex5;
	by subject;
	
	rfxstdtc =rfxstdtc1||'T'||exsttm1;
	if exsttm2 ne null then 
	rfxendtc =rfxendtc1||'T'||exsttm2;
	 else rfxendtc =rfxendtc1;
run;

/*extrcting from inv*/
data inv;
	set vm_1.inv;
	country=country;
	invnam=strip(invfname)||" "||invlname;
	invid=INVID;
run;

/*finding(dmdtc) from dov*/
data dov;
	set vm_1.dov;
   where foldername='Screening' ;
		dmdtc=put(datepart(visdtn), yymmdd10.);
run;

/*finding rfendtc and rfpendtc from ds*/
data ds;
	set vm_1.ds;
	rfendtc=put(datepart(dsstdat), yymmdd10.);
	rfpendtc=rfendtc;
run;

/*finding dthfl and dthdtc from AE*/
data ae  (keep=dthfl dthdtc subject);
	set vm_1.ae;
  where aeout='Fatal';
	if aeout='Fetal' then do;
	dthfl='y';
		dthdtc=put(datepart(aeendtn), yymmdd10.);
	end;
else
	do;
		dthfl='';
		dthdtc='';
	end;
run;

/* merging all*/
proc sort data=inv;
	by siteid;
run;

proc sort data=dm1;
	by siteid;
run;

data merged;
	merge dm1(in=a) inv;
	by siteid;
    if a;
run;

proc sort data=merged;
by subject;
run;

proc sort data=final_ex;
	by subject;
run;

proc sort data=ae;
	by subject;
run;

proc sort data=dov;
	by subject;
run;

proc sort data=ds;
	by subject;
run;

proc sort data=enr;
	by subject;
run;
/* mapping  dmdy*/
data final_merged;
	merge merged(in=a) final_ex ae dov ds enr;
	by subject;
	age=int(yrdif(input(brthdtc, yymmdd10.), input(rficdtc, yymmdd10.), 'actual'));
	
stdt=input(rfstdtc, yymmdd10.);
scrdt=input(dmdtc, yymmdd10.);
if scrdt>=stdt then dmdy= (scrdt-stdt+1);
else dmdy=(scrdt-stdt);
	
/* labelling*/
data prog.dm;
	attrib 
		STUDYID label="study identifier" length=$6. 
		DOMAIN label="domain abbreviation	" length=$2. 
		USUBJID label="unique subject identifoer" length=$16. 
		SUBJID label="subject identifier for the study" length=$9. 
		RFSTDTC label="subject reference strt date/time" length=$10. 
		RFENDTC label="	subject reference end date/time" length=$10. 
		RFXSTDTC label="date/time of first study treatment" length=$16. 
		RFXENDTC label="date/time of last study treatment" length=$16. 
		RFICDTC label="date/time of informed consent" length=$10. 
		RFPENDTC label="date/time of end of participation" length=$10. 
		DTHDTC label="date/time of death" length=$1. 
		DTHFL label="subject death flag" length=$1. 
		SITEID label="study site identifier" length=$4. 
		INVID label="investigator identifier" length=$4. 
		INVNAM label="investigator name" length=$13. 
		BRTHDTC label="date/time of birth" length=$10. 
		AGE label="age" length=8. 
		AGEU label="Age Units" length=$5. 
		SEX label="sex" length=$1. 
		RACE label="race" length=$5. 
		ETHNIC label="ethnicity" length=$22. 
		ARMCD label="planned arm code" length=$8. 
		ARM label="planned arm" length=$7. 
		ACTARMCD label="actual arm code" length=$8. 
		ACTARM label="actual arm" length=$7. 
		COUNTRY label="country" length=$3. 
		DMDTC label="date/time of collection" length=$10. 
		DMDY label="study day of collection" length=8.;
	set final_merged;
	keep STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC 
		RFPENDTC DTHDTC DTHFL SITEID INVID INVNAM BRTHDTC AGE AGEU SEX RACE ETHNIC 
		ARMCD ARM ACTARMCD ACTARM COUNTRY DMDTC DMDY;
run;
/* creating xpt*/
libname xpt xport "/home/u60094620/vm project/program/dm_f.xpt" ; 
data xpt.dm_f;
set prog.dm;
/*converting xpt in sasfile*/
libname sasfile "/home/u60094620/xpt_v";
libname xpt xport "/home/u60094620/vm project/program/dm_f.xpt" ; 
proc copy inlib=xpt outlib=sasfile; run; 

libname xpt xport "/home/u60094620/xpt_v/dm.xpt" access=readonly; 
proc copy inlib=xpt outlib=sasfile; run;

/*validation of sas files*/
proc compare base=sasfile.dm_f compare=sasfile.dm;
run;

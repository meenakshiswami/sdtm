libname vm_1 "/home/u60094620/vm project";
libname prog "/home/u60094620/vm project/program";

/*extracting  from ds	*/
data ds1;
length DSTERM $25	DSDECOD	$25  DSSCAT $26 DSCAT $26 ;
	set vm_1.ds;
	studyid='CMP135';
	domain='DS';
	subjid=strip(SUBJECT);
	usubjid=strip(STUDYID)||'-'||SUBJID;
	
	if datapagename="Subject Disposition (End of Study)" then do;
	dsterm='COMPLETED';
	dsdecod='COMPLETED';
	dscat="DISPOSITION EVENT";
	dsscat="END OF STUDY";
	dsstdtc=put(datepart(dsstdat), yymmdd10.);
	end;
	
/*extracting  from enr	*/
data enr1(keep=SUBJECT STUDYID	DOMAIN	USUBJID	dsstdtc	DSTERM	DSDECOD	DSSCAT	DSCAT);
length DSTERM $25	DSDECOD	$25  DSSCAT $26  DSCAT $26 ;
	set vm_1.enr;
	studyid='CMP135';
	domain='DS';
	subjid=strip(SUBJECT);
	usubjid=strip(STUDYID)||'-'||SUBJID;
	
	if datapagename="System Enrollment" then do;
	dsstdtc=put(datepart(cnstdtn), yymmdd10.);
	dsterm="INFORMED CONSENT OBTAINED";
	dsdecod="INFORMED CONSENT OBTAINED";
	dscat="PROTOCOL MILESTONE";
	dsscat="INFORMED CONSENT";
	end;

/*extracting  from dsdd	*/	
data dsdd1(keep=SUBJECT STUDYID 	DOMAIN	USUBJID	dsstdtc	DSTERM	DSDECOD	DSSCAT	DSCAT);
length DSTERM $25	DSDECOD	$25  DSSCAT $26  DSCAT $26 ;
	set vm_1.dsdd;
	
	studyid='CMP135';
	domain='DS';
	subjid=strip(SUBJECT);
	usubjid=strip(STUDYID)||'-'||SUBJID;
	
	if datapagename="Study Drug Discontinuation " then do;
	dsstdtc=put(datepart(dsstdtn), yymmdd10.);
	dsterm="ADVERSE EVENT";
	dsdecod="ADVERSE EVENT";
	dscat="DISPOSITION EVENT";
	dsscat="STUDY DRUG DISCONTINUATION";
	
	end;


/* merging dsdd1, enr1 and ds1 for dsstdtc*/
data ds2;
	set enr1 ds1  dsdd1 ;
	
run;

/*extracting from ex for finding dsdy*/
data exx;
	set vm_1.ex;
	if exdose > 0;
run;

proc sort data=exx out=ex1;
	by subject exstdtn;
run;

data ex2;
	set ex1;
	by subject exstdtn;
	if first.subject then
		baseline=datepart(exstdtn) ;
	else
		delete;

	/* merging ex2 and ds3*/
proc sort data=ds2 out=ds3;
	by subject dsstdtc;
run;

data merge_exds;
	merge ex2 ds3;
	by subject;
	dsday=input(dsstdtc,yymmdd10.);
	
	if dsday>=baseline then
		dsstdy=dsday-baseline+1;
	else
		dsstdy=dsday-baseline;

/*extracting dates from se for epoch*/
data se1;
	set vm_1.se;

proc sort data=se1;
	by usubjid;
run;

 /*start date*/
proc transpose data=se1 out=se2 (drop=_name_) prefix=ST_;
	by usubjid;
	id etcd;
	var sestdtc;
run;
   /*end date*/
proc transpose data=se1 out=se3 (drop=_name_) prefix=EN_;
	by usubjid;
	id etcd;
	var seendtc;
run;
  /*merging dates for mapping epoch*/
 
proc sort data=merge_exds out=ds4;
	by usubjid;
run;

data ds5;
 length epoch $11;
	merge se2 se3 ds4;
	by usubjid;
	
	dsstdt=input(DSSTDTC, yymmdd10.);
	scrn=input(ST_SCRN, yymmdd10.);
	scrn_l=input(EN_SCRN, yymmdd10.);
	p1=input(ST_P1, yymmdd10.);
	p1_l=input(EN_P1, yymmdd10.);
	p2=input(ST_P2, yymmdd10.);
	p2_l=input(EN_P2, yymmdd10.);
	p3=input(ST_P3, yymmdd10.);
	p3_l=input(EN_P3, yymmdd10.);
	fu_l=input(EN_FU, yymmdd10.);
	fu=input(ST_FU, yymmdd10.);

	
	 if dscat ne "PROTOCOL MILESTONE" THEN DO;
	    if fu<= dsstdt <= fu_l then
		epoch='FOLLOW-UP';
	    else if p3<=dsstdt<=p3_l then
		epoch='MAINTENANCE';
		else if p2<=dsstdt<=p2_l then
		epoch='TITRATION';
		else if p1<=dsstdt<=p1_l then
		epoch='INDUCTION';
		else if scrn<=dsstdt <= scrn_l then
		epoch='SCREENING'; 
	end;
run;

/*for mapping dsseq*/
proc sort data=ds5 out=ds6;
	by usubjid DSDECOD DSSTDTC;
run;

data ds7;
	set ds6;
	by usubjid dsdecod DSSTDTC;

	if first.usubjid then
		DSSEQ=1;
	else
		DSSEQ+1;
run;

/*labelling*/

data final;
attrib
	STUDYID LABEL ="study identifier" length =$6.
 DOMAIN LABEL ="domain abbreviation" length =$2.
 USUBJID LABEL ="unique subject identifier" length =$16.
 DSSEQ LABEL ="sequence nuber" length = 8.
 DSTERM LABEL ="Reported Term for the Disposition Event" length =$25.
 DSDECOD LABEL ="Standardized Disposition term" length =$25.
 DSSCAT LABEL ="SubCategory for Disposition Event" length =$26.
 DSCAT LABEL ="Category for Disposition Event" length =$26.
 EPOCH LABEL ="epoch" length =$11.
 DSSTDTC LABEL ="Start Date/Time of Disposition Event" length =$10.
 DSSTDY LABEL ="Study Day of Start of Disposition Event" length = 8.;
set ds7;
keep STUDYID	DOMAIN	USUBJID	DSSEQ	DSTERM	DSDECOD	DSSCAT	DSCAT	EPOCH	DSSTDTC	DSSTDY;
run;

/*creating xpt*/
libname xpt xport "/home/u60094620/vm project/program/vs_f.xpt";

data xpt.ds_f;
	set final;

/*converting to xpt to sas files*/
libname sasfile "/home/u60094620/xpt_v";
libname xpt xport "/home/u60094620/vm project/program/ds_f.xpt";

proc copy inlib=xpt outlib=sasfile;
run;

libname xpt xport "/home/u60094620/xpt_v/ds.xpt" access=readonly;

proc copy inlib=xpt outlib=sasfile;
run;
/*validation of sas files*/
proc compare base=sasfile.ds_f compare=sasfile.ds;
run;
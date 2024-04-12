libname vm_1 "/home/u60094620/vm project";
libname prog "/home/u60094620/vm project/program";
/*extracting from vs*/
proc format;
	value $ code 'Weight'='WEIGHT' 'Height'='HEIGHT' 'Temperature'='TEMP' 
		'Respiratory Rate'='RESP' 'Heart Rate'='HR' 'Systolic Blood Pressure'='SYSBP' 
		'Diastolic Blood Pressure'='DIABP';
data vs1;
	length vsorres $5 vsstresc $5 vstestcd $6 vscat $23 vsorresu $11 vsorres $3 vsstresu $11 ;
	set vm_1.vs(REName=(vsorresu=_vsorresu vsorres=_vsorres));
	studyid='CMP135';
	domain='VS';
	subjid=strip(SUBJECT);
	usubjid=strip(STUDYID)||'-'||SUBJID;
	vstest=propcase(vstest);	
	vstestcd=strip(put(vstest, $code.));
	vsorres=strip(put(_vsorres, 5.));
	vsstresc=strip(put(_vsorres, 5.));
	vsstresn=round(input(vsorres,8.1),.01);
	vscat=datapagename;
	if vstestcd in("TEMP")THEN
		DO;
			vsorresu="C";
			vsstresu="C";
		end;

	if vstestcd in("DIABP", "SYSBP")THEN
		DO;
			vsorresu=_vsorresu;
			vsstresu=_vsorresu;
		end;

	if vstestcd in("RESP")THEN
		DO;
			vsorresu="BREATHS/MIN";
			vsstresu="BREATHS/MIN";
		end;

	if vstestcd in("HR")THEN
		DO;
			vsorresu="BEATS/MIN";
			vsstresu="BEATS/MIN";
		end;

	if vsorres_raw in('ND', 'U', 'X') then
		vsstat='NOT DONE';

	if vscat='Vital Signs Day 1' then
		vsblfl='Y';
	vsdtc=put(datepart(recorddate), yymmdd10.);
run;

/*finding baseline from ex*/
data exx;
set vm_1.ex ;
if exdose > 0;
run;

proc sort data=exx out=ex1;
	by subject exstdtn;
run;

proc sort data=vs1 out=vs2;
	by subject vsdtn vstestcd;
run;

data ex2;
	set ex1;
	by subject exstdtn;
	retain baseline;	
	if first.subject then
		baseline=put(datepart(exstdtn) , yymmdd10.);
	else
		baseline=baseline;
	
run;

/*merging ex and vs*/
data merge_exvs;
	merge ex2 vs2;
	by subject;

	if folder="UNS" or folder="SRV" THEN
		ord=2;
	else
		ord=1;

proc sort data=merge_exvs out=sort_v;
	by subject vstest vsdtn ord;
run;

/*mapping vsdy from merged_exvs*/
data vs3;
	set sort_v;
	by subject vstest vsdtn ord;
	vsday=input(vsdtc,yymmdd10.);
	basday=input(baseline,yymmdd10.);
	
	if vsday>=basday then
		vsdy=vsday-basday+1;
	else
		vsdy=vsday-basday;
run;

/* mapping visit visitnum using folder*/
data vs4;
	length visit $ 14.;
	set vs3;
	by subject vstest vsdtn ord;
	retain folder_r;

	if first.vstest then
		folder_r=.;

	if folder='SCREENING' then
		do;
			visitnum=-1;
			visit=propcase(strip(folder));
		end;
	else if index(upcase(folder), 'WEEK') THEN
		do;
			visitnum=substr(folder, 5, 2)*7-6;
			visit=instancename;
			folder_r=visitnum;
		end;
	else if folder='SRV' then
		do;
			visitnum=folder_r + 0.01;
			visit='Systemic'||'-'||strip(visitnum);
		end;
	else if folder='UNS' then
		do;
			visitnum=folder_r + 0.01;
			visit='Unsched'||'-'||strip(visitnum);
		end;
run;

/*finding start and end date from se*/
libname vm_1 "/home/u60094620/vm project";
libname xpt xport "/home/u60094620/vm project/vm_program/se.xpt";

proc copy inlib=xpt outlib=vm_1;
run;

data se1;
	set vm_1.se;

proc sort data=se1;
	by usubjid;
run;


proc transpose data=se1 out=se2 (drop=_name_) prefix=ST_;
	by usubjid;
	id etcd;
	var sestdtc;
	
run;

proc transpose data=se1 out=se3 (drop=_name_) prefix=EN_;
	by usubjid;
	id etcd;
	var seendtc;
run;

/* merging  vs and se for mapping  epoch*/

proc sort data=vs4;
	by usubjid;
run;

data vs5;
length epoch $11.;
	merge se2 se3 vs4;
	by usubjid;
	vsstdt=input(vsdtc,yymmdd10.);
	scrn=input(ST_SCRN, yymmdd10.);
	scrn_l=input(EN_SCRN, yymmdd10.);
	p1=input(ST_P1, yymmdd10.);
	p1_l=input(EN_P1, yymmdd10.);
	p2=input(ST_P2, yymmdd10.);
	p2_l=input(EN_P2, yymmdd10.);
	p3=input(ST_P3, yymmdd10.);
	p3_l=input(EN_P3, yymmdd10.);
	fu_l=input(EN_FU, yymmdd10.) ;
	fu=input(ST_FU, yymmdd10.);

	if scrn<=vsstdt and vsstdt< scrn_l then epoch='SCREENING';
	else if p1<=vsstdt and vsstdt<p1_l then epoch='INDUCTION';
	else if p2<=vsstdt and vsstdt<p2_l then epoch='TITRATION';
	else if p3<=vsstdt and vsstdt<=p3_l then epoch='MAINTENANCE';
	else if fu<vsstdt and vsstdt< fu_l then epoch='FOLLOW-UP';
run;

proc sort data=vs5;
	by usubjid vstestcd  vsdtc visitnum;
run;

/*mapping vsseq*/
data vs6;
	set vs5;
	by usubjid vstestcd vsdtc visitnum;

	if first.usubjid then
		vsseq=1;
	else
		vsseq+1;
run;


/*labelling*/
data final;
	attrib STUDYID LABEL="study identifier" length=$6. DOMAIN 
		LABEL="domain abbreviation" length=$2. USUBJID 
		LABEL="unique subject identifier" length=$16. VSSEQ LABEL="sequence nuber" 
		length=8. VSTESTCD LABEL="vital sign test short name" length=$6. VSTEST 
		LABEL="vital sign test name" length=$24. VSCAT 
		LABEL="category for vital sign" length=$23. VSORRES 
		LABEL="result or finding in original units" length=$5. VSORRESU 
		LABEL="original units" length=$11. VSSTRESN 
		LABEL="numeric result/finding in standard units" length=8. VSSTRESC 
		LABEL="character result/finding in standard units" length=$8. VSSTRESU 
		LABEL="standard units" length=$11. VSSTAT LABEL="completion status" 
		length=$8. VSBLFL LABEL="baseline flag" length=$1. VISITNUM 
		LABEL="visit number" length=8. VISIT LABEL="visit name" length=$14. EPOCH 
		LABEL="epoch" length=$11. VSDTC LABEL="date/time of measurement" length=$10. 
		VSDY LABEL="study day of vital sign" length=8.;
	set vs6;
	keep STUDYID  DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSCAT VSORRES VSORRESU 
		VSSTRESN VSSTRESC VSSTRESU VSSTAT VSBLFL VISITNUM VISIT EPOCH VSDTC VSDY;
run;

/*creating xpt*/
libname xpt xport "/home/u60094620/vm project/program/vs_f.xpt";

data xpt.vs_f;
	set final;

/*converting xpt in sasfile*/
libname sasfile "/home/u60094620/xpt_v";
libname xpt xport "/home/u60094620/vm project/program/vs_f.xpt";

proc copy inlib=xpt outlib=sasfile;
run;

libname xpt xport "/home/u60094620/xpt_v/vs.xpt" access=readonly;

proc copy inlib=xpt outlib=sasfile;
run;
/*validation of sas files*/
proc compare base=sasfile.vs_f compare=sasfile.vs;
run;
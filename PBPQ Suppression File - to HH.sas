data _null_;
	call symput ('_1yr1month','2020-10-10');
	call symput ('yesterday','2021-11-10');
	call symput ('HHsuppression', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\DECPBPQSuppression.txt');
run;
	
data pbpq;
** \\server-fs01\Marketing\Risk\PBPQ\PBPQmmm2017_Drop\PBmmmUpsell.csv';
	set WORK.PBPQ_RISK_PBDecUpsell_20211104;
run;					

proc format; /* define format for delq*/
	value cdfmt
	1 = 'Current'
	2 = '1-29cd'
	3 = '30-59cd'
	4 = '60-89cd'
	5 = '90-119cd'
	6 = '120-149cd'
	7 = '150-179cd'
	8 = '180+cd'
	other = ' '
;
run;

data atb; 
	SET dw.vw_AgedTrialBalance(
		KEEP = LoanNumber AGE2 BOM
		where = (BOM between "&_1yr1month" and "&yesterday")); 
	BRACCTNO = LoanNumber;
	YEARMONTH = BOM; 
	atbdt = input(substr(yearmonth, 6, 2) || '/' || 
				  substr(yearmonth, 9, 2) || '/' || 
				  substr(yearmonth, 1, 4), mmddyy10.);    
	*age is month number of loan where 1 is most recent month; 
	age = intck('month', atbdt, "&sysdate"d); 
	cd = substr(age2, 1, 1) * 1;   
	*** i.e. for age = 1: this is most recent month. Fill delq1,   ***;
	*** which is delq for month 1, with delq status (cd). Note     ***;
	*** that each loan is potentially in the file as many times    ***;
	*** are there are months. ------------------------------------ ***;
	if age = 1 then delq1 = cd;
	else if age = 2 then delq2 = cd;
	else if age = 3 then delq3 = cd;
	else if age = 4 then delq4 = cd;
	else if age = 5 then delq5 = cd;
	else if age = 6 then delq6 = cd;
	else if age = 7 then delq7 = cd;
	else if age = 8 then delq8 = cd;
	else if age = 9 then delq9 = cd;
	else if age =10 then delq10= cd;
	else if age =11 then delq11= cd;
	else if age =12 then delq12= cd;
	*** if cd is greater than 30-59 days late, set cd60 to 1 ----- ***;
	if cd > 3 then cd60 = 1; 
	*** if cd is greater than 1-29 days late, set cd30 to 1 ------ ***;
	if cd > 2 then cd30 = 1; 

	if age < 7 then do;
		/* note 30-59s in last six months */
		if cd = 3 then recent6 = 1;
	end;

	else if 6 < age < 13 then do;
		/*note 30-59s from 7 to 12 months ago */
		if cd = 3 then first6 = 1; 
	end;
	keep bracctno delq1-delq12 cd cd30 cd60 age2 atbdt age first6 
		 recent6;
run;

data atb2;
	set atb;
	*** count the number of 30-59s in the last year -------------- ***;
	last12 = sum(recent6, first6); 
run;

*** count cd30, cd60,recent6,first6 by bracctno (*recall loan      ***; 
*** potentially counted for each month) -------------------------- ***;
proc summary 
	data = atb2 nway missing;
	class bracctno;
	var delq1-delq12 recent6 last12 first6 cd60 cd30;
	output out = atb3(drop = _type_ _freq_) sum = ;
run;
 
data atb4; *create new counter variables;
   set atb3;
   if cd60 > 0 then ever60 = 'Y'; else ever60 = 'N';
   times30 = cd30;
   if times30 = . then times30 = 0;
   if recent6 = null then recent6=0;
   if first6 = null then first6=0;
   if last12 = null then last12=0;
   drop cd30;
   format delq1-delq12 cdfmt.;
run;

proc sort 
	data = atb4 nodupkey; 
	by bracctno; 
run; *sort to merge;

data dlq; 
	set atb4; 
	drop null; *dropping the null column (not nulls in dataset); 
run;

proc sort 
	data = pbpq; 
	by BrAcctNo; 
run;

data x; *merge pull and dql information;
	merge pbpq(in = x) dlq(in = y);
	by bracctno;
	if x = 1;
run;

data x2; *For HH Suppression;
	set x(
		keep = bracctno delq1);
	if delq1 = "" | delq1 = 1 then DLQDrop = "Keep";
	else DLQDrop = "Drop";
run;

data pullnetbal;
	set dw.vw_AgedTrialBalance(
		keep = LoanNumber NetBalance BOM);
	rename LoanNumber = bracctno
		   NetBalance = netbal
		   BOM = yearmonth;
run;

proc sort 
	data = pullnetbal;
	by BrAcctNo descending yearmonth;
run;

data pullnetbal2;
	set pullnetbal;
	by BrAcctNo descending yearmonth;
	if first.bracctno 
		then output pullnetbal2;
run;

proc sort 
	data = pullnetbal2 nodupkey; 
	by bracctno; 
run;

proc sort 
	data = x2; 
	by bracctno; 
run;

data x3;
	merge x2(in = x) pullnetbal2;
	by bracctno;
	if x;
	keep bracctno dlqdrop netbal yearmonth;
run;

data x4; 
	set x3; 
	drop yearmonth; 
run;

proc sort 
	data = x4 nodupkey; 
	by bracctno; 
run;

ods excel; 

proc contents 
	data = x4; 
run; 

ods excel close;

proc export 
	data = x4 outfile = "&HHsuppression" dbms = tab;
run;

proc tabulate 
	data = x4;
	class DLQDrop;
	tables DLQDrop;
run;

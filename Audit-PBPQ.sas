*** bring branchnumber in as string ------------------------------ ***;
data _null_;
	call symput("outfilex",
		"\\mktg-app01\E\Production\Audits\PBPQ AUDIT - 9.0 - Final Mail File.xlsx");
	call symput("filename",
		"WORK.'118649A_RMC_PBPQ9.0_18_FINA_0000'n");
run;

data code_standard;
	input offercode $ EQXcode;
	datalines;
A 1
B 2
C 3
D 4
E 5
F 6
B 7
C 8
D 9
E 10
F 11
;
RUN;

data state_offer_standard;
	input state $ OfferA OfferB OfferC OfferD OfferE OfferF;
	datalines;
SC 7000 6500 4000 3000 2000 1500
NC 7000 6500 4000 3000 2000 1500
TN 7000 6500 4000 3000 2000 1500
AL 6000 5000 4000 3000 2000 1500
OK 7000 6500 4000 3000 1466 1000
NM 7000 6500 4000 3000 2000 1500
TX 7000 6500 4000 3000 2600 1400
VA 7000 6500 4000 3000 2000 1500
GA 7000 6500 4000 3100 0 0
;
RUN;

data bni_standard;
	input Segment BNIRange $;
	datalines;
1 260-600
2 240-600
3 220-600
4 200-600
5 180-600
6 180-600
7 240-600
8 220-600
9 200-600
10 180-600
11 180-600
;
run;

data audit;
	set &filename;
	segment = equ_segment_number;
	Fico = equ_field41;
	Vantage = equ_field40;
	BNI4_0 = equ_field3;

	if rmc_dob = "" then Missing_DOB = 1;
	else missing_dob = 0;

	if rmc_dob ne "" then Populated_DOB = 1;
	else populated_dob = 0;

	OfferAmount = offer_amount;
run;

data ntb;
	set &filename; 
	segment = equ_segment_number;
	NTB_Check = 1.1 * xno_tduepoff;

	if offer_amount < ntb_check then AuditFlag = "Drop";
	else auditflag = "Keep";

	ntb_flag = strip(ntb_flag);

	if auditflag eq ntb_flag then NTBCalc = "Correct";
	else ntbcalc = "Incorrect";
run;

title;
ods excel file = "&outfilex" options(sheet_name = "Attribute Scores" 
									 sheet_interval = "none");

*** Check FICO Range, Vantage Score, and BNI 4.0 ----------------- ***;
proc means 
	data = audit min max maxdec = 0;
	var fico Vantage bni4_0;
run;

proc tabulate 
	data = audit;
	class segment;
	var bni4_0;
	tables segment, bni4_0 * min * f = 10.0 
					bni4_0 * max * f = 10.0;
run;

proc print 
	data = bni_standard;
run;

ods excel options(sheet_interval = 'table');                         
ods select none; 

data _null_; 
	dcl odsout obj(); 
run; 

ods select all;
ods excel options(sheet_name = "Campaign Mailing Info" 
				  sheet_interval = "none" );

*** Check that customer state and branch state match. ------------ ***;
proc tabulate 
	data = audit;
	class state BranchState;
	tables state,branchstate;
run;

*** Only our 9 states are present -------------------------------- ***;
proc freq 
	data = audit;
	tables state / nocum nopercent;
run;

*** Check  drop date and expiration date ------------------------- ***;
proc freq 
	data = audit;
	tables Drop_Date Closed_Date / nopercent nocum;
run;

*** Check Date of Birth ------------------------------------------ ***;
proc freq 
	data = audit;
	tables missing_dob Populated_DOB / nocum nopercent;
run;

ods excel options(sheet_interval = 'table');                         
ods select none; 

data _null_; 
	dcl odsout obj(); 
run; 

ods select all;
ods excel options(sheet_name = "Offer Info" sheet_interval = "none" );

*** No small loans in GA ----------------------------------------- ***;
proc tabulate data=audit;
	class Offer_Amount state;
	tables state, Offer_Amount;
run;

*** Check offer amount by offer code ----------------------------- ***;
proc tabulate 
	data = audit;
	class offer_code Offer_Amount;
	tables offer_code, Offer_Amount;
run;

PROC PRINT 
	data = state_offer_standard;
run;

*** Check segment by credit score -------------------------------- ***;
proc means 
	data = audit min max maxdec = 0;
	class EQU_Segment_Number;
	var fico;
run;

*** Check offer code by segment ---------------------------------- ***;
proc tabulate 
	data = audit;
	class offer_code EQU_Segment_Number;
	tables EQU_Segment_Number, offer_code;
run;

proc print 
	data = code_standard;
run;

*** Check for NTB Errors ----------------------------------------- ***;
proc tabulate 
	data = ntb;
	class ntb_flag AuditFlag NTBCalc;
	tables ntb_flag AuditFlag NTBCalc;
run;

ods excel options(sheet_interval = 'table');                         
ods select none; 

data _null_; 
	dcl odsout obj(); 
run; 

ods select all;
ods excel options(sheet_name = "Branch Info" sheet_interval = "none" );

*** Check Branch Info -------------------------------------------- ***;
data audit2;
	set audit;
	keep  BranchNumber 
		  BranchStreetAddress 
		  BranchCity 
		  BranchState 
		  BranchZip 
		  BranchPhone;
run;

proc sort 
	data = audit2 nodupkey;
	by BranchNumber 
	   BranchStreetAddress 
	   BranchCity 
	   BranchState 
	   BranchZip 
	   BranchPhone;
run;

data branchinfo;
	set rmcath.branchinfo;
	branchnumber = branchnumber_txt;
run;

proc sort 
	data = branchinfo;
	by branchnumber;
run;

data branchInfo_Check;
	merge branchinfo audit2(in = x);
	by branchnumber;
	if x;
run;

data branchinfo_check2;
	set branchinfo_check;
	if Branchstreetaddress ne StreetAddress then Br_Info_Mismatch = 1;
	if Branchcity ne city then Br_Info_Mismatch = 1;
	if branchstate ne state then br_info_mismath = 1;
	if branchzip ne zip_full then br_info_mismatch = 1;
	if branchphone ne phone then br_info_mismatch = 1;
	if br_info_mismatch = 1;
	drop BranchNumber_txt;
	rename BranchNumber_number=Branch;
run;

proc print 
	data = branchinfo_check2 noobs;
run;

ods excel close;


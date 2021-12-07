*** Change dates in the lines immediately below along with file    ***;
*** paths. For the files paths, you will likely need to create a   ***;
*** new folder "PBPQ" in the appropriate month file. Do not change ***;
*** the argument to the left of the comma - only change what is to ***;
*** the right of the comma --------------------------------------- ***;

*** Change 3/6/2018 by Brad:  All 9 NLS States are now in the      ***;
*** toggle-States strings ---------------------------------------- ***;

*** Change 3/6/2018 by Brad:  data step atb3 (near rows 592-600):  ***;
*** to fix "unitialized variables":  replace code "null" with "."  ***;

OPTIONS MPRINT MLOGIC SYMBOLGEN; /* SET DEBUGGING OPTIONS */

%LET PULLDATE = %SYSFUNC(today(), yymmdd10.);
%PUT "&PULLDATE";

%LET _5YR_NUM = %EVAL(%SYSFUNC(inputn(&pulldate,yymmdd10.))-1825);
%LET _5YR = %SYSFUNC(putn(&_5YR_NUM,yymmdd10.));
%PUT "&_5YR";

%LET _13MO_NUM = %EVAL(%SYSFUNC(inputn(&pulldate,yymmdd10.))-395);
%LET _13MO = %SYSFUNC(putn(&_13MO_NUM,yymmdd10.));
%PUT "&_13MO";

%LET _2YR_NUM = %EVAL(%SYSFUNC(inputn(&pulldate,yymmdd10.))-730);
%LET _2YR = %SYSFUNC(putn(&_2YR_NUM,yymmdd10.));
%PUT "&_2YR";

%LET _1DAY_NUM = %EVAL(%SYSFUNC(inputn(&pulldate,yymmdd10.))-1);
%LET _1DAY = %SYSFUNC(putn(&_1DAY_NUM,yymmdd10.));
%PUT "&_1DAY";

data _null_;
	call symput ('PBPQ_ID', 'PBPQ12.1_2021');    
	*** current file --------------------------------------------- ***;
	call symput ('dnhfile', 
		'\\server-lcp\LiveCheckService\DNHCustomers\DNHFile-10-28-2021-06-28.xlsx'); 
	call symput ('finalexportflagged', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\PBPQ_flagged_20211104.txt');
	call symput ('finalexportdropped', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\PBPQ_finalPBPQ_20211104.txt');
	call symput ('riskfile', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\PBPQ_RISK_PBAugUpsell_20211104.csv');
	*** This is the file we send to Risk to audit ---------------- ***;
	call symput ('eqxfile', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\PBPQ_RISK_PBAugUpsell_SU_20211104.csv');  
	call symput ('HHsuppression', 
		'\\mktg-app01\E\Production\2021\12_December_2021\PBPQ\PBPQ_PBPQSuppression_20211104.txt');
run;

data loan1;
	set dw.vw_loan_NLS(
		keep = orgst purcd cifno bracctno id ownbr ownst SSNo1 ssno2
			   ssno1_rt7 LnAmt FinChg LoanType EntDate LoanDate ClassID
			   ClassTranslation XNO_TrueDueDate FirstPyDate SrCD pocd
			   POffDate plcd PlDate PlAmt BnkrptDate BnkrptChapter 
			   DatePaidLast APRate CrScore orgst NetLoanAmount CurBal
			   conprofile1);
	where cifno ne "" & 
		  pocd = "" & 
		  plcd = "" & 
		  BnkrptDate = "" & 
		  PlDate = "" & 
		  poffdate = "" & 
		  ClassTranslation not in ("Auto-I", "Auto-D") & 
		  ownst in ("AL", "GA", "MO", "NC", "NM", "OK", "SC", "TN", 
					"TX", "VA", "WI");
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	if cifno not =: "B";
run;

data BorrNLS;
	length firstname $20 middlename $20 lastname $30;
	set dw.vw_borrower(
		keep = rmc_updated phone cifno ssno ssno_rt7  FName LName Adr1
			   Adr2 City State zip BrNo age Confidential Solicit
			   CeaseandDesist CreditScore);
	where cifno not =: "B";
	FName = strip(fname);
	LName = strip(lname);
	Adr1 = strip(Adr1);
	Adr2 = strip(adr2);
	City = strip(city);
	State = strip(state);
	Zip = strip(zip);

	if find(fname, "JR") ge 1 then do;
		firstname = compress(fname, "JR");
		suffix = "JR";
	end;

	if find(fname, "SR") ge 1 then do;
		firstname = compress(fname, "SR");
		suffix = "SR";
	end;

	if suffix = "" then do;
		firstname = scan(fname, 1, 1);
		middlename = catx(" ", scan(fname, 2, " "), 
							   scan(fname, 3, " "), 
							   scan(fname, 4, " "));
	end;

	nwords = countw(fname, " ");

	if nwords > 2 & suffix ne "" then do;
		firstname = scan(fname, 1, " ");
		middlename = scan(fname, 2, " ");
	end;

	lastname = lname;
	drop fname lname nwords;
	if cifno ne "";
run;

*** Merge by Cifno ----------------------------------------------- ***;
proc sort 
	data = loan1; 
	by cifno; 
run;

data loan1ONEloan loan1mult;
	set loan1;
	by cifno;
	if first.cifno and last.cifno then output loan1ONEloan;
	else output loan1mult;
run;

proc sql;
	create table loan1oneloan as
	select *
	from loan1oneloan
	group by cifno
	having curbal = max(curbal);
quit;

proc sql;
	create table loan1mult2 as
	select *, 
		   count(cifno) as countcif
	from loan1mult
	group by cifno;
quit;

data loan1mult3; 
	set loan1mult2; 
	if countcif = 2; 
run;

proc sort 
	data = loan1mult3; 
	by cifno Classid; 
run;

data firstloan secondloan;
	set loan1mult3;
	by cifno classid;
	if first.cifno then output firstloan;
	else output secondloan;
run;

data firstloan; 
	set firstloan; 
	if classtranslation ne "Retail"; 
run;

data secondloan; 
	set secondloan; 
	if classtranslation ne "Retail" then _2personalDelete = "X"; 
run;

proc sort 
	data = firstloan; 
	by cifno; 
run;

proc sort 
	data = secondloan; 
	by cifno; 
run;

data multkeep;
	merge firstloan(in = x) secondloan;
	by cifno;
	if x;
run;

data multkeep2; 
	set multkeep; 
	if _2personalDelete ne "X"; 
run;

data loan2; 
	set loan1oneloan multkeep2; 
run;

proc sort 
	data = borrnls; 
	by cifno descending rmc_updated; 
run;

proc sort 
	data = borrnls out = borrnls2 nodupkey; 
	by cifno; 
run;

proc sort 
	data = loan2; 
	by cifno; 
run;

data loannls;
	merge loan2(in = x) borrnls2(in = y);
	by cifno;
	if x and y;
run;

*** Find NLS state loans not in dw.vw_loan_NLS ------------------- ***;
data loanextra;
	set dw.vw_loan(
		keep = purcd bracctno xno_availcredit xno_tduepoff id ownbr
			   ownst SSNo1 ssno2 ssno1_rt7 LnAmt FinChg LoanType
			   EntDate LoanDate ClassID ClassTranslation
			   XNO_TrueDueDate FirstPyDate SrCD pocd POffDate plcd
			   PlDate PlAmt BnkrptDate BnkrptChapter DatePaidLast
			   APRate CrScore orgst NetLoanAmount XNO_AvailCredit
			   XNO_TDuePOff CurBal conprofile1 orgst);
	where plcd = "" & 
		  pocd = "" & 
		  poffdate = "" & 
		  pldate = "" & 
		  bnkrptdate = "" & 
		  ownst in ("AL", "GA", "MO", "NC", "NM", "OK", "SC", "TN", 
					"TX", "VA", "WI") & 
		  ClassTranslation not in ("Auto-I", "Auto-D");
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	if ssno1 =: "99" then BadSSN = "X"; /* Flag bad ssns */
	if ssno1 =: "98" then BadSSN = "X";
run;

data loan1_2; 
	set loan1; 
	keep BrAcctNo; 
run;

proc sort 
	data = loan1_2; 
	by bracctno; 
run;

proc sort 
	data = loanextra; 
	by BrAcctNo; 
run;

data loanextra2;
	merge loanextra(in = x) loan1_2(in = y);
	by bracctno;
	if x and not y;
run;

*** if this dataset is null, remove it from the set statement in   ***;
*** set1 below --------------------------------------------------- ***;

data loanparadata;
	set dw.vw_loan(
		keep = orgst purcd bracctno xno_availcredit xno_tduepoff id
			   ownbr ownst SSNo1 ssno2 ssno1_rt7 LnAmt FinChg LoanType
			   EntDate LoanDate ClassID ClassTranslation
			   XNO_TrueDueDate FirstPyDate SrCD pocd POffDate plcd
			   PlDate PlAmt BnkrptDate BnkrptChapter DatePaidLast
			   APRate CrScore NetLoanAmount XNO_AvailCredit
			   XNO_TDuePOff CurBal conprofile1);
	where plcd = "" & 
		  pocd = "" & 
		  poffdate = "" & 
		  pldate = "" & 
		  bnkrptdate = "" & 
		  ownst not in ("AL", "GA", "MO", "NC", "NM", "OK", "SC", "TN", 
						"TX", "VA", "WI") & 
		  ClassTranslation not in ("Auto-I", "Auto-D");
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	if ssno1 =: "99" then BadSSN = "X"; /* Flag bad ssns */
	if ssno1 =: "98" then BadSSN = "X"; 
run;

data set1; 
	set loanparadata loanextra2; 
run;

data BorrParadata;
	length firstname $20 middlename $20 lastname $30;
	set dw.vw_borrower(
		keep = rmc_updated phone cifno ssno ssno_rt7  FName LName Adr1
			   Adr2 City State zip BrNo age Confidential Solicit
			   CeaseandDesist CreditScore);
	FName = strip(fname);
	LName = strip(lname);
	Adr1 = strip(Adr1);
	Adr2 = strip(adr2);
	City = strip(city);
	State = strip(state);
	Zip = strip(zip);

	if find(fname, "JR") ge 1 then do;
		firstname = compress(fname, "JR");
		suffix = "JR";
	end;

	if find(fname, "SR") ge 1 then do;
		firstname = compress(fname, "SR");
		suffix = "SR";
	end;

	if suffix = "" then do;
		firstname = scan(fname, 1, 1);
		middlename = catx(" ", scan(fname, 2, " "), 
							   scan(fname, 3, " "), 
							   scan(fname, 4, " "));
	end;

	nwords = countw(fname, " ");

	if nwords > 2 & suffix ne "" then do;
		firstname = scan(fname, 1, " ");
		middlename = scan(fname, 2, " ");
	end;

	ss7brstate = cats(ssno_rt7, substr(brno, 1, 2));
	lastname = lname;
	rename ssno_rt7 = ssno1_rt7 
		   ssno = ssno1;
	if ssno =: "99" then BadSSN = "X"; /* Flag bad ssns */
	if ssno =: "98" then BadSSN = "X"; 
	drop nwords fname lname;
run;

data goodssn_l badssn_l;
	set set1;
	if badssn = "X" then output badssn_l;
	else output goodssn_l;
run;

data goodssn_b badssn_b;
	set borrparadata;
	if badssn = "X" then output badssn_b;
	else output goodssn_b;
run;

*** Match Good ssn's --------------------------------------------- ***;
proc sort 
	data = goodssn_l; 
	by ssno1; 
run;

data loan2oneloan loan2mult;
	set goodssn_l;
	by ssno1;
	if first.ssno1 and last.ssno1 then output loan2oneloan;
	else output loan2mult;
run;

proc sql;
	create table loan2oneloan as
	select *
	from loan2oneloan
	group by ssno1
	having curbal = max(curbal);
quit;

proc sql;
	create table loan2mult2 as
	select *, 
		   count(ssno1) as countssn
	from loan2mult
	group by ssno1;
quit;

data loan2mult3; 
	set loan2mult2; 
	if countssn = 2; 
run;

proc sort 
	data = loan2mult3; 
	by ssno1 classid; 
run;

data firstloan2 secondloan2;
	set loan2mult3;
	by ssno1 classid;
	if first.ssno1 then output firstloan2;
	else output secondloan2;
run;

data firstloan2; 
	set firstloan2; 
	if classtranslation ne "Retail"; 
run;

data secondloan2; 
	set secondloan2; 
	if classtranslation ne "Retail" then _2personalDelete = "X"; 
run;

proc sort 
	data = firstloan2; 
	by ssno1; 
run;

proc sort 
	data = secondloan2; 
	by ssno1; 
run;

data multkeep3; 
	merge firstloan2(in = x) secondloan2;
	by ssno1;
	if x;
run;

data multkeep4; 
	set multkeep3; 
	if _2personaldelete ne "X"; 
run;

data loan3; 
	set loan2oneloan multkeep4; 
run;

proc sort 
	data = goodssn_b; 
	by ssno1 descending rmc_updated; 
run;

proc sort 
	data = goodssn_b nodupkey; 
	by ssno1; 
run;

proc sort 
	data = loan3 nodupkey; 
	by ssno1; 
run;

data mergedgoodssn;
	merge loan3(in = x) goodssn_b(in = y);
	by ssno1;
	if x and y;
run;

*** Match Bad ssn's ---------------------------------------------- ***;
proc sort 
	data = badssn_l; 
	by ss7brstate; 
run;

data loan3oneloan loan3mult;
	set badssn_l;
	by ss7brstate;
	if first.ss7brstate and last.ss7brstate then output loan3oneloan;
	else output loan3mult;
run;

proc sql;
	create table loan3oneloan as
	select *
	from loan3oneloan
	group by ss7brstate
	having curbal = max(curbal);
quit;

proc sql;
	create table loan3mult2 as
	select *, 
		   count(ss7brstate) as countss7br
	from loan3mult
	group by ss7brstate;
quit;

data loan3mult3; 
	set loan3mult2; 
	if countss7br = 2; 
run;

proc sort 
	data = loan3mult3; 
	by ss7brstate classid; 
run;

data firstloan3 secondloan3;
	set loan3mult3;
	by ss7brstate classid;
	if first.ss7brstate then output firstloan3;
	else output secondloan3;
run;

data firstloan3; 
	set firstloan3; 
	if classtranslation ne "Retail"; 
run;

data secondloan3; 
	set secondloan3; 
	if classtranslation ne "Retail" then _2personalDelete = "X"; 
run;

proc sort 
	data = firstloan3; 
	by ss7brstate; 
run;

proc sort 
	data = secondloan3; 
	by ss7brstate; 
run;

data multkeep5;
	merge firstloan3(in = x) secondloan3;
	by ss7brstate;
	if x;
run;

data multkeep6; 
	set multkeep5; 
	if _2personaldelete ne "X"; 
run;

data loan4; 
	set loan3oneloan multkeep6; 
run;

proc sort 
	data = badssn_b; 
	by ss7brstate descending rmc_updated; 
run;

proc sort 
	data = badssn_b nodupkey; 
	by ss7brstate; 
run;

proc sort 
	data = loan4 nodupkey; 
	by ss7brstate; 
run;

data mergedbadssn;
	merge loan4(in = x) badssn_b(in = y);
	by ss7brstate;
	if x and y;
run;

DATA ssns; 
	set mergedgoodssn mergedbadssn; 
run;

proc sort 
	data = ssns nodupkey; 
	by bracctno; 
run;

proc sort 
	data = loannls nodupkey; 
	by bracctno; 
run;

data paradata;
	merge loannls(in = x) ssns(in = y);
	by bracctno;
	if not x and y;
run;

data merged_l_b; 
	set loannls paradata; 
run; 

proc sort 
	data = merged_l_b out = merged_l_b2 nodupkey; 
	by bracctno; 
run;

*** Pull in information for statflags ---------------------------- ***;
data Statflags;
	set dw.vw_loan(
		keep = ownbr SSNo1_rt7 entDate StatFlags);
	where entdate > "&_5YR" & StatFlags ne "";
run;

proc sql; /* identifying bad statflags */
	create table statflags2 as
	select * from statflags where statflags contains "5" /* 120 day */
 	union
 	select * from statflags where statflags contains "6" /* 150 day */
 	union 
 	select * from statflags where statflags contains "7" /* 180 day */
	union
	/* Accelerated */
 	select * from statflags where statflags contains "A" 
 	union 
	/* Bankruptcy */
 	select * from statflags where statflags contains "B" 
 	union
	/* Confidential */
 	select * from statflags where statflags contains "C" 
 	union
 	select * from statflags where statflags contains "D" /* Debt Aid */
 	union
	/* Inactive Charge Off */
 	select * from statflags where statflags contains "I" 
 	union
 	select * from statflags where statflags contains "J" /* Judgment */
 	union 
 	select * from statflags where statflags contains "L" /* Legal */
  	union 
	/* Charge Off */
 	select * from statflags where statflags contains "P" 
  	union 
	/* Interest Reduction */
 	select * from statflags where statflags contains "R" 
	union 
	/* Repossession Redeemed */
 	select * from statflags where statflags contains "V" 
	union 
	/* Charge off balance waived */
 	select * from statflags where statflags contains "W" 
	union 
	/* Repossession */
 	select * from statflags where statflags contains "X" 
	union 
	/* Repossession Sold */
 	select * from statflags where statflags contains "S"; 
quit;

data statflags2; /* tagging bad statflags */
	set statflags2;
	statfl_flag = "X";
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop ownbr SSNo1_rt7 entDate;
run;

proc sort 
	data = statflags2 nodupkey; 
	by ss7brstate; 
run;

proc sort 
	data = merged_l_b2; 
	by ss7brstate; 
run;

data Merged_L_B2; /* Merge file with statflag flags */
	merge merged_l_b2(in = x) statflags2(in = y);
	by ss7brstate;
	if x = 1;
run;

data openloans2;
	set dw.vw_loan(
		keep = ownbr ssno2 ssno1_rt7 pocd plcd poffdate pldate
			   bnkrptdate classtranslation);
	where pocd = "" & 
		  plcd = "" & 
		  poffdate = "" & 
		  pldate = "" & 
		  bnkrptdate = "" & 
		  classtranslation in ("Auto-I", "Auto-D");
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
run;

data ssno2s;
	set openloans2;
	ss7brstate = cats((substr(ssno2, max(1, length(ssno2) - 6))), 
					   substr(ownbr, 1, 2));
	if ssno2 ne "" then output ssno2s;
run;

data openloans3; 
	set openloans2 ssno2s; 
run;

data openloans4;
	set openloans3;
	Open_flag2 = "X";
	if ss7brstate = "" then 
		ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop pocd ssno2 ssno1_rt7 OwnBr plcd poffdate pldate bnkrptdate
		 ClassTranslation;
run;

proc sort 
	data = openloans4 nodupkey; 
	by ss7brstate; 
run;

proc sort 
	data = merged_l_b2; 
	by ss7brstate; 
run;

data merged_l_b2;
	merge merged_l_b2(in = x) openloans4;
	by ss7brstate;
	if x;
run;

data bk2yrdrops;
	set dw.vw_loan(
		keep = ssno1_rt7 OwnBr bnkrptdate BnkrptChapter entdate);
	where EntDate > "&_5YR";
run;

data bk2yrdrops; 
	set bk2yrdrops; 
	where BnkrptChapter > 0 | bnkrptdate ne ""; 
run;

data bk2yrdrops;
	set bk2yrdrops;
	bk2_flag = "X";
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop BnkrptDate entdate ssno1_rt7 ownbr BnkrptChapter;
run;

proc sort 
	data = bk2yrdrops nodupkey; 
	by ss7brstate; 
run;

data Merged_L_B2;
	merge Merged_L_B2(in = x) bk2yrdrops;
	by ss7brstate;
	if x;
run;

data merged_l_b2;
	set merged_l_b2;
	if bnkrptdate ne "" then bk2_flag = "X";
	if bnkrptchapter ne 0 then bk2_flag = "X";
run;

*** Flag bad TRW status ------------------------------------------ ***;
data trwstatus_fl; /* find from 5 years back */
	set dw.vw_loan(
		keep = ownbr SSNo1_rt7 EntDate trwstatus);
	where entdate > "&_5YR" & 
		  TrwStatus ne ""; /* Values relate to fraud */
run;

data trwstatus_fl; /* flag for bad trw's */
	set trwstatus_fl;
	TRW_flag = "X";
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop ssno1_rt7 ownbr EntDate;
run;

proc sort 
	data = trwstatus_fl nodupkey; 
	by ss7brstate; 
run;

data Merged_L_B2; /* merge pull with trw flags */
	merge Merged_L_B2(in = x) trwstatus_fl;
	by ss7brstate;
	if x;
run;

*** Identify bad PO Codes ---------------------------------------- ***;
data PO_codes_5yr;
	set dw.vw_loan(
		keep = EntDate pocd ssno1_rt7 ownbr);
	where EntDate > "&_5YR" & 
		  pocd in ("49", "61", "62", "63", "64", "66", "68", "97");
run;

*** 49 = Bankruptcy, 61 = Voluntary Surrender,                     ***;
*** 62 = Pd Collection Acct, 63 = Pd Repo, 64 = Pd Charge off,     ***;
*** 66 = Repo Pd by Dealer, 68 = Pd less than balance,             ***;
*** 97 = Non-file pay off ---------------------------------------- ***;
data po_codes_5yr;
	set po_codes_5yr;
	BadPOcode_flag = "X";
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop entdate ssno1_rt7 ownbr pocd;
run;

proc sort 
	data = po_codes_5yr nodupkey; 
	by ss7brstate; 
run;

data merged_l_b2;
	merge merged_l_b2(in = x) po_codes_5yr;
	by ss7brstate;
	if x;
run;

data PO_codes_forever;
	set dw.vw_loan(
		keep = pocd ssno1_rt7 ownbr);
	where pocd in("21", "94", "95");
*** 21 = Deceased, 94 = Pd AH Insurance, 95 = Pd Life Insurance -- ***;
run;

data po_codes_forever;
	set po_codes_forever;
	Deceased_flag = "X";
	ss7brstate = cats(ssno1_rt7, substr(ownbr, 1, 2));
	drop pocd ssno1_rt7 ownbr;
run;

proc sort 
	data = po_codes_forever nodupkey; 
	by ss7brstate; 
run;

data merged_l_b2;
	merge merged_l_b2(in = x) po_codes_forever;
	by ss7brstate;
	if x;
run;

*** Bad Branch Flags --------------------------------------------- ***;
data merged_l_b2;
	set merged_l_b2;
	if ownbr in("1", "9000", "198", "498", "580", "600", "698", "898", 
				"0001", "9000", "0198", "0498", "0580", "0600", "0698", 
				"0898", "398", "0398") 
		then BadBranch_flag = "X";
	if substr(ownbr, 3, 2) = "99" then BadBranch_flag = "X";
	*** Flag incomplete info ------------------------------------- ***;
	if adr1 = "" then MissingInfo_flag = "X"; 
	*** Flag incomplete info ------------------------------------- ***;
	if state = "" then missinginfo_flag = "X";
	*** Flag incomplete info ------------------------------------- ***;
	if Firstname = "" then MissingInfo_flag = "X";
	*** Flag incomplete info ------------------------------------- ***;
	if Lastname = "" then MissingInfo_flag = "X";
	*** Find states outside of footprint ------------------------- ***;
	if state not in("AL", "GA", "MO", "NC", "NM", "OK", "SC", "TN", 
					"TX", "VA", "WI") then OOS_flag = "X"; 
	if confidential = "Y" then DNS_DNH_flag = "X"; /* Flag DNS DNH */
	if solicit = "N" then DNS_DNH_flag = "X"; /*Flag DNS DNH */
	if ceaseanddesist = "Y" then DNS_DNH_flag = "X"; /* Flag DNS DNH */
	*** Flag nonmatching branch state and borrower state --------- ***;
	if ownst ne state then State_Mismatch_flag = "X"; 
	if ssno1 = "" then ssno1 = ssno;
	*** identify Retail loans in NC and OK ----------------------- ***;
	if ownst in("NC", "OK") & classtranslation = "Retail" then 
		renewaldelete_flag = "X"; 
	if curbal < 20 then curbal_flag = "X";
	if ownbr = "1016" then ownbr = "1008";
	if ownbr = "1003" and zip =: "87112" then ownbr = "1013";
	if brno = "1016" then brno = "1008";
	if brno = "1003" and zip =: "87112" then brno = "1013";
	if purcd in ("020", "015", "016", "021", "022") 
		then dlqren_flag = "X";
	if ownbr = "0251" then ownbr = "0580";
	if ownbr = "0252" then ownbr = "0683";
	if ownbr = "0253" then ownbr = "0581";
	if ownbr = "0254" then ownbr = "0582";
	if ownbr = "0255" then ownbr = "0583";
	if ownbr = "0256" then ownbr = "1103";
	if zip =: "36264" & ownbr = "0877" then ownbr = "0870";
	if ownbr = "0877" then ownbr = "0806";
	if ownbr = "0159" then ownbr = "0132";
	if zip =: "29659" & ownbr = "0152" then ownbr = "0121";
	if ownbr = "0152" then ownbr = "0115";
	if ownbr = "0885" then ownbr = "0802";
	if ownbr = "0302" then ownbr = "0133";
	if brno = "0668" then brno = "0680";
	if ownbr = "0668" then ownbr = "0680";
	if ownbr = "1018" then ownbr = "1008";
	if brno = "1018" then brno = "1008";
	
	/*COVID*/
	*IF OWNST = "NM" THEN BADBRANCH_FLAG = "X";
	/*Tiger King Branches*/
	/*
	IF OWNBR = "0415" THEN offer_type = "Branch ITA";
	IF OWNBR = "0504" THEN offer_type = "Branch ITA";
	IF OWNBR = "0518" THEN offer_type = "Branch ITA";
	IF OWNBR = "0521" THEN offer_type = "Branch ITA";
	IF OWNBR = "0537" THEN offer_type = "Branch ITA";
	IF OWNBR = "0585" THEN offer_type = "Branch ITA";
	IF OWNBR = "0586" THEN offer_type = "Branch ITA";
	IF OWNBR = "0589" THEN offer_type = "Branch ITA";
	IF OWNBR = "0904" THEN offer_type = "Branch ITA";
	IF OWNBR = "0910" THEN offer_type = "Branch ITA";
	IF OWNBR = "0915" THEN offer_type = "Branch ITA";
	IF OWNBR = "0917" THEN offer_type = "Branch ITA";
	IF OWNBR = "0918" THEN offer_type = "Branch ITA";
	IF OWNBR = "0921" THEN offer_type = "Branch ITA";
	IF OWNBR = "0923" THEN offer_type = "Branch ITA";
	IF OWNBR = "1001" THEN offer_type = "Branch ITA";
	IF OWNBR = "1002" THEN offer_type = "Branch ITA";
	IF OWNBR = "1007" THEN offer_type = "Branch ITA";
	IF OWNBR = "1010" THEN offer_type = "Branch ITA";
	IF OWNBR = "1011" THEN offer_type = "Branch ITA";
	IF OWNBR = "1012" THEN offer_type = "Branch ITA";
	IF OWNBR = "1014" THEN offer_type = "Branch ITA";
	*/
run;

*** Ed's dnsdnh -------------------------------------------------- ***;
proc import 
	datafile = "&dnhfile" out = dns dbms = excel; 
	sheet="DNS";
run;

proc import 
	datafile = "&dnhfile" out = dnh dbms = excel; 
	sheet = "DNH";
run;

proc import 
	datafile = "&dnhfile" out = dnhc dbms = excel replace; 
	sheet = "DNH-C";
run;

data dnsdnh; 
	set dns dnh dnhc; 
	DNS_DNH_flag = "X"; 
	keep ssn dns_dnh_flag; 
run;

proc datasets; 
	modify dnsdnh; 
	rename ssn = ssno1; 
run;

proc sort 
	data = dnsdnh nodupkey; 
	by SSNo1; 
run;

proc sort 
	data = merged_l_b2; 
	by ssno1; 
run;

data merged; 
	merge merged_l_b2(in = x) dnsdnh; 
	by ssno1; 
	if x; 
run;

*** pull and merge dlq info for pb's ----------------------------- ***;
proc format; /* define format for delq */
	value cdfmt 1 = 'Current'
   				2 = '1-29cd'
   				3 = '30-59cd'
   				4 = '60-89cd'
   				5 = '90-119cd'
   				6 = '120-149cd'
   				7 = '150-179cd'
   				8 = '180+cd'
   				other = ' ';
run;
/*
data atb; 
	set dw.vw_AgedTrialBalance(
		keep = LoanNumber AGE2 BOM 
	where = (BOM between "&_13MO" and "&_1DAY"));
	BRACCTNO = LoanNumber;
	YEARMONTH = BOM;
	atbdt = input(substr(yearmonth, 6, 2) || '/' || 
				  substr(yearmonth, 9, 2) || '/' || 
				  substr(yearmonth, 1, 4), mmddyy10.);     
	*** age is month number of loan where 1 is most recent month - ***;
	age = intck('month', atbdt, "&sysdate"d); 
	cd = substr(age2, 1, 1) * 1;   
	*** i.e. for age=1: this is most recent month. Fill delq1,     ***;
	*** which is delq for month 1, with delq status (cd). -------- ***;
   	if age = 1 then delq1 = cd;
   	else if age = 2 then delq2 = cd;
   	else if age = 3 then delq3 = cd;
   	else if age = 4 then delq4 = cd;
   	else if age = 5 then delq5 = cd;
   	else if age = 6 then delq6 = cd;
   	else if age = 7 then delq7 = cd;
   	else if age = 8 then delq8 = cd;
   	else if age = 9 then delq9 = cd;
   	else if age = 10 then delq10 = cd;
   	else if age = 11 then delq11 = cd;
   	else if age = 12 then delq12 = cd;
	*** if cd is greater than 60-89 days late, set cd60 to 1 ----- ***;
   	if cd > 3 then cd60 = 1; 
	*** if cd is greater than 30-59 days late, set cd30 to 1 ----- ***;
   	if cd > 2 then cd30 = 1; 

	if age < 4 then do;
		*** note 30-59s in last six months ----------------------- ***;
		if cd > 2 then recent3 = 1; 
	end;

	else if 3 < age < 7 then do;
		*** note 30-59s from 7 to 12 months ago ------------------ ***;
		if cd > 2 then recent4to6 = 1; 
	end;

	if age < 7 then do;
		*** note 30-59s in last six months ----------------------- ***;
		if cd > 2 then recent6 = 1; 
		if cd > 3 then recent6_60 = 1;
	end;

	else if 6 < age < 13 then do;
		*** note 30-59s from 7 to 12 months ago ------------------ ***;
		if cd > 2 then first6 = 1; 
		if cd > 3 then first6_60 = 1;
	end;

	keep bracctno delq1-delq12 cd cd30 cd60 age2 atbdt age recent3
		 recent4to6 recent6_60 first6_60 first6 recent6;
run;
*/
**********************************************************************;
**********************************************************************;
**********************************************************************;

data atb; 
	set dw.vw_ATB_Data(
		keep = BRACCTNO AGE2 YEARMONTH 
	where = (YEARMONTH between "&_13MO" and "&_1DAY"));
	atbdt = input(substr(yearmonth, 6, 2) || '/' || 
				  substr(yearmonth, 9, 2) || '/' || 
				  substr(yearmonth, 1, 4), mmddyy10.);     
	*** age is month number of loan where 1 is most recent month - ***;
	age = intck('month', atbdt, "&sysdate"d); 
	cd = substr(age2, 1, 1) * 1;   
	*** i.e. for age=1: this is most recent month. Fill delq1,     ***;
	*** which is delq for month 1, with delq status (cd). -------- ***;
   	if age = 1 then delq1 = cd;
   	else if age = 2 then delq2 = cd;
   	else if age = 3 then delq3 = cd;
   	else if age = 4 then delq4 = cd;
   	else if age = 5 then delq5 = cd;
   	else if age = 6 then delq6 = cd;
   	else if age = 7 then delq7 = cd;
   	else if age = 8 then delq8 = cd;
   	else if age = 9 then delq9 = cd;
   	else if age = 10 then delq10 = cd;
   	else if age = 11 then delq11 = cd;
   	else if age = 12 then delq12 = cd;
	*** if cd is greater than 60-89 days late, set cd60 to 1 ----- ***;
   	if cd > 3 then cd60 = 1; 
	*** if cd is greater than 30-59 days late, set cd30 to 1 ----- ***;
   	if cd > 2 then cd30 = 1; 

	if age < 4 then do;
		*** note 30-59s in last six months ----------------------- ***;
		if cd > 2 then recent3 = 1; 
	end;

	else if 3 < age < 7 then do;
		*** note 30-59s from 7 to 12 months ago ------------------ ***;
		if cd > 2 then recent4to6 = 1; 
	end;

	if age < 7 then do;
		*** note 30-59s in last six months ----------------------- ***;
		if cd > 2 then recent6 = 1; 
		if cd > 3 then recent6_60 = 1;
	end;

	else if 6 < age < 13 then do;
		*** note 30-59s from 7 to 12 months ago ------------------ ***;
		if cd > 2 then first6 = 1; 
		if cd > 3 then first6_60 = 1;
	end;

	keep bracctno delq1-delq12 cd cd30 cd60 age2 atbdt age recent3
		 recent4to6 recent6_60 first6_60 first6 recent6;
run;
**********************************************************************;
**********************************************************************;
**********************************************************************;

data atb2;
	set atb;
	*** count the number of 30-59s in the last year -------------- ***;
	last12 = sum(recent6, first6); 
	last12_60 = sum(recent6_60, first6_60);
run;

*** count cd30, cd60, recent6, first6 by bracctno (*recall loan      ***;
*** potentially counted for each month) -------------------------- ***;
proc summary 
	data = atb2 nway missing;
   	class bracctno;
   	var delq1-delq12 recent6 last12 first6 recent6_60 last12_60
		first6_60 recent3 recent4to6 cd60 cd30;
   	output out = atb3(drop = _type_ _freq_) sum = ;
run; 

*** create new counter variables; * NEW THIS RUN:  replace "null"  ***;
*** with "." ----------------------------------------------------- ***;      
data atb4;
	set atb3;
   	times30 = cd30;
   	if times30 = . then times30 = 0;
   	if recent6 = . then recent6 = 0;
   	if first6 = . then first6 = 0;
   	if last12 = . then last12 = 0;
   	if recent6_60 = . then recent6_60 = 0;
   	if first6_60 = . then first6_60 = 0;
   	if last12_60 = . then last12_60 = 0;
   	if recent3 = . then recent3 = 0;
   	if recent4to6 = . then recent4to6 = 0;
   	drop cd30;
   	format delq1-delq12 cdfmt.;
run;

proc sort 
	data = atb4 nodupkey; 
	by bracctno; 
run; /* sort to merge */

data dlq; 
	set atb4; 
	drop null; /* dropping the null column (not nulls in dataset) */ 
run;

proc sort 
	data = merged_l_b2; /* sort to merge */ 
	by BrAcctNo; 
run;

data Merged_l_b2; /* merge pull and dql information */
	merge merged_l_b2(in = x) dlq(in = y);
	by bracctno;
	if x = 1;
run;

data merged_l_b2; /* flag for bad dlq */
	set merged_l_b2;
	if recent3 > 0 or 
	   recent4to6 > 1 or 
	   last12 > 2 or 
	   last12_60 > 1 or 
	   recent6_60 > 0 or 
	   first6_60 > 1 then DLQ_Flag = "X";
run;

*** Conprofile flags --------------------------------------------- ***;
data merged_l_b2;
	set merged_l_b2;
	con_recent3 = substr(conprofile1, 1, 3);
	con_recent4to6 = substr(conprofile1, 4, 3);
	con_recent6 = substr(conprofile1, 1, 6);
	_30_recent3 = countc(con_recent3, "1");
	_30_recent4to6 = countc(con_recent4to6, "1");
	_60_recent6 = countc(con_recent6, "2");
	_30 = countc(conprofile1, "1");
	_60 = countc(conprofile1, "2");
	_90 = countc(conprofile1, "3");
	_120a = countc(conprofile1, "4");
	_120b = countc(conprofile1, "5");
	_120c = countc(conprofile1, "6");
	_120d = countc(conprofile1, "7");
	_120e = countc(conprofile1, "8");
	_90plus = sum(_90, _120a, _120b, _120c, _120d, _120e);
	if _30 > 2 | 
	   _60 > 1 | 
	   _90plus > 0 | 
	   _60_recent6 > 0 | 
	   _30_recent3 > 0 | 
	   _30_recent4to6 > 1 then conprofile_flag = "X";
	_9s = countc(conprofile1, "9");
	if _9s > 10 then lessthan2_flag = "X";
	XNO_TrueDueDate2 = input(substr(XNO_TrueDueDate, 6, 2) || '/' || 
							 substr(XNO_TrueDueDate, 9, 2) || '/' || 
							 substr(XNO_TrueDueDate, 1, 4), mmddyy10.);
	FirstPyDate2 = input(substr(FirstPyDate, 6, 2) || '/' || 
						 substr(FirstPyDate, 9, 2) || '/' || 
						 substr(FirstPyDate, 1, 4), mmddyy10.);
	Pmt_days = XNO_TrueDueDate2 - FirstPyDate2;
	if pmt_days < 60 then lessthan2_flag = "X";
	if pmt_days = . & _9s < 10 then lessthan2_flag = "";
	*** pmt_days calculation wins over conprofile ---------------- ***;
	if pmt_days > 59 & _9s > 10 then lessthan2_flag = ""; 
run;

proc sort 
	data = merged_l_b2 out = deduped nodupkey; 
	by BrAcctNo; 
run;

proc export 
	data = deduped outfile = "&finalexportflagged" dbms = tab;
run;

data final; 
	set deduped; 
run;

*** count obs ---------------------------------------------------- ***;
proc sql; 
	create table count as 
	select count(*) as Count 
	from merged_l_b2; 
quit;

data final; 
	set final; 
	if BadBranch_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if MissingInfo_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if OOS_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if State_Mismatch_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if open_flag2 = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if renewaldelete_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if BadPOcode_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if deceased_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if lessthan2_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if dlq_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if conprofile_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if bk2_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if statfl_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if TRW_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if DNS_DNH_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if delq1 ne .; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if curbal_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

data final; 
	set final; 
	if dlqren_flag = ""; 
run;

proc sql; 
	insert into count 
	select count(*) as Count 
	from final; 
quit;

proc print 
	data = count noobs; 
run;

data final; 
	set final; 
	Campaign_ID = "&PBPQ_ID"; 
run;

proc export 
	data = final outfile = "&finalexportdropped" dbms = tab;
run;

data Waterfall;
	length Criteria $50 Count 8.;
 	infile datalines dlm = "," truncover;
 	input Criteria $ Count;
 	datalines;
Final Open Total,			
Delete customers in Bad Branches,	
Delete customers with Missing Info,	
Delete customers Outside of Footprint,	
Delete where State/OwnSt Mismatch,
Delete if customer has auto loan,
Delete NC and OK Retail,
Delete customers with a "bad" POCODE,
Delete if deceased,
Delete if Less than Two Payments Made,	
Delete for ATB Delinquency,	
Delete for Conprofile Delinquency,
Delete for Bankruptcy (5yr),
Delete for Statflag (5yr),
Delete for TRW Status (5yr),
Delete if DNS or DNH,
Delete if delq1 is empty,
Delete if CurBal <$50,
Delete DLQ Renewal,
;
run;

data final3;
	set final;
	N_payments = 12 - _9s;
	if conprofile1 = "" then N_payments = "";
	NLS_N_Payments = pmt_days / 30;
	if nls_n_payments > N_payments then N_payments = nls_n_payments;
	N_payments = round(n_payments);
	if "2010-01-01" <= entdate <= "2010-12-31" then EntYear = 2010;
	if "2011-01-01" <= entdate <= "2011-12-31" then EntYear = 2011;
	if "2012-01-01" <= entdate <= "2012-12-31" then EntYear = 2012;
	if "2013-01-01" <= entdate <= "2013-12-31" then EntYear = 2013;
	if "2014-01-01" <= entdate <= "2014-12-31" then EntYear = 2014;
	if "2015-01-01" <= entdate <= "2015-12-31" then EntYear = 2015;
	if "2016-01-01" <= entdate <= "2016-12-31" then EntYear = 2016;
	if "2017-01-01" <= entdate <= "2017-12-31" then EntYear = 2017;
	if "2018-01-01" <= entdate <= "2018-12-31" then EntYear = 2018;
	if "2019-01-01" <= entdate <= "2019-12-31" then EntYear = 2019;
	if "2020-01-01" <= entdate <= "2020-12-31" then EntYear = 2020;
	if "2021-01-01" <= entdate <= "2021-12-31" then EntYear = 2021;
run;

data check;
	set final3;
	if entyear = .;
run;

proc tabulate 
	data = final3 missing;
	class delq1 times30 recent6_60 _90plus DatePaidLast n_payments
		  ownst;
	tables ownst all, delq1 times30 recent6_60 _90plus;
run;

proc tabulate 
	data = final3 missing;
	class delq1 times30 recent6_60 _90plus EntYear DatePaidLast
		  n_payments ownst;
	tables Ownst all, EntYear;
run;

proc freq 
	data = final3;
	tables entyear / nopercent nocol norow;
run;

proc freq 
	data = final3;
	tables DatePaidLast / nopercent nocol norow;
run;

proc freq 
	data = final3;
	tables N_payments / nopercent nocol norow;
run;

data x; 
	set final; 
	if bk2_flag = "X"; 
run;

data risk; 
	set final; 
	conprofile = cats("Z", conprofile1); 
	rename ownbr = branch 
		   age = DOB; 
run;

proc export 
	data = risk outfile = "&riskfile" dbms = dlm;
	delimiter = ",";
run;

data risk2;
	set risk;
	a = strip(put(_30, 5.));
	b = strip(put(_60, 5.));
	c = strip(put(_90, 5.));
	d = strip(put(_90plus, 5.));
	e = strip(put(cd60, 5.));
	f = strip(put(classid, 10.));
	g = strip(put(crscore, 5.));
	h = strip(put(finchg, 15.));
	i = strip(put(first6, 5.));
	j = strip(put(id, 10.));
	k = strip(put(last12, 5.));
	l = strip(put(lnamt, 15.));
	m = strip(put(netloanamount, 15.));
	n = strip(put(recent6, 5.));
	o = strip(put(times30, 5.));
	drop _30 _60 _90 _90plus cd60 ClassID CrScore FinChg first6 id
		 last12 LnAmt NetLoanAmount recent6 times30;
	rename a = _30 
		   b = _60 
		   c = _90 
		   d = _90plus 
		   e = cd60 
		   f = ClassID 
		   g = CrScore 
		   h = FinChg 
		   i = first6 
		   j = id 
		   k = last12 
		   l = LnAmt 
		   m = NetLoanAmount 
		   n = recent6 
		   o = times30;
run;

data eqx;
	length id $20 bracctno $20 branch $5 classid $20 
		   classtranslation $20 ssno1 $20 ssno1_rt7 $20 orgst $5
		   ownst $5 srcd $5 loantype $20 entdate $20 lnamt $20
		   finchg $20 crscore $5 firstpydate $20 conprofile $20 
		   netloanamount $20 cifno $20 firstname $50 middlename $50 
		   lastname $50 adr1 $50 adr2 $50 city $50 state $5 zip $20 
		   dob $20 recent6 $5 last12 $5 first6 $5 cd60 $5 ever60 $5 
		   times30 $5 dlq_flag $5 _30 $5 _60 $5 _90 $5 
		   oplncurr_dlqflag $5 _90plus $5 campaign_id $50;
	set risk2;
	keep id bracctno branch classid classtranslation ssno1 ssno1_rt7 
		 orgst ownst srcd loantype entdate lnamt finchg crscore 
		 firstpydate conprofile netloanamount cifno firstname 
		 middlename lastname adr1 adr2 city state zip dob recent6 
		 last12 first6 cd60 ever60 times30 dlq_flag _30 _60 _90 
		 oplncurr_dlqflag _90plus campaign_id;
run;

proc sort 
	data = eqx out = checkdups nodupkey; 
	by bracctno; 
run;

proc export 
	data = eqx outfile = "&eqxfile" dbms = dlm;
	delimiter = ",";
run;

ods excel options(sheet_interval = "none");

proc contents 
	data = eqx;
run;

ods excel close;


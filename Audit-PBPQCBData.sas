*** Location: M:\2017 Programs\1) Direct Mail Programs\PBFB\PB FB\ ***;
*** FBX-PB 7 July\PB-PQ Files                                      ***;
*** File Name:                                                     ***;
*** 113479A_RMC_PBPQ7.0_17ITA_OFFER_ASSIGN_CUSTOMER_woPII          ***;
*** Have to open file, since it's password protected, copy         ***;
*** contents into file to trash after audit.                       ***;
*** Bring in all variables as a number EXCEPT: Offer_Amount and    ***;
*** Netbal as "Currency" and ntb_flag as "String"                  ***;
*** For confirmation: O\Risk\PBPQ\CriteriaPBPQ_June_2017 --------- ***;

data _null_;
	call symput("cbdata", "WORK.'31332201.m01.prod.NTB.audit.pbpq'n");
run;

title;

data attributes;
	length attribute $25;
	input attribute $ segment_forComparision $ low high;
	datalines;
TrMoSinceDateOp48Mo 1 5 99
TrMoSinceDateOp48Mo 2 4 99
TrMoSinceDateOp48Mo 3 4 99
TrMoSinceDateOp48Mo 4 3 99
TrMoSinceDateOp48Mo 5 2 99
TrMoSinceDateOp48Mo 6 1 99
TrMoSinceDateOp48Mo 7 4 99
TrMoSinceDateOp48Mo 8 4 99
TrMoSinceDateOp48Mo 9 3 99
TrMoSinceDateOp48Mo 10 2 99
TrMoSinceDateOp48Mo 11 2 99
PerFTrMoDateOp3Mo 1 0 3
PerFTrMoDateOp3Mo 2 0 3
PerFTrMoDateOp3Mo 3 0 2
PerFTrMoDateOp3Mo 4 0 2
PerFTrMoDateOp3Mo 5 0 2
PerFTrMoDateOp3Mo 6 0 3
PerFTrMoDateOp3Mo 7 0 2
PerFTrMoDateOp3Mo 8 0 2
PerFTrMoDateOp3Mo 9 0 2
PerFTrMoDateOp3Mo 10 0 2
PerFTrMoDateOp3Mo 11 0 3
WRatAutoTr12Mo 1 0 1
WRatAutoTr12Mo 2 0 1
WRatAutoTr12Mo 3 0 1
WRatAutoTr12Mo 4 0 1
WRatAutoTr12Mo 5 0 2
WRatAutoTr12Mo 6 0 2
WRatAutoTr12Mo 7 0 1
WRatAutoTr12Mo 8 0 1
WRatAutoTr12Mo 9 0 1
WRatAutoTr12Mo 10 0 2
WRatAutoTr12Mo 11 0 2
WRatMortgTr12Mo 1 0 1
WRatMortgTr12Mo 2 0 1
WRatMortgTr12Mo 3 0 1
WRatMortgTr12Mo 4 0 1
WRatMortgTr12Mo 5 0 2
WRatMortgTr12Mo 6 0 2
WRatMortgTr12Mo 7 0 1
WRatMortgTr12Mo 8 0 1
WRatMortgTr12Mo 9 0 1
WRatMortgTr12Mo 10 0 2
WRatMortgTr12Mo 11 0 2
WRateRetailTr12Mo All 0 2
WRateHEqTr12Mo All 0 2
DTIScore All 1 999
Vantage All 300 850
FICO 1 680 999
FICO 2 660 999
FICO 3 640 999
FICO 4 620 999
FICO 5 580 999
FICO 6 550 999
FICO 7 680 999
FICO 8 660 999
FICO 9 640 999
FICO 10 600 999
FICO 11 550 999
;
run;

proc sort 
	data = attributes;
	by segment_forComparision;
run;

data offeraudit;
	set &cbdata;
	if offer_amount > netbal + 100 then NTBcalc = "Keep";
	else ntbcalc = "Drop";
	rename equ_field8 = TrMoSinceDateOp48Mo 
		   equ_field25 = PerFTrMoDateOp3Mo 
		   equ_field31 = WRatAutoTr12Mo 
		   equ_field35 = WRatMortgTr12Mo 
		   equ_field37 = WRateRetailTr12Mo 
		   equ_field38 = WRateHEqTr12Mo 
		   equ_field39 = DTIScore 
		   equ_field40 = Vantage 
		   equ_field41 = FICO 
		   equ_field42 = DispInc;
run;

proc sort 
	data = offeraudit;
	by EQU_Segment_Number;
run;

ods pdf startpage = no columns = 2;

proc means 
	data = offeraudit min max maxdec = 0;
	var TrMoSinceDateOp48Mo 
		PerFTrMoDateOp3Mo 
		WRatMortgTr12Mo 
		WRateRetailTr12Mo 
		WRateHEqTr12Mo 
		DTIScore 
		Vantage 
		FICO 
		DispInc;
run;

proc means 
	data = offeraudit min max maxdec = 0;
	var TrMoSinceDateOp48Mo 
		WRatAutoTr12Mo 
		WRatMortgTr12Mo 
		FICO 
		PerFTrMoDateOp3Mo;
	by EQU_Segment_Number;
run;

proc tabulate 
	data = offeraudit;
	class ntbcalc 
		  ntb_flag;
	tables ntbcalc, ntb_flag;
run;

Proc print 
	data = attributes;
	by segment_forComparision;
run;

ods pdf close;


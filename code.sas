libname stocks "C:\Users\akalia3\Downloads";

proc contents data=stocks.annualreports varnum;
run;

proc freq data=stocks.annualreports;
table IndFinancialYearEnd;
run;

data work.AnnualReports;
set stocks.AnnualReports;
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
run;
proc freq data=work.annualreports;
table FiscalYear;
run;
data work.No2014;
set work.AnnualReports;
if FiscalYearDate<"01Jan2014"d;
run; 
proc freq data=work.no2014;
tables FiscalYear;
run;

proc freq data=No2014;
table sector*industry/list missing missprint;
run;
data Mycompanies;
set work.No2014;
if sector="Consumer Servic" and Industry="Other Consumer Servic";
run; 
proc freq data=mycompanies order=freq;
title "No of Annual Report Records by Name";
table name;
run;

proc freq data=mycompanies ;
title "Counts of Symbol by Name--Detect Duplicates";
table symbol*name/list missing missprint;
run;

proc sort nodupkey data=Mycompanies;
by name FiscalYear;
run;
proc freq data=mycompanies ;
title "Counts of Symbol by Name--Detect Duplicates";
table symbol*name/list missing missprint;
run;
title; 

data Mycompanies;
set Mycompanies;
NameCompressed=compress(Name, " #.(),;&-");
run;
proc freq data=mycompanies order=freq;
tables namecompressed/list out=CompanyCounts;
run; 

data WithBinaries;
set Mycompanies;
if namecompressed="DeVryEducationGroupInc" then DeVryEducationGroupInc=1;
                                     else DeVryEducationGroupInc=0;
if namecompressed="FranklinCoveyCompany" then FranklinCoveyCompany=1;
                                     else FranklinCoveyCompany=0;
if namecompressed="GKServicesInc" then GKServicesInc=1;
                                   else GKServicesInc=0;
if namecompressed="GPStrategiesCorporation" then GPStrategiesCorporation=1;
                                   else GPStrategiesCorporation=0;
run;     


proc freq data=WithBinaries order=freq;
tables Name*DeVryEducationGroupInc*FranklinCoveyCompany*GKServicesInc*GPStrategiesCorporation/list missing missprint;
run;

data ForAnova;
set WithBinaries;
if DeVryEducationGroupInc=1 or FranklinCoveyCompany=1 or GKServicesInc=1 or GPStrategiesCorporation=1;
run;

data ConvertMetric;
set ForAnova;
PriceSToInd=input(PriceSalesToIndustry,8.);
run;

proc means data=convertmetric;
class symbol;
var PriceStoInd;
run;

proc anova data=convertmetric;
class symbol;
model PriceStoInd=symbol;
means symbol/snk;
run;
quit;









proc sort nodupkey data=mycompanies;
by symbol;
run;

data work.optionsfile;
set stocks.optionsfile (rename=(underlying=Symbol));
if "01Mar2014"d<=expdate<="30Nov2014"d;
run;

proc sort data=optionsfile;
by symbol expdate strike;
run;

data myoptions;
merge mycompanies(in=OnCompanies keep=symbol)
      work.optionsfile(in=OnOptions)
      ;
by Symbol;
if OnCompanies and OnOptions;
run;      

proc freq data=myoptions;
table Symbol;
run;  



proc means data=myoptions;
class Symbol type;
var strike;
run;


proc summary data=myoptions nway;
class symbol type;
var strike;
output out=OptionStrikes mean=;
run;









data work.prices;
set stocks.pricesrevised;
year=year(date);
run;

proc means data=work.prices n nmiss min;
class year;
var date;
run;

proc summary data=work.prices nway;
class year;
var date;
output out=FirstTradingDayPerYear min=;
run;

proc print data=FirstTradingDayPerYear;
run; 

data MyFirstTradingDay;
set stocks.pricesrevised;
if date="03Jan2012"d;
run;
proc sort data=MyFirstTradingDay;
by tic;
run;

data MyPriceFirstTradingDay;

merge Mycompanies (in=OnCompanies keep=symbol)
      MyFirstTradingDay (in=onprices rename=(tic=symbol));
      
by Symbol;
if OnCompanies and onprices;
run;

data work.DivFile;
set stocks.DivFile;
where Date ge "01Jan2010"d; 
rename tic=Symbol;
run;

data MyDividends;
merge MyPriceFirstTradingDay (in=onprice)
		Divfile (in=ondiv);
by symbol;
if onprice and ondiv;
run;

proc summary data=MyDividends nway;
class symbol adjclose;
var DivAmount;
output out=Divsum sum=;
run;

data DivCalc;
format DivYield percent8.1;
set DivSum;
DivYield=DivAmount/Adjclose;
run;

proc print data=DivCalc;
run; 




data work.splits (drop=date rename=(splitdate=date));
set stocks.splits;
splitdate = input(date,YYMMDD10.);
format splitdate YYMMDD10.;
rename tic=Symbol;
run;

data Mysplits;
merge Mycompanies (in=oncompanies keep=symbol)
splits (in=onsplits);
by symbol;
if oncompanies and onsplits
and date ge "01Jan1988"d;
run;
 
proc summary data=Mysplits nway;
class symbol;
var split;
output out=Splitminmax (drop=_type_) min=splitmin max=splitmax;
run; 
proc print data=Splitminmax;
run; 



data Onepersymbolstart;
merge mycompanies (in=onbase keep=symbol)
		splitminmax (in=onsplits)
		divcalc (in=ondiv);
by symbol;
if onbase;
run;

proc freq data=myoptions;
table symbol /out=optionscount (drop=percent rename=(count=optionscount));
run;

proc transpose data=optionstrikes (drop=_type_ _freq_)
				out=optionstransposed prefix=strikeprice_;
by symbol;
id type;
var strike;
run;
 
proc print data=optionstransposed;
run;



data Onepersymbolround2;
merge mycompanies (in=onbase keep=symbol)
		splitminmax (in=onsplits rename=(_freq_=splitcount))
		divcalc (in=ondiv drop=_type_ _freq_ adjclose)
		optionscount (in=onoptions)
		optionstransposed (in=optionsprices drop=_NAME_)
;
by symbol;
if onbase;
run;
options label;

data onepersymbolnoblanks;
set Onepersymbolround2;
format strikeprice_C strikeprice_P 8.2;
array numbervars _numeric_;
do over numbervars;
if numbervars=. then numbervars=0;
end;
run;
proc print data=onepersymbolnoblanks;
run;


data onepersymbolnoblanks;
set Onepersymbolround2;
format strikeprice_C strikeprice_P 8.2;
array BlankToZero splitcount divyield divamount optionscount;
do over BlankToZero;
if BlankToZero=. then BlankToZero=0;
end;
run;
proc print data=onepersymbolnoblanks;
run;



data Mycompany;
set stocks.annualreports;
format InfoAvailDate YYMMDD10.;
where sector="Consumer Servic" and Industry="Other Consumer Servic";
fiscalyeardate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
run;

Proc sort data=Mycompany nodupkey;
by symbol Indfinancialyearend;
run;


data report2009;
set mycompany (keep=fiscalyear ebit bstotalcurrentliabilities bsltdebt bsminorintliab bsprefstockeq
						bscash bsnetfixedass bswc symbol infoavaildate bssharesoutcommon);
where fiscalyear=2009;
returnoncapital=ebit/(bsnetfixedass+bswc);
run;

proc rank data=report2009 out=report2009ROC descending;
var returnoncapital;
ranks rankroc;
run;


data GetPrices;
merge report2009roc (in=onbase)
		stocks.pricesrevised (in=onprices rename=(tic=symbol) keep=tic date close adjclose);
by symbol;
if onbase and date=InfoAvailDate;
run;

proc freq data=getprices;
tables symbol;
title "GetPrices";
run;
title;


data GetPrices2;
merge report2009roc (in=onbase)
		stocks.pricesrevised (in=onprices rename=(tic=symbol) keep=tic date close adjclose);
by symbol;
if onbase and InfoAvailDate<=date<=InfoAvailDate+5;
run;

proc freq data=getprices2;
tables symbol;
title "GetPrices2";
run;
title;

data getpricesfirst;
set getprices2;
by symbol date;
if first.symbol;
run;




data EarningsYield;
set getpricesfirst;
marketcap=close*bssharesoutcommon;
earningsYield=ebit/(marketcap+bstotalcurrentliabilities+bsltdebt+bsminorintliab+bsprefstockeq-bscash);
run;

proc rank data=EarningsYield out=EYandROCRank descending;
var earningsyield;
ranks rankEY;
run;

proc plot data=EYandROCRank;
plot RankEY*RankROC=''$symbol;
run;
quit;
 


data AvgRank;
set EYandrocrank;
Avgrank=(rankey+rankroc)/2;
run;



data Mycompaniesoneyearlater (keep=symbol fiscalyear infoavaildate);
set stocks.annualreports;
format InfoAvailDate YYMMDD10.;
where sector="Consumer Servic" and Industry="Other Consumer Servic";
fiscalyeardate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
if fiscalyear=2010;
run;

data Oneyearlaterwithprice;
merge Mycompaniesoneyearlater (in=oncompanies)
		stocks.pricesrevised (in=onprices rename=(tic=symbol adjclose=lateradjclose) keep=tic date close adjclose);
by symbol;
if InfoAvailDate-5<=date<=InfoAvailDate-1;
run;

data pricebeforenextreport;
set Oneyearlaterwithprice;
by symbol date;
if last.symbol;
run;




data evalbeforenextreport;
merge avgrank (in=onbase)
		pricebeforenextreport (in=onnext);
by symbol;
if onbase;
return=(lateradjclose-adjclose)/adjclose;
run;

proc plot data=evalbeforenextreport;
plot return*avgrank=''$symbol;
run;
quit;






data muchlaterprice (keep=tic adjclose rename=(tic=symbol adjclose=adjclose2014));
set stocks.pricesrevised;
if date="02Jan2014"d;
run;


data LaterReturn;
merge EvalBeforeNextReport (in=onbase)
	muchlaterprice (in=onlater)
;
by symbol;
if onbase;
return2014=(adjclose2014-adjclose)/adjclose;
run;

proc plot data=laterreturn;
plot return2014*avgrank=''$symbol;
run;
quit;

proc reg data=laterreturn;
model return2014=avgrank;
run;

proc reg data=laterreturn;
model return=avgrank;
run;
quit;
 

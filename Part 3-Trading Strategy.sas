/* Garrett Mills
   Deepak Punjabi
   Marshall Titch
   Deepak Tiwari
   
   MBA524-001 Quantitative Analysis Project
   5/7/2019
*/



/* Project Part 3
   In this program, we compare the Gross Profit plus Value (GPA+HML),
   Value plus Momentum (HML+UMB), and Passive Market Portfolio (MKTRF factor)
*/


**Define your paths;

%let data_path=/courses/d0f4cb55ba27fe300/Anomalies;
%let output_path=/home/ddpunjab0/sasuser.v94/FinalProject;

*Define Data library;
libname my "&data_path";
libname project "&output_path";


/*In the first section of part 3, we build our data sets for the 3
  trading strategies*/
 

data project.returns;
 set project.gross_profit;
 gpa_hml =  exret + hml + rf;
 hml_umd = hml + umd + rf;
 market_portfolio = mktrf + rf;
 if bin=99;
 if year(date) ne 2017;
 if year(date) ne 2018;
run;


****************************************************************************************
creating a simple summary stats table showing summary stats of return for all 3 strategies without class
****************************************************************************************;

proc means data=project.returns n mean median std min max p1 skew ;
var gpa_hml hml_umd market_portfolio;
output out=project.Summary ;
run;
***************************Transposing to make Part 3 easier********;

*note we added the rf to the excess returns in the data step;
proc transpose data=project.returns out=project.returns;
 by dateff;
 var market_portfolio gpa_hml hml_umd;
run;

data project.returns;
 set project.returns;
 rename _name_=bin col1=ret dateff=date;
run;
****************************************************************************************
creating a simple summary stats table showing summary stats of return for all 3 strategies with class
****************************************************************************************;

proc means data=project.returns n mean median std min max p1 skew ;
var ret;
class bin;
output out=project.Summary_class ;
run;
****************************************************************************************
prepration for making cumulative returns and cumulative performance of all 3 strategies on the same line graph 
****************************************************************************************;

proc sort data=project.returns;
by bin ;
run;

data project.portfolio_graph;
set project.returns;
by bin ;
*for graphing total returns, convert long short to return by adding back risk free rate;
*if bin=99 then ret=ret+rf;
if first.bin then cumret1=1;
if ret ne . then cumret1=cumret1*(1+ret);
else cumret1=cumret1;
cumret=cumret1-1;
retain cumret1;


format cumret1 dollar15.2 bin bin_format.; 
label cumret1="Value of Dollar Invested In Portfolio";

run;

****************************************************************************************
Instead of assuming $1 invested at beginning of time period, graph the hypothetical growth in value 
of a $10,000 portfolio invested at the beginning of the time period for each strategy. 
****************************************************************************************;

data project.portfolio_graph_100000;
set project.portfolio_graph;
cumret1=cumret1*100000;
run;

****************************************************************************************
*table showing the end of sample-period portfolio values for each of the strategies ;
****************************************************************************************;



data project.sampleperiodportfoliovaluesend(keep=date bin endsampleperiodportfoliovalue);
set project.portfolio_graph_100000;
by bin;
if last.bin then endsampleperiodportfoliovalue=cumret1;
if last.bin;
run;

Title;
proc print data=project.sampleperiodportfoliovaluesend noobs label;
label date = "Date"
      bin = "Strategy"
      
run;

****************************************************************************************
 cumulative performance of all 3 strategies on the same line graph 
****************************************************************************************;

proc sgplot data=project.portfolio_graph_100000;
*where bin in(1,&bins,99);

   title2 'Cumulative Performance (Returns)';
   footnote 'Log Scale. Note, Long/Short portfolios converted to Returns by adding back risk free rate';
   series x=date y=cumret1 / group=bin lineattrs=(thickness=2);
Xaxis type=time ;
Yaxis type=log logbase=10 logstyle=linear ; *log based scale;
     
run;
footnote;

proc sql;
 create table project.returns as
 select a.*, a.ret - b.rf as exret, b.smb, b.hml, b.umd, b.mktrf
 from project.returns as a, my.factors_monthly as b
 where a.date = b.dateff;
quit;

proc sort data=project.returns;
 by bin date;
run;



*Part 3: #3
*******************************************************;
*What about risk? Sharpe Ratio
*******************************************************;

proc means data=project.returns noprint;
by bin;
var exret ;
output out=project.mean_std mean= std= /autoname autolabel;
run; 
*!EXAMINE THE RETURNS AND STANDARD DEVIATION;

data project.sharpe;
set project.mean_std;

sharpe_ratio=exret_mean/exret_StdDev;
label 
exret_mean="Mean Excess Return"
exret_StdDev="Standard Deviation of Excess Returns"
sharpe_ratio="Sharpe Ratio"
;

format exret_mean exret_StdDev percentn10.2 sharpe_ratio 10.2;
drop _type_ _freq_;


run;

proc print noobs label;
title2 "Sharpe Ratio by bin";
run;






*Part 3: #4

*******************************************************;
*What about risk? Factor Model Adjustment
*******************************************************;

*CAPM regression;
proc reg data = project.returns outest = project.CAPM_out edf noprint tableout;
by bin;
model exret = mktrf;
quit;

*CAPM clean up regression output;
data project.CAPM_out;
set project.CAPM_out;
where  _TYPE_ in ('PARMS','T'); *just keep Coefficients (Parms) and T-statistics (T);

*rescale intercept to percentage but only the PARMS, not T (Cant use percentage format because it would change T-stat also);
IF _TYPE_ ='PARMS' THEN intercept=intercept*100;

label 
intercept="Alpha: CAPM"
mktrf="Market Beta: CAPM"
;

format intercept mktrf 10.2;

keep bin _type_ intercept mktrf;

rename
intercept=alpha_capm
mktrf=mktrf_capm
;
run;


*Fama French 3 Factor;
proc reg data = project.returns outest = project.FF3_out edf noprint tableout;
by bin;
model exret = mktrf smb hml;
quit;


*FAMA FRENCH ALPHA AND BETAS*;
data project.FF3_out;
set project.FF3_out;
where  _TYPE_ in ('PARMS','T');

*rescale intercept to percentage but only the PARMS, not T;
IF _TYPE_ ='PARMS' THEN intercept=intercept*100;

label 
intercept="Alpha: FF3"
mktrf="Market Beta: FF3"
smb="SMB Beta"
hml="HML Beta"
;

format intercept mktrf smb hml 10.2;

keep bin _type_ intercept mktrf smb hml;

rename 
intercept=alpha_ff3
mktrf=mktrf_ff3
;

run;

*MERGE TOGETHER FOR NICE TABLE;
data project.Nice_table ;
retain bin;
merge project.CAPM_out project.FF3_out;
by bin _type_;

format bin bin_format.;
run;

proc print;
title2 "Factor Regression Results";
run;




*part 5;
*******************************************************
Creating 1 table containing the annual returns for each strategy for the full sample period.
(32 rows, 4 columns: year, and each strategy’s annual return)
*******************************************************;

 
proc sort data= project.returns out=project.returns_part5_sorted;
by date;
run;

proc transpose data=project.returns_part5_sorted out=project.returns_part5monthly;
 by date ;
 var ret;
run;

data project.returns_part5monthly;
set project.returns_part5monthly (rename=(COL1=gpa_hml COL2=hml_umd COL3=market_portfolio ));
 
 run;






proc sql;
create table project.annualreturns as 

select distinct
       Year(date) as Year ,
       EXP(SUM(LOG(gpa_hml+1)))-1 as gpa_hml_ret,
       EXP(SUM(LOG(hml_umd+1)))-1 as hml_umd_ret,
       EXP(SUM(LOG(market_portfolio+1)))-1 as market_portfolio_ret


 from project.returns_part5monthly
 group by YEAR(date);
 
quit;

Data project.annualreturns(drop=percent);
set project.annualreturns;
*market_portfolio_ret=market_portfolio_ret*100;
format market_portfolio_ret percentn10.2;
*gpa_hml_ret=gpa_hml_ret*100;
format gpa_hml_ret percentn10.2;
*hml_umd_ret=hml_umd_ret*100;
format hml_umd_ret percentn10.2;
run;

Title "Annual Returns";
proc print data=project.annualreturns noobs;
run;

*******************************************************
creating a table containing only the 5 worst annual returns for each strategy 
and another table with only the 5 best annual returns and their associated rank for each strategy 
*******************************************************;


*creating top 5 returns for each stratergy;
proc sql outobs=5;
create table project.topmarket_portfolio_ret as 
select  market_portfolio_ret  from project.annualreturns  order by market_portfolio_ret desc;

quit;

proc sql outobs=5;
create table project.topgpa_hml_ret as 
select  gpa_hml_ret  from project.annualreturns  order by gpa_hml_ret desc;

quit;

proc sql outobs=5;
create table project.tophml_umd_ret as 
select  hml_umd_ret  from project.annualreturns  order by hml_umd_ret desc;

quit;




data project.top5returns;
   merge project.topmarket_portfolio_ret project.topgpa_hml_ret project.tophml_umd_ret;
run;

title "5 Best Returns";
proc print data=project.top5returns;
run;

*creating worst 5 returns for each stratergy;
proc sql outobs=5;
create table project.bottommarket_portfolio_ret as 
select  market_portfolio_ret  from project.annualreturns  order by market_portfolio_ret;

quit;

proc sql outobs=5;
create table project.bottomgpa_hml_ret as 
select  gpa_hml_ret  from project.annualreturns  order by gpa_hml_ret;

quit;

proc sql outobs=5;
create table project.bottomhml_umd_ret as 
select  hml_umd_ret  from project.annualreturns  order by hml_umd_ret;

quit;




data project.bottom5returns;
   merge project.bottommarket_portfolio_ret project.bottomgpa_hml_ret project.bottomhml_umd_ret;
run;

title "5 Worst Returns";
proc print data=project.bottom5returns;
run;

*************************************************************************
*Best and worst annual returns graphs
***********************************************************************;
proc transpose data=project.annualreturns out=annualreturnstranspos (rename=(col1=ret));
by year;
var gpa_hml_ret hml_umd_ret market_portfolio_ret;
run;

*best returns;
proc sort data=annualreturnstranspos out=best5;
by descending ret;
run;

data best5;
set best5 (obs=5);
Rank = _n_;
DataLabel = _name_ || year;
run;

title "Best 5 Annual Returns of Any Strategy";
footnote;
proc sgplot data=best5;
vbar Rank / response=ret datalabel=DataLabel;   
run;

*worst returns;
proc sort data=annualreturnstranspos out=worst5;
by ret;
run;

data worst5;
set worst5 (obs=5);
Rank = _n_;
DataLabel = _name_ || year;
run;

title "Worst 5 Annual Returns of Any Strategy";
footnote;
proc sgplot data=worst5;
vbar Rank / response=ret datalabel=DataLabel;   
run;


*************************************************************************
% of months with positive monthly returns and % of years with positive annual returns 
for each of the 3 strategies
***********************************************************************;

*creating annual indicators;

data project.annualindicator;
set project.annualreturns;
gpa_hml_ind=0;
hml_umd_ind=0;
market_portfolio_ind=0;
if gpa_hml_ret>0 then gpa_hml_ind=1;
if hml_umd_ret>0 then hml_umd_ind=1;
if market_portfolio_ret>0 then market_portfolio_ind=1;
run;

proc sql;
create table project.positiveannual as
select distinct (select  (count(*)/32) from project.annualindicator where gpa_hml_ind>0) as Value_plus_Gross_Profit,
(select  (count(*)/32) from project.annualindicator where hml_umd_ind>0) as Value_plus_Momentum,
(select  (count(*)/32) from project.annualindicator where market_portfolio_ind>0) as Market_Portfolio  from project.annualindicator;
run;

proc transpose data=project.positiveannual out=project.positiveannual;
run;


data project.positiveannual;
set project.positiveannual (rename=(_NAME_=Strategy COL1=percentofpositiveyears ));
 
 run;

data project.positiveannual;
set project.positiveannual;
format percentofpositiveyears percentn10.2;
run;

*creating monthly indicators;


data project.monthlyindicator;
set project.returns_part5monthly;
gpa_hml_ind=0;
hml_umd_ind=0;
market_portfolio_ind=0;
if gpa_hml>0 then gpa_hml_ind=1;
if hml_umd>0 then hml_umd_ind=1;
if market_portfolio>0 then market_portfolio_ind=1;
run;

proc sql;
create table project.positivemonthly as
select distinct (select  (count(*)/378) from project.monthlyindicator where gpa_hml_ind>0) as Value_plus_Gross_Profit,
(select  (count(*)/378) from project.monthlyindicator where hml_umd_ind>0) as Value_plus_Momentum,
(select  (count(*)/378) from project.monthlyindicator where market_portfolio_ind>0) as Market_Portfolio  from project.annualindicator;
run;

proc transpose data=project.positivemonthly out=project.positivemonthly;
run;


data project.positivemonthly;
set project.positivemonthly (rename=(_NAME_=Strategy COL1=percentofpositivemonths ));
 
 run;

data project.positivemonthly;
set project.positivemonthly;
format percentofpositivemonths percentn10.2;
run;


*Create a table showing the % of months with positive monthly returns and % of years with positive
 annual returns for each of the 3 strategies;

proc sql;
create table positiveyearmonth as
select a.*, b.percentofpositivemonths from project.positiveannual a join project.positivemonthly b 
on a.Strategy=b.Strategy;
quit;


Title;
proc print data=positiveyearmonth noobs label;
label percentofpositiveyears = "% of Positive Years"
      percentofpositivemonths = "% of Positive Months"
      Strategy = "Strategy";
run;



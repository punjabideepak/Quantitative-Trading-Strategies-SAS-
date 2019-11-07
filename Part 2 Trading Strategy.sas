/* Garrett Mills
   Deepak Punjabi
   Marshall Titch
   Deepak Tiwari
   
   MBA524-001 Quantitative Analysis Project
   5/7/2019
*/



/* Project Part 2
   In this section, we reconfigure the Value.sas program
   to test for the gross profit anomaly instead of the value
   anamoly
*/



*******************************************************;
**Libraries and Paths;
*******************************************************;
**Define your paths;

%let data_path=/courses/d0f4cb55ba27fe300/Anomalies;
%let program_path=/courses/d0f4cb55ba27fe300/Anomalies/programs;
%let output_path=/home/Quantitative Analysis Project;

*Define Data library;
libname my "&data_path";



*******************************************************;
*Get Stock Data Ready
*******************************************************;



*Make temporary version of full stock universe and create any extra variables you want to add to the mix;
data stock;
set my.crspm_small;
by permno;


*Create/change any variables
***********************************************************************;
*fix price variable because it is sometimes negative to reflect average of bid-ask spread;
price=abs(prc);
*get beginning of period price;
lag_price=lag(price);
if first.permno then lag_price=.;
************************************************************************;


if LME=. then delete; *require all stocks to have beginning of period market equity.;
if primary_security=1; *pick only the primary security as of that date (only applies to multiple share class stocks);


keep date permno ME ret LME lag_price;
*remove return label to make programming easier;
label ret=' ';

run;





/*Our anomaly is defined to be Gross Profit / Total Assets where 
 Gross Profit is Total Revenue - Cost of Goods Sold */


*Get Compustat Data ready; 
data account;
set my.comp_big;

*data is already sorted on WRDS so we can use by groups right away;
  by gvkey datadate;


*Calculate Gross Profit. revt=Total Revenue and cogs=Cost of Goods Sold;
  GrossProfit = revt - cogs;

*Calculate Total Assets;
  TotalAssets = at;
  
*Calculate ratio;
 if TotalAssets NE . and TotalAssets NE 0 then anomaly = GrossProfit/TotalAssets;
 else anomaly = .;


 
label 
anomaly="Gross Profits / Total Assets";


*require the stock to have a PERMNO (a match to CRSP);
if permno=. then delete;
*only keep the variables we need for later;
keep datadate permno anomaly ;

run;




*Merge stock returns data from CRSP with Gross Profits / Assets accounting data from Compustat.
For each month t in the stock returns set, merge with the latest fiscal year end that is also at least 6 months old so we can 
assume you would have access to the accounting data. Remember that firms report accounting data with a lag, annual data in year t
won't be reported until annual reports come out in April of t+1. This sorts by datadate_dist so that closest dates come first;

proc sql;
create table formation as
select a.*, b.* , intck('month',b.datadate,a.date) as datadate_dist "Months from last datadate"

from stock a, account b
where a.permno=b.permno and 6 <= intck('month',b.datadate,a.date) <=18
order by a.permno,date,datadate_dist;
quit;

*select the closest accounting observation for each permno and date combo;
data formation;
set formation;
by permno date;
if first.date;
run;


*Get SIC industry code from header file in order to
remove stocks that are classified as financials because they have weird ratios (avoid sic between 6000-6999);
proc sql;
create table formation as
select a.*, b.siccd
from formation a ,my.msenames b
where a.permno=b.permno and (b.NAMEDT <= a.date <=b.NAMEENDT)
and not (6000<= b.siccd <=6999);
quit;


*Define a Master Title that will correspond to Anomaly definition throughout output;
title1 "Gross Profits / Assets";
*Start Output file;
ods pdf file="&output_path/Gross Profits Assets to Ratio.pdf"; 


*Define the variable you want to sort on and define your subsample criteria
For instance, you may only want to form portfolios every July (once a year), so we would just keep 
those stocks to form our portfolios. If we build them every month we wouldn't need the restriction;

data formation;
set formation;
by permno date;

***********************************************************************;
*Define the stock characteristics you want to sort on (SORTVAR);
***********************************************************************;
SORTVAR=anomaly; *Book to Market Ratio;
format SORTVAR 10.3;
label SORTVAR="Sort Variable: Gross Profits to Assets Ratio";

***********************************************************************;
*Define Rebalance Frequency;
***********************************************************************;
if month(date)=7; *Rebalance Annually in July;

***********************************************************************;
*Define subsample criteria
***********************************************************************;
if SORTVAR = . then delete; *must have non missing SORTVAR;
if (year(date)>1985 and year(date)<=2017) or (year(date)=1985 and month(date)>=7); *Select Time period;
if lme>1; *market cap of at least 1 million to start from;
if lag_price<1 or lag_price=. then delete; *Remove penny stocks or stocks missing price;

***********************************************************************;
*Define portfolio_weighting technique;
***********************************************************************;
portfolio_weight=LME; *Portfolio weights: set=1 for equal weight, or set =LME for value weighted portfolio;

run;




*******************************************************;
*Define holding period, bin Order and Format
*******************************************************;
*Define Holding Period (number of months in between rebalancing dates (i.e., 1 year = 12 months);
%let holding_period = 12;

*Define number of bins;
%let bins=5;

*Define the bin ordering:;
*%let rankorder= ; 
%let rankorder=descending;

*What stocks are you going long vs. what are you going Short?
leave blank for ascending rank (bin 1 is smallest value), set to descending 
if you want bin 1 to have largest value;

*Define a bin format for what the bin portfolios will correspond to for output;
proc format;
value bin_format 1="1. High Gross Profits to Assets"
10="10. Low Gross Profits to Assets"
99="Long/Short: High - Low"
;
run;




**********************************************************Forming Portfolios and Testing Begins Here**************************************;
%include "&program_path/Subroutine_ Form Portfolios and Test Anomaly.sas";

ods pdf close;
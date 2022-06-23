global data_dropbox "/Users/nicholasmark/Dropbox/police_absences/data"
global figures "/Users/nicholasmark/Dropbox/police_absences/figures"
global tables "/Users/nicholasmark/Dropbox/police_absences/tables"


clear all
set emptycells drop
set maxvar 32767
set matsize 11000
set scheme cleanplots
***********************************
*Descriptive Stats
***********************************

use "$data_dropbox/fullsample_12-2-21", clear
merge m:1 newid schoolyear using  "/Users/nicholasmark/Dropbox/police_absences/data/matchgroup_12-7-21.dta", gen(mergematch)

global table1 "female ever_ell ever_gifted ever_iep Any Unexcused Suspended Court Medical" 
					

g black = (racehisp ==1) 
g white = (racehisp ==0) 
g otherrace = (racehisp != 0 & racehisp !=1) 
g ms = (hs ==0)
g nofelony = (felony ==0)
replace nofelony = . if felony ==. 
g otherpolice = (schoolpolice ==0)
replace otherpolice = . if schoolpolice ==. 

**Graphing trends in absences for the appendix
preserve
gcollapse Any Unexcused Suspended Court Medical schoolyear, by(date analytic)
replace analytic = 0 if analytic ==.
label define analytic 0 "Not in Analyic Sample" 1 "In Analytic Sample"
label values analytic analytic
replace date = date-20695 if schoolyear ==2017
replace date = date-20331 if schoolyear ==2016
twoway (lfit Any date, by(analytic, note(""))) ///
(lfit Unexcused date, by(analytic, note(""))) ///
(lfit Suspended date, by(analytic, note(""))) ///
(lfit Court date, by(analytic, note(""))) ///
(lfit Medical date, by(analytic, note(""))), ///
xtitle(Day of School Year) ytitle(Absence Rate) ///
legend(order(1 "Any" 2 "Unexcused" 3 "Suspended" 4 "Court" 5 "Medical") title(Type of Absence, pos(11) size(medsmall)) r(1))
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/absence_trends.pdf", replace
restore




preserve
*collapse to the student-year level:
gcollapse $table1 analytic black white otherrace ever_schoolpolice  hs ms ever_felony felony nofelony schoolpolice otherpolice arrested ever_arrested prevarrest* summerpre* match1_1, by(newid schoolyear)

*create max var for the variables indicating "ever" 
foreach i in schoolpolice felony {
egen max_`i' = rmax(ever_`i' prevarrest_`i' summerpre_`i')
bys newid: egen true_ever_`i' = max(max_`i')
drop max_`i'
}

egen max_arrested = rmax(ever_arrested prevarrest summerpre)
bys newid: egen true_ever_arrested = max(max_arrested)
drop max_arrested

*now create never var thats the inverse
foreach i in schoolpolice felony {
g never_`i' = (true_ever_`i' ==0)
replace never_`i' = . if true_ever_`i' ==.
}

foreach i in felony nofelony schoolpolice otherpolice {
replace `i' = 1 if `i' !=. & `i' >0
}

foreach i in true_ever_arrested true_ever_schoolpolice true_ever_felony felony nofelony schoolpolice otherpolice black white otherrace hs ms never_schoolpolice never_felony $table1 {
replace `i' = `i' * 100 
}

estpost summarize  black white otherrace hs ms $table1 true_ever_arrested felony nofelony schoolpolice otherpolice if schoolyear == 2016
est sto all2016
estpost summarize  black white otherrace hs ms $table1 true_ever_arrested felony nofelony schoolpolice otherpolice if schoolyear == 2017
est sto all2017


*now collapse again to have data at the student level
*this way we can get any arrests
bys newid: egen max_analytic = max(analytic)
drop if max_analytic ==1
tab analytic

gcollapse $table1  black white otherrace true_ever_schoolpolice hs ms true_ever_felony never* true_ever_arrested prevarrest analytic, by(newid)


estpost summarize  black white otherrace hs ms $table1 true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if true_ever_arrested ==100 & analytic !=1
est sto arrested_nonanalytic


restore


***MATCHED SAMPLE
preserve
keep if mergematch ==3 | analytic ==1 

gcollapse analytic wgt match1_1 $table1  black white otherrace schoolpolice otherpolice hs ms felony nofelony move_in move_out jail runaway dropout ever_arrested arrested prevarrest summerpre, by(newid schoolyear post_yr)


egen max_arrested = rmax(ever_arrested prevarrest summerpre)
bys newid: egen true_ever_arrested = max(max_arrested)
drop max_arrested

*this looks sketchy, but I'm renaming schoolpolice ever_school police, felony ever_felony, ms true_ms, hs true_hs
*this is just so that they are in line with the others in the table
ren schoolpolice true_ever_schoolpolice
ren otherpolice never_schoolpolice

ren felony true_ever_felony
ren nofelony never_felony

foreach i in true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony black white otherrace hs ms $table1 {
replace `i' = `i' * 100 
}


estpost summarize black white otherrace hs ms  $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if analytic ==. & match1_1 ==1
est sto matched
estpost summarize black white otherrace hs ms $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if analytic ==. [w=wgt]
est sto weighted
estpost summarize black white otherrace hs ms $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if analytic ==1 & post_yr ==0
est sto match0
estpost summarize black white otherrace hs ms $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if analytic ==1 &  post_yr ==1
est sto match1
restore



***ANALYTIC SAMPLE
preserve
keep if analytic ==1 


*drop students that were suspended on the day of arrest
g susp = (Suspended == 1 & date == arrest_date)
bys newid: gegen max_susp =max(susp)
drop if max_susp ==1
drop max_susp


gcollapse $table1  black white otherrace schoolpolice otherpolice hs ms felony nofelony move_in move_out jail runaway dropout ever_arrested arrested prevarrest, by(newid schoolyear post_yr)

*this looks sketchy, but I'm renaming schoolpolice ever_school police, felony ever_felony, ms true_ms, hs true_hs
*this is just so that they are in line with the others in the table
ren schoolpolice true_ever_schoolpolice
ren otherpolice never_schoolpolice

ren felony true_ever_felony
ren nofelony never_felony

g true_ever_arrested =100


foreach i in true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony black white otherrace hs ms $table1 {
replace `i' = `i' * 100 
}

estpost summarize black white otherrace hs ms $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if post_yr ==0
est sto analytic0
estpost summarize black white otherrace hs ms $table1 true_ever_arrested true_ever_schoolpolice never_schoolpolice true_ever_felony never_felony if post_yr ==1
est sto analytic1

label var female "\% Female" 
label var ever_ell "\% Ever ELL" 
label var ever_gifted "\% Ever Gifted"
label var ever_iep "\% Ever had an IEP"
label var Any "Absent for Any Reason"
label var Unexcused "Unexcused Absence"
label var Suspended "Absent due to Suspension"
label var Court "Absent due to Court"
label var Medical "Absent for Medical Reason"
label var black "Black"
label var white "White"
label var otherrace "Other"
label var true_ever_schoolpolice "Ever Arrested" 
label var true_ever_schoolpolice "Arrested by School Police" 
label var never_schoolpolice "Arrested by Other Police" 
label var hs "Grades 9-12"
label var ms "Grades 6-8"
label var true_ever_felony "Arrested for Felony"
label var never_felony "Arrested for Non-Felony"


esttab all2016 all2017 analytic0 analytic1 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/table1_1-19-22", ///
nostar not  b(3) cells("mean(fmt(%9.1f))") label tex type replace nonumber ///
mtitles("\shortstack{All Students \\ SY 2015-16}" "\shortstack{All Students \\ SY 2016-17}" "\shortstack{Analytic Sample \\ Pre-Arrest}" "\shortstack{Analytic Sample \\ Post-Arrest}")

esttab weighted match0 match1 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/table2_App_1-19-22", ///
nostar not  b(3) cells("mean(fmt(%9.1f))") label tex type replace nonumber ///
mtitles("\shortstack{Matched Sample \\ Not Arrested}"  "\shortstack{Arrested Sample \\ Pre-Arrest}"  "\shortstack{Arrested Sample \\ Post-Arrest}" )

label var true_ever_schoolpolice "Ever Arrested by School Police" 
label var never_schoolpolice "Never Arrested by Other Police" 
label var hs "Percent of days in Grades 9-12"
label var ms "Percent of days in Grades 6-8"
label var true_ever_felony "Ever Arrested for Felony"
label var never_felony "Never Arrested for Non-Felony"

esttab arrested_nonanalytic using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/table1_App_1-19-22", ///
nostar not  b(3) cells("mean(fmt(%9.1f))") label tex type replace nonumber ///
mtitles("\shortstack{Arrested Students \\ not in the \\ Analytic Sample}")

restore




use "$data_dropbox/analyticsample_12-2-21", clear


global table1 "Any Unexcused Suspended Court Medical Other" 
					
g black = (racehisp ==1) 
g white = (racehisp ==0) 


collapse $table1  black white schoolpolice hs felony , by(newid)


estpost summarize $table1 
est sto All
 estpost summarize  $table1 if black == 1
est sto Black
estpost summarize  $table1 if white ==1
est sto White
 estpost summarize  $table1 if schoolpolice ==1
est sto schoolpolice1
 estpost summarize  $table1 if schoolpolice ==0
est sto schoolpolice0
 estpost summarize  $table1 if hs ==1
est sto hs1
 estpost summarize  $table1 if hs ==0
est sto hs0
 estpost summarize  $table1 if felony ==1
est sto felony1
 estpost summarize  $table1 if felony ==0
est sto felony0


esttab All White Black schoolpolice1 schoolpolice0 hs0 hs1 felony1 felony0   using "$tables/app_table1_12-2-21", ///
nostar not  b(3) cells("mean(fmt(%9.3f))") label tex type replace  ///
mtitles("All" "White" "Black" "School Police" "Non-School Police" "Grades 6-8" "Grade 9-12" "Felony" "Non-Felony")

esttab All White Black schoolpolice1 schoolpolice0 hs0 hs1 felony1 felony0   using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/app_table1_12-2-21", ///
nostar not  b(3) cells("mean(fmt(%9.3f))") label tex type replace nonumber ///
mtitles("All" "White" "Black" "\shortstack{Arrested \\ by School \\ Police}" "\shortstack{Arrested \\ by Other \\ Police}" "\shortstack{Grades \\ 6-8}" "\shortstack{Grades \\ 9-12}" "Felony" "\shortstack{Non- \\ Felony}")

*frequency of arrests by date
use "/Users/nicholasmark/Dropbox/police_absences/data/analyticsample_12-2-21.dta", clear
					
collapse arrest_date, by(newid) 

hist arrest_date, freq w(7) scheme(plotplain) xtitle(Week) ytitle(Number of Students Arrested)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/freq_arrests.pdf", replace

*Attendance
use "/Users/nicholasmark/Dropbox/police_absences/data/analyticsample_12-2-21.dta", clear
keep if schoolyear == 2016
foreach i in Any Suspended Unexcused Court Medical {
bys date: egen mn_`i' = mean(`i')
g diff_`i' = `i' - mn_`i'
drop mn_`i'
}
collapse diff_Any diff_Suspended diff_Unexcused diff_Court diff_Medical, by(time)
keep if time >-45 & time <45
twoway (lowess diff_Any time if time<0,  bw(.2) xline(20394)) (lowess diff_Any time if time>0,  bw(.2)) 

twoway (lowess diff_Suspended time if time<0,  bw(.2)) (lowess diff_Suspended time if time>0,  bw(.2)), name(susp, replace)

twoway (lowess diff_Unexcused time if time<0,  bw(.4)) (lowess diff_Unexcused time if time>0,  bw(.2)) , name(unex, replace)
grc1leg susp unex, ycommon 
///
(lowess Court time if time<0,  bw(.8)) (lowess Court time if time>0,  bw(.8)) ///
(lowess Medical time if time<0,  bw(.8)) (lowess Medical time if time>0,  bw(.8))

*********************************************************************************************************
************************************ On Average *********************************************************
*********************************************************************************************************

***********************************
* ESTIMATE with analytic sample - including dynamic effects
***********************************

use "/Users/nicholasmark/Dropbox/police_absences/data/analyticsample_12-2-21.dta", clear

*check twfe results - similar but larger for suspensions. 
foreach i in Any Suspended Unexcused Medical Court {
reghdfe `i' post_yr, absorb(newid date) cluster(newid)
}

g time_noneg = time + 11
replace time_noneg = 0 if time_noneg <0

g post_including_anticip = post_including0
replace post_including_anticip = 1 if time >-12

bys newid: egen min_time = min(time_noneg) 
tab min_time
*7 obs need to be dropped. 
*drop if min_time >0

foreach i in Any Suspended Unexcused Medical Court {
*did2s `i' , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
*regsave using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'.dta", replace
did2s `i' , first_stage(i.newid i.date) second_stage(i.time_noneg) treatment(post_including0) cluster(newid)
regsave using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_time.dta", replace
}
/*to check residuals
predict yhat_`i'
g resid = `i' - yhat_`i'

forvalues n = 1/15 {
bys newid: g resid_`i'_`n'dayb4 = resid[_n-`n']
replace resid_`i'_`n'dayb4 = . if post_including0 ==1
}
 }
 */

***********************************
* GRAPH
***********************************
* A) Average Effects
***********************************

clear
 foreach i in Any Suspended Unexcused Medical Court {
append using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'.dta"

*keep var coef stderr
replace var = "`i'" if var == "post_excluding0"
}

*normally I would use encode, but that makes things in a weird (alphabetical) order. So I'll do it manually.
g double type = 1 in 1
replace type = 2 in 2
replace type = 3 in 3
replace type = 4 in 4
replace type = 5 in 5

label define type 1 "Any" 2 "Suspended" 3 "Unexcused" 4 "Medical" 5 "Court", replace
label values type type

*95% CIs
g lower = coef-(1.96*stderr)
g upper = coef+(1.96*stderr)


twoway ///
(rcap lower upper type, lcolor(black)) ///
(scatter coef type if type ==1, msize(vlarge) mcolor(navy)  msym(S) ) ///
(scatter coef type if type >1, msize(vlarge) mcolor(navy)  msym(Sh) ), ///
 xlabel(1 2 3 4 5, val nogrid) xsc(r(.5 5.5)) yline(0) xtitle("") ylabel(, nogrid)  ///
 legend(off)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_all.pdf", replace



***********************************
* B) Dynamic Effects
***********************************
use "/Users/nicholasmark/Dropbox/police_absences/tmp/Any_time.dta", clear
keep var coef stderr
ren coef  coef_Any
ren stderr stderr_Any
g lower_Any = coef_Any-(1.96*stderr_Any)
g upper_Any = coef_Any+(1.96*stderr_Any)

 foreach i in  Suspended Unexcused Medical Court {
merge 1:1 var using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_time.dta"
keep var coef* stderr* upper* lower*
ren coef  coef_`i'
ren stderr stderr_`i'
g lower_`i' = coef_`i'-(1.96*stderr_`i')
g upper_`i' = coef_`i'+(1.96*stderr_`i')
}
g time1 = substr(var, 1, 1)
g time2 = substr(var, 2, 1)
g time3 = substr(var, 3, 1)
replace time2 = "" if time2 == "." | time2 == "b" | time2 == "t"
replace time3 = "" if time3 == "." | time3 == "b" | time3 == "t"
egen time = concat(time1 time2 time3)
destring time, replace
g realtime = time - 11
keep if realtime > -11 & realtime <43
drop var time1 time2 time3 time

twoway ///
(scatter coef_Any realtime if realtime <0, mc(maroon%20)  msize(tiny) msym(o)) ///
(lowess coef_Any realtime if realtime <0, lc(maroon) bw(.5)) ///
(lowess lower_Any realtime if  realtime <0, lc(gs12) bw(.5)) ///
(lowess upper_Any realtime if  realtime <0, lc(gs12) bw(.5)) ///
(scatter coef_Any realtime if realtime ==0, mc(gs10) msym(o) msize(large)) ///
(rcap upper_Any lower_Any realtime if realtime ==0, lc(gs10)) ///
(scatter coef_Any realtime if realtime >=1, mc(navy%20) msize(tiny) msym(o)) ///
(lowess coef_Any realtime if realtime >=1 , lc(navy) bw(.5) lp(solid)) ///
(lowess lower_Any realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)) ///
(lowess upper_Any realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)), ///
name(Any, replace) ///
 legend(off) ///
 xtitle(Days Relative to Arrest, size(small)) ///
 ytitle(Effect Estimate, size(small)) ///
 yline(0) ylabel(, nogrid) xlabel(, nogrid)

graph combine Any, title(Panel A: All Absences, pos(11)) fxsize(650) fysize(350) name(Any1, replace)

twoway ///
(scatter coef_Suspended realtime if realtime <0, mc(maroon%20)  msize(tiny) msym(o)) ///
(lowess coef_Suspended realtime if realtime <0, lc(maroon) bw(.5)) ///
(lowess lower_Suspended realtime if  realtime <0, lc(gs12) bw(.5)) ///
(lowess upper_Suspended realtime if  realtime <0, lc(gs12) bw(.5)) ///
(scatter coef_Suspended realtime if realtime >=1, mc(navy%20) msize(tiny) msym(o)) ///
(scatter coef_Suspended realtime if realtime ==0, mc(gs10) msym(o) msize(large)) ///
(rcap upper_Suspended lower_Suspended realtime if realtime ==0, lc(gs10)) ///
(lowess coef_Suspended realtime if realtime >=1 , lc(navy) bw(.5) lp(solid)) ///
(lowess lower_Suspended realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)) ///
(lowess upper_Suspended realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)), ///
name(Suspended, replace) legend(off) xtitle(Days Relative to Arrest) ///
ytitle(Effect Estimate) ysc(r(-.05 .5)) title(Suspended) yline(0)  ylabel(, nogrid) xlabel(, nogrid)

 foreach i in Unexcused Medical Court {
twoway ///
(scatter coef_`i' realtime if realtime <0, mc(maroon%20)  msize(tiny) msym(o)) ///
(lowess coef_`i' realtime if realtime <0, lc(maroon) bw(.5)) ///
(lowess lower_`i' realtime if  realtime <0, lc(gs12) bw(.5)) ///
(lowess upper_`i' realtime if  realtime <0, lc(gs12) bw(.5)) ///
(scatter coef_`i' realtime if realtime ==0, mc(gs10) msym(o) msize(large)) ///
(rcap upper_`i' lower_`i' realtime if realtime ==0, lc(gs10)) ///
(scatter coef_`i' realtime if realtime >=1, mc(navy%20) msize(tiny) msym(o)) ///
(lowess coef_`i' realtime if realtime >=1 , lc(navy) bw(.5) lp(solid)) ///
(lowess lower_`i' realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)) ///
(lowess upper_`i' realtime if realtime >=1 ,  lc(gs12) bw(.5) lp(solid)), ///
name(`i', replace) legend(off) xtitle(Days Relative to Arrest) ytitle(Effect Estimate) ///
title(`i') ylabel(-.05(.05).1) yline(0)  ylabel(, nogrid) xlabel(, nogrid)
}
graph combine Suspended Unexcused Medical Court, name(others, replace) title(Panel B: By Type of Absence, pos(11))  fxsize(650) fysize(450)

graph combine Any1 others, r(2) xsize(6.5) ysize(9)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_eventtime.pdf", replace

*testing trends
reg coef_Unexcused realtime if realtime <0 & realtime >-11
reg coef_Unexcused realtime if realtime <-11
reg coef_Unexcused realtime if realtime <0
reg coef_Unexcused if realtime <0 & realtime >-11
reg coef_Unexcused if realtime <-11
reg coef_Unexcused if realtime <0


reg coef_Suspended realtime if realtime <0 & realtime >-11
reg coef_Suspended realtime if realtime <0
reg coef_Suspended if realtime <0 & realtime >-11
reg coef_Suspended if realtime <-11
reg coef_Suspended if realtime <0

*********************************************************************************************************
************************************ By Subgroup ********************************************************
*********************************************************************************************************

***********************************
* ESTIMATE
***********************************
use "/Users/nicholasmark/Dropbox/police_absences/data/analyticsample_12-2-21.dta", clear
g time_noneg = time + 11
replace time_noneg = 0 if time_noneg <0
replace racehisp = . if racehisp >1


foreach i in Any Suspended Unexcused Medical Court {
foreach grp in schoolpolice felony racehisp hs {
display "`i'_`grp'"
did2s `i' if `grp' !=., first_stage(i.newid i.date##`grp') second_stage(post_excluding0##`grp') treatment(post_including0) cluster(newid)
est sto `i'_`grp'
margins , dydx(post_excluding0) over(`grp') post
regsave using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'.dta", replace
preserve 
keep if `grp' == 0 
did2s `i' , first_stage(i.newid i.date) second_stage(ib287.time_noneg) treatment(post_including0) cluster(newid)
regsave using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'0_time.dta", replace
restore

preserve 
keep if `grp' == 1 
did2s `i' , first_stage(i.newid i.date) second_stage(ib287.time_noneg) treatment(post_including0) cluster(newid)
regsave using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'1_time.dta", replace
restore
}
}

*Then you can use grp_i to see if they are different 
esttab Any_schoolpolice Any_felony Any_racehisp Any_hs, keep(1.post_excluding0#1.*)
esttab Suspended_schoolpolice Suspended_felony Suspended_racehisp Suspended_hs, keep(1.post_excluding0#1.*)
esttab Unexcused_schoolpolice Unexcused_felony Unexcused_racehisp Unexcused_hs, keep(1.post_excluding0#1.*)
esttab Medical_schoolpolice Medical_felony Medical_racehisp Medical_hs, keep(1.post_excluding0#1.*)
esttab Court_schoolpolice Court_felony Court_racehisp Court_hs, keep(1.post_excluding0#1.*)
***********************************
* GRAPH
***********************************
* A) Average Effects by subgroup
***********************************
clear
g type = ""
g subgroup = ""
 foreach i in Any Suspended Unexcused Medical Court {
 foreach grp in schoolpolice felony racehisp hs {
append using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'.dta"
keep var coef stderr type subgroup
replace type = "`i'" if type ==""
replace subgroup = "`grp'" if subgroup ==""

replace var = "0" if var == "1.post_excluding0:0bn.`grp'"
replace var = "1" if var == "1.post_excluding0:1.`grp'"
}
}
keep if var == "0" | var == "1"

destring var, replace
g lower = coef-(1.96*stderr)
g upper = coef+(1.96*stderr)

g double grp = 1 if subgroup == "schoolpolice"
replace grp = 2 if subgroup == "felony"
replace grp = 3 if subgroup == "racehisp"
replace grp = 4 if subgroup == "hs"
replace grp = grp-.15 if var == 0
replace grp = grp+.15 if var == 1
replace grp = grp *100
label define grp 85 "Other Police" 115 "School Police" 185 "Not Felony" 215 "Felony" 285 "White" 315 "Black" 385 "Middle School" 415 "High School", replace
label values grp grp

*check where there should be stars: only HS
*esttab marg_schoolpolice_Any marg_felony_Any marg_racehisp_Any marg_hs_Any , star(+ 0.10 * 0.05)


twoway ///
(rcap lower upper grp if type == "Any", lcolor(black)) ///
(scatter coef grp if type == "Any", msize(vlarge) mcolor(navy) msym(Oh) ///
xlabel(85 115 185 215 285 315 385 415, val angle(45) nogrid)), ///
xtitle("") legend(off) yline(0) xsc(r(75 425)) ylabel(0 .05 .1 .15, nogrid) ytitle(Effect Estimate, size(small)) ///
text(.13 400 "*", size(vlarge) color(red)) ///
text(.15 100 "Arresting" .138 100 "Agency" .15 200 "Felony" .138 200 "Status" .15 300 "Race" .15 400 "Grade" ) name(Any_grp, replace)

graph combine Any_grp, title(Panel A: All Absences, pos(11)) fxsize(650) fysize(350) name(Any_grp1, replace)

*only difference is HS
esttab Suspended_schoolpolice Suspended_felony Suspended_racehisp Suspended_hs, keep(1.post_excluding0#1.*)

 *plot each separately to include stars
twoway ///
(rcap lower upper grp if type == "Suspended", lcolor(black) ) ///
(scatter coef grp if type == "Suspended", msize(vlarge) mcolor(navy) msym(Oh)), ///
 xlabel(85 115 185 215 285 315 385 415, val angle(45) nogrid) ///
 ylabel(-.02(.02).08, nogrid) ///
 name(Suspended_grp, replace) ///
 legend(off) ///
 title(Suspended) ///
 yline(0) ///
 xtitle("") ///
 ytitle(Effect Estimate) ///
  ysc(r(-.02 .08)) ///
  xsc(r(75 425)) ///
text(.077 400 "*", size(vlarge) color(red))

esttab Unexcused_schoolpolice Unexcused_felony Unexcused_racehisp Unexcused_hs, keep(1.post_excluding0#1.*)
twoway ///
(rcap lower upper grp if type == "Unexcused", lcolor(black) ) ///
(scatter coef grp if type == "Unexcused", msize(vlarge) mcolor(navy) msym(Oh)), ///
 xlabel(85 115 185 215 285 315 385 415, val angle(45) nogrid) ///
 ylabel(-.02(.02).08, nogrid) ///
 name(Unexcused_grp, replace) ///
 legend(off) ///
 title(Unexcused) ///
 yline(0) ///
 xtitle("") ///
 ytitle(Effect Estimate, size(small)) ///
 ysc(r(-.02 .08)) ///
 xsc(r(75 425)) 
 
esttab Medical_schoolpolice Medical_felony Medical_racehisp Medical_hs, keep(1.post_excluding0#1.*)
 twoway ///
(rcap lower upper grp if type == "Medical", lcolor(black) ) ///
(scatter coef grp if type == "Medical", msize(vlarge) mcolor(navy) msym(Oh)), ///
 xlabel(85 115 185 215 285 315 385 415, val angle(45) nogrid) ///
 ylabel(-.02(.02).08, nogrid) ///
 name(Medical_grp, replace) ///
 legend(off) ///
 title(Medical) ///
 yline(0) ///
 xtitle("") ///
 ytitle(Effect Estimate, size(small)) ///
 xsc(r(75 425)) ///
ysc(r(-.02 .08)) ///
text(.077 200 "*", size(vlarge) color(red))

 
esttab Court_schoolpolice Court_felony Court_racehisp Court_hs, keep(1.post_excluding0#1.*)
twoway ///
(rcap lower upper grp if type == "Court", lcolor(black) ) ///
(scatter coef grp if type == "Court", msize(vlarge) mcolor(navy) msym(Oh)), ///
 xlabel(85 115 185 215 285 315 385 415, val angle(45) nogrid) ///
 ylabel(-.02(.02).08, nogrid) ///
 name(Court_grp, replace) ///
 legend(off) ///
 title(Court) ///
 yline(0) ///
 xtitle("") ///
 ytitle(Effect Estimate, size(small)) ///
 xsc(r(75 425)) ///
 ysc(r(-.02 .08)) ///
 text(.077 200 "*" .077 400 "*", size(vlarge) color(red))

 
graph combine Suspended_grp Unexcused_grp Medical_grp Court_grp, ycommon title(Panel B: By Type of Absence, pos(11)) fxsize(650) fysize(450) name(others_grp, replace)
graph combine Any_grp1 others_grp, ysize(9) xsize(6.5) r(2)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_subgroup.pdf", replace

***********************************
* B) Dynamic Effects by subgroup
***********************************

 foreach i in Any Suspended Unexcused Medical Court {
 use "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_schoolpolice0_time.dta", clear
g yes = 0
append using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_schoolpolice1_time.dta"
replace yes = 1 if yes ==. 
g subgroup = "schoolpolice"
foreach grp in felony racehisp hs {
append using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'0_time.dta"
replace yes = 0 if yes ==.

append using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_`grp'1_time.dta"
replace yes = 1 if yes ==.

replace subgroup = "`grp'" if subgroup ==""
}
keep var coef stderr yes subgroup

ren coef coef_`i'
ren stderr stderr_`i'
g lower_`i' = coef_`i'-(1.96*stderr_`i')
g upper_`i' = coef_`i'+(1.96*stderr_`i')
 save "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_time.dta", replace
}

use "/Users/nicholasmark/Dropbox/police_absences/tmp/Any_time.dta"
 foreach i in  Suspended Unexcused Medical Court {
merge 1:1 var yes subgroup using "/Users/nicholasmark/Dropbox/police_absences/tmp/`i'_time.dta", nogen update
}


g time1 = substr(var, 1, 1)
g time2 = substr(var, 2, 1)
g time3 = substr(var, 3, 1)
replace time2 = "" if time2 == "." | time2 == "b" | time2 == "t" | time2 == "o"
replace time3 = "" if time3 == "." | time3 == "b" | time3 == "t" | time3 == "o"
egen time = concat(time1 time2 time3)
destring time, replace
g realtime = time - 11
keep if realtime > -11 & realtime <46
keep realtime coef* stderr* subgroup  upper* lower* yes
egen newsubgroup = group(subgroup yes)
label define newsubgroup 1 "Not Felony" 2 "Felony" 3 "Middle School" 4 "High School" 5 "White" 6 "Black" 7 "Not School Police" 8 "School Police"
label values newsubgroup newsubgroup

*Any Suspended Unexcused Medical Court 
 foreach i in Any Suspended Unexcused Medical Court  {
twoway ///
(scatter coef_`i' realtime if realtime <0, mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_`i' realtime if realtime <0, lc(maroon) bw(.7) by(newsubgroup)) ///
(lowess lower_`i' realtime if  realtime <0, lc(gs12) bw(.7) by(newsubgroup)) ///
(lowess upper_`i' realtime if  realtime <0, lc(gs12) bw(.7) by(newsubgroup)) ///
(scatter coef_`i' realtime if realtime >=1, mc(navy%20) msize(tiny) msym(o)  by(newsubgroup)) ///
(lowess coef_`i' realtime if realtime >=1 , lc(navy) bw(.7) lp(solid)  by(newsubgroup)) ///
(lowess lower_`i' realtime if realtime >=1 ,  lc(gs12) bw(.7) lp(solid)  by(newsubgroup)) ///
(lowess upper_`i' realtime if realtime >=1 ,  lc(gs12) bw(.7) lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(`i'_time, replace) legend(off) xlabel(, nogrid) xtitle(Days Relative to Arrest) ytitle(Effect Size)  yline(0)
graph display `i'_time, xsize(6.5) ysize(8.5) name(`i'_time1, replace)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_`i'_subgroup_eventtime.pdf", replace
}

preserve 
keep if newsubgroup ==7 | newsubgroup ==8
twoway ///
(scatter coef_Suspended realtime if realtime <0 , mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Suspended realtime if realtime <0 , lc(maroon) lp(line) bw(.7) by(newsubgroup)) ///
(lowess lower_Suspended realtime if  realtime <0 , lc(gs12)  lp(line)  bw(.7) by(newsubgroup)) ///
(lowess upper_Suspended realtime if  realtime <0 , lc(gs12)  lp(line)  bw(.7) by(newsubgroup)) ///
(scatter coef_Suspended realtime if realtime ==0, mc(gs10) msym(o) msize(large)  by(newsubgroup)) ///
(rcap upper_Suspended lower_Suspended realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Suspended realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Suspended realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Suspended realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Suspended realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Suspended_schoolpolice, replace) xlabel(-10(10)40, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_eventtime_suspended_schoolpolice.pdf", replace 

twoway ///
(scatter coef_Court realtime if realtime <0 , mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Court realtime if realtime <0 , lc(maroon) lp(line)  bw(.7) by(newsubgroup)) ///
(lowess lower_Court realtime if  realtime <0 , lc(gs12) lp(line)  bw(.7) by(newsubgroup)) ///
(lowess upper_Court realtime if  realtime <0 , lc(gs12) lp(line)  bw(.7) by(newsubgroup)) ///
(scatter coef_Court realtime if realtime ==0, mc(gs10) msym(o) msize(large)  by(newsubgroup)) ///
(rcap upper_Court lower_Court realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Court realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Court realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Court realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Court realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Court_schoolpolice, replace) xlabel(, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)

twoway ///
(scatter coef_Unexcused realtime if realtime <0, mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Unexcused realtime if realtime <0 , lc(maroon)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess lower_Unexcused realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess upper_Unexcused realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(scatter coef_Unexcused realtime if realtime ==0, mc(gs10) msym(o) msize(large)  by(newsubgroup)) ///
(rcap upper_Unexcused lower_Unexcused realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Unexcused realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Unexcused realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Unexcused realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Unexcused realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Unexcused_schoolpolice, replace) xlabel(, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)
restore

preserve 
keep if newsubgroup ==1 | newsubgroup ==2


twoway ///
(scatter coef_Suspended realtime if realtime <0, mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Suspended realtime if realtime <0 , lc(maroon)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess lower_Suspended realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess upper_Suspended realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(rcap upper_Suspended lower_Unexcused realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Suspended realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Suspended realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Suspended realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Suspended realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Suspended_felony, replace) xlabel(, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)

twoway ///
(scatter coef_Unexcused realtime if realtime <0, mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Unexcused realtime if realtime <0 , lc(maroon)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess lower_Unexcused realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess upper_Unexcused realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(rcap upper_Unexcused lower_Unexcused realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Unexcused realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Unexcused realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Unexcused realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Unexcused realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Unexcused_felony, replace) xlabel(, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)

restore


preserve 
keep if newsubgroup ==3 | newsubgroup ==4
twoway ///
(scatter coef_Medical realtime if realtime <0, mc(maroon%20) by(newsubgroup) msym(o)) ///
(lowess coef_Medical realtime if realtime <0 , lc(maroon)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess lower_Medical realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(lowess upper_Medical realtime if  realtime <0 , lc(gs12)  lp(line) bw(.7) by(newsubgroup)) ///
(scatter coef_Medical realtime if realtime ==0, mc(gs10) msym(o) msize(large)  by(newsubgroup)) ///
(rcap upper_Medical lower_Medical realtime if realtime ==0, lc(gs10)  by(newsubgroup)) ///
(scatter coef_Medical realtime if realtime >=1 , mc(navy%20)  by(newsubgroup) msym(o) lp(solid)) ///
(lowess coef_Medical realtime if realtime >=1 , lc(navy) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess lower_Medical realtime if realtime >=1 ,  lc(gs12) bw(.7) by(newsubgroup) lp(solid)) ///
(lowess upper_Medical realtime if realtime >=1,  lc(gs12) bw(.7)  lp(solid) by(newsubgroup, legend(off) c(2) note(""))), ///
name(Medical_felony, replace) xlabel(, nogrid) ylabel(, nogrid) xtitle("") ytitle(Effect Estimate) yline(0)
restore

graph combine Suspended_schoolpolice, title(Panel A: Effects on Absences Due to Suspension, pos(11)) name(Suspended_schoolpolice1, replace)
graph combine Unexcused_schoolpolice, title(Panel B: Effects on Unexcused Absences, pos(11)) name(Unexcused_schoolpolice1, replace)
graph combine Court_schoolpolice, title(Panel C: Effects on Court Absences, pos(11)) name(Court_schoolpolice1, replace)

graph combine Suspended_schoolpolice1 Unexcused_schoolpolice1 , xsize(6.5) ysize(9) r(2) imargin(0)
graph export "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/figures/did_subgroup_eventtime.pdf", replace 


********************************************************************************************************************************************
********************************************************************************************************************************************
*Appendix

***********************************
* ESTIMATE with the part of the analytic sample that dropped out, etc
***********************************

use "/Users/nicholasmark/Dropbox/police_absences/data/analyticsample_12-2-21.dta", clear
keep if n_days <181

label var post_yr "Post-Arrest"

reghdfe Any post_yr, absorb(newid date) cluster(newid)
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/twfe_dropouts.tex", replace tex(frag) label alpha(0.1, 0.05, 0.01, 0.001) symbol(+, *, **, ***)
foreach i in  Suspended Unexcused Medical Court {
reghdfe `i' post_yr, absorb(newid date) cluster(newid)
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/twfe_dropouts.tex", append tex(frag) label alpha(0.1, 0.05, 0.01, 0.001) symbol(+, *, **, ***)
}

bys newid: egen last_day = max(date)
g days_enrolled_postarrest = last_day - arrest_date
tab days_en if day ==1



***********************************
* ESTIMATE with the 1-1 matched sample
***********************************
use "/Users/nicholasmark/Dropbox/police_absences/data/fullsample_12-2-21.dta", clear
merge m:1 newid schoolyear using  "/Users/nicholasmark/Dropbox/police_absences/data/matchgroup_12-7-21.dta", gen(mergematch) 
keep if (mergematch ==3 | analytic ==1)
replace analytic =0 if analytic !=1

preserve
collapse analytic arrested, by(newid schoolyear)
tab analytic arrested
restore



label var post_yr "Post-Arrest"

*this variable includes the anticiption day of 1:
g post_including0 = (date >= arrest_date)
*this post variable starts the day AFTER arrest. So we need anticipation days of at least 1
g post_excluding0 = (date >arrest_date)


g time = date - arrest_date
replace time = 0 if time ==.
g time_noneg = time + 11
replace time_noneg = 0 if time_noneg <0

egen group_date = group(date group)
replace group_date =-1 if group_date ==.

egen untreated_date = group(date analytic)

foreach i in Any Suspended Unexcused Medical Court {
preserve

bys group_date analytic: egen mean_group_`i' = mean(`i')
replace mean_group_`i' = . if analytic ==1
bys group_date: fillmissing mean_group_`i'
g diff_`i' = `i' - mean_group_`i'

*for those missing a match, replace the "diff" var with the difference with average of untreated 
bys untreated_date: egen mean_untreated_`i' = mean(`i')
replace mean_untreated_`i' = . if diff_`i' ==.
bys untreated_date: fillmissing mean_untreated_`i'
count if diff_`i' ==.
replace diff_`i' = `i' - mean_untreated_`i' if diff_`i' ==.

keep if analytic ==1 
did2s diff_`i' , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
est save did2s_m_`i', replace
*did2s `i', first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
*est save did2s_a_`i', replace
*did_imputation diff_`i' newid date arrest_date, autosample shift(1)
*est save m_`i', replace
*did_imputation `i' newid date arrest_date if analytic ==1, autosample  shift(1)
*est save a_`i', replace
restore

}

foreach x in did2s_a {
est use `x'_Any
label var post_excluding0 "Effect of Arrest"
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/`x'.tex", replace tex(frag) label ///
ctitle(Any) stats(coef se) noobs addtext(N Students, 355) alpha(0.001 ,0.01, 0.05, 0.1) symbol(***, **, *, +)
foreach i in  Suspended Unexcused Medical Court {
est use `x'_`i'
label var post_excluding0 "Effect of Arrest"
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/`x'.tex", append tex(frag) label ///
ctitle(`i')  stats(coef se) noobs addtext(N Students, 355) alpha(0.001 ,0.01, 0.05, 0.1) symbol(***, **, *, +)
}
}

foreach x in did2s_m {
est use `x'_Any
label var post_excluding0 "Effect of Arrest"
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/`x'.tex", replace tex(frag) label ///
ctitle(Any) stats(coef se) noobs addtext(N Students, 4758) alpha(0.001 ,0.01, 0.05, 0.1) symbol(***, **, *, +)
foreach i in  Suspended Unexcused Medical Court {
est use `x'_`i'
label var post_excluding0 "Effect of Arrest"
outreg2 using "/Users/nicholasmark/Dropbox/Apps/Overleaf/Arrests and Attendance/tables/`x'.tex", append tex(frag) label ///
ctitle(`i')  stats(coef se) noobs addtext(N Students, 4758) alpha(0.001 ,0.01, 0.05, 0.1) symbol(***, **, *, +)
}
}


***********************************
* ESTIMATE with students who were arrested over the summer vs analytic before they were arrested - This doesnt work, its jus 
***********************************
use "/Users/nicholasmark/Dropbox/police_absences/data/fullsample_12-2-21.dta", clear
bys newid: egen max_analytic = max(analytic)
keep if summerpre ==1 | analytic ==1
*this variable includes the anticiption day of 1:
g post_including0 = (date >= arrest_date) | summerpre ==1
*this post variable starts the day AFTER arrest. So we need anticipation days of at least 1
g post_excluding0 = (date >arrest_date) | summerpre ==1


did2s Any , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
did2s Suspended , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
did2s Unexcused , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
did2s Medical , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
did2s Court , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)
did2s Other , first_stage(i.newid i.date) second_stage(post_excluding0) treatment(post_including0) cluster(newid)



                                                                
/*****************************************************************************/
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");
/*****************************************************************************/
cas; 
caslib _all_ assign;
proc contents data =public.COMPRESSOR_ISEFF;
run;
proc univariate data =public.COMPRESSOR_ISEFF;
var Isentropic_Efficiency;
run;
/*****************************************************************************/
/**Identify and Plot Normal Conditions of IEFF **/
/*****************************************************************************/
/*Identify the Normal Conditions Area from Data*/;
* Series plot of IEFF;
data public.COMPRESSOR_ISEFF_Sample;
 set public.COMPRESSOR_ISEFF ;
/*     WHERE Date_Time BETWEEN '1Aug2018:00:00:25'dt AND '20Jul2020:00:00:25'dt; */
    WHERE Date_Time GT '1Jul2019:00:40:25'dt ;
run;

PROC GPLOT DATA = public.COMPRESSOR_ISEFF_Sample;
PLOT Isentropic_Efficiency * Date_Time  /
 	VAXIS=AXIS1
	HAXIS=AXIS2
FRAME;
Title 'IEFF Degradation Plot in Sample  Data ';
RUN; QUIT;

/*Plot the Normal Conditions Area from Data*/;
* Series plot of IEFF;
data public.COMPRESSOR_ISEFF_Train;
 set public.COMPRESSOR_ISEFF ;
    WHERE Date_Time BETWEEN '1Aug2019:00:00:25'dt AND '27Aug2019:23:50:25'dt; /*Equal Spaced Obs*/
run;

PROC GPLOT DATA = public.COMPRESSOR_ISEFF_Train;
PLOT Isentropic_Efficiency * Date_Time  /
 	VAXIS=AXIS1
	HAXIS=AXIS2
FRAME;
Title 'IEFF Degradation Plot in Normalised Training Data ';
RUN; QUIT;

/*Univariate of Normalise Training Data*/
proc univariate data = public.COMPRESSOR_ISEFF_Train;
var Isentropic_Efficiency
	_61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
	_61PIT222_DischargePressure _61TIT221_DischargeTemperature
	_61FIT101_VolumetricFlowrate ;
run;
/*****************************************************************************/
*Creating Model Specifications Using PROC SMSPEC;
/*****************************************************************************/
/*A - With log Transform*/;
proc smspec;
target transform = logm;
input        _61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
			_61PIT222_DischargePressure _61TIT221_DischargeTemperature
			_61FIT101_VolumetricFlowrate  / transform = logm;
	reg name=public.reg_log alpha=0.10 holdout=200;
	arima name=public.arima_log alpha=0.10 holdout=200; 
run;

/*B - With/out Log Transform*/;
proc smspec;
/* target transform = log; */
input       _61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
			_61PIT222_DischargePressure _61TIT221_DischargeTemperature
			_61FIT101_VolumetricFlowrate  ;
	reg name=public.reg_ alpha=0.10 holdout=200;
	arima name=public.arima_ alpha=0.10 holdout=200; 
run;

/*****************************************************************************/
*Creating Project Repository Using PROC SMPROJECT;
/*****************************************************************************/

/*Create a Stable Variable in Training Dataset, Not Required in Score Dataset*/;
data public.project_1 (Keep = Date_Time stable Isentropic_Efficiency
						_61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
						_61PIT222_DischargePressure _61TIT221_DischargeTemperature
						_61FIT101_VolumetricFlowrate );
set  public.COMPRESSOR_ISEFF_Train;
	stable=1;
run;
/*Create Score dataset from Historial Data*/;
data public.project_1_score (Keep = 
						 Date_Time  Isentropic_Efficiency
						_61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
						_61PIT222_DischargePressure _61TIT221_DischargeTemperature
						_61FIT101_VolumetricFlowrate );
set public.COMPRESSOR_ISEFF ;
    WHERE Date_Time BETWEEN '16Jul2020:00:00:25'dt and '27Jul2020:23:50:25'dt ; /*1440 Obs*/
run;

proc smproject name=public.proj1
	    id = 1
       holdout   = 10
       alpha     = 0.10
       data      = public.project_1
       scoredata = public.project_1_score;
target Isentropic_Efficiency;
input   
		_61PIT120_Suction_Pressure _61TIT121_SuctionTemperature 
	    _61PIT222_DischargePressure _61TIT221_DischargeTemperature
	    _61FIT101_VolumetricFlowrate ;
	stable stable;
    datetime Date_Time;
model REG_ ARIMA_ REG_LOG ARIMA_LOG / force nowarn;
run;

proc print data = public.proj1 ; run;
/*****************************************************************************/
/*Calibrating the Project Using PROC SMCALIB*/;
/*****************************************************************************/
ods output holdoutstats=work.holdstat1__compressor;
proc smcalib name = public.proj1;
	output modelfit = public.mfit_compressor
	holdoutfit = public.hfit__compressor
	scoreinfo = public.sinfo__compressor;
store public.scoreout__compressor;
run;
ods output close;
/*****************************************************************************/
*Selecting the Best Models Using PROC SMSELECT;
/*****************************************************************************/
proc smselect name=public.proj1 input=work.holdstat1__compressor; output out=public.mymodels__compressor; run;
proc print data=public.mymodels__compressor; run;

/*****************************************************************************/
*Auto Monitoring Using PROC SMSCORE;
/*****************************************************************************/
proc smscore name = public.proj1
	scorerepository=public.scoreout__compressor models=public.mymodels__compressor;
	output out = public.score__compressor;
run;

 
####Load appropriate packages
#Load competition data
library(Mcomp)

#Load lm and timeseries analysis packages
library(lmtest)
library(forecTheta)
library(tseries)
library(MAPA)

# List time series for review as those ending in 7 as on library card
timeSeries = seq (707,1400,10)

#find max and min time series length
timeSeriesLength = array(0,length(timeSeries))
for ( i in 1:length(timeSeries))(
  timeSeriesLength[i] = length(M3[[timeSeries[i]]]$x)
)
max(timeSeriesLength)
min(timeSeriesLength)

length(detailArray[which(detailArray[,6]==1),6])

#remove from loop
Q1s = seq (1,400,4)
Q2s = seq (2,400,4)
Q3s = seq (3,400,4)

#create an array of dummy variables for the 4 seasons of the quarterly data
dummys = array(0, c(400,4))
dummys[,1] = 1:400
for (i in 1:400){
  if(dummys[i,1] %in% Q1s){
    dummys[i,2] = 1
  }
  if(dummys[i,1] %in% Q2s){
    dummys[i,3] = 1
  }
  if(dummys[i,1] %in% Q3s){
    dummys[i,4] = 1
  }
}

#Some problems were had with Arimas, while the majority have been fixed on occasion error management code 
#has been used in a function - the try() function. Should this try be unsuccessful the arima forecast
#will return these global variables; these will impact MAPE/ Log accuracy and penalise the arima, prevent it from
#from being used on inappropriate data - the majority of errors occur in the non-toolbox arima models, particularly the 
#seasonal ones.

arima1, arima2, arima3, arima4, arima5, arima6, arima7, arima8, arima9 = Arima(1:8)

#Create arrays to hold performance measures for model selection
LARs = array(0, c(length(timeSeries),no_methods))
LARs2 = array(0, c(length(timeSeries),no_methods))
#and the output of the model selection
chosenModel = array(0,c(length(timeSeries),3))
chosenModel[,1] = timeSeries


###############Load functions to be used ############

#Create function to run Cox-Stuart Test
#From: MARTINO, Tommaso (2009). Trend analysis with the Cox-Stuart test in R. Retrieved 2010-02-17, from <http://statistic-on-air.blogspot.com/2009/08/trend-analysis-with-cox-stuart-test-in.html>
cox.stuart.test = function (x) {
    method = "Cox-Stuart test for trend analysis"
    leng = length(x)
    apross = round(leng) %% 2
    if (apross == 1) {
      delete = (length(x)+1)/2
      x = x[ -delete ] 
    }
    half = length(x)/2
    x1 = x[1:half]
    x2 = x[(half+1):(length(x))]
    difference = x1-x2
    signs = sign(difference)
    signcorr = signs[signs != 0]
    pos = signs[signs>0]
    neg = signs[signs<0]
    if (length(pos) < length(neg)) {
      prop = pbinom(length(pos), length(signcorr), 0.5)
      names(prop) = "Increasing trend, p-value"
      rval <- list(method = method, statistic = prop)
      class(rval) = "htest"
      return(rval)
    }
    else {
      prop = pbinom(length(neg), length(signcorr), 0.5)
      names(prop) = "Decreasing trend, p-value"
      rval <- list(method = method, statistic = prop)
      class(rval) = "htest"
      return(rval)
    }
}

#create is even function to check if a number is even
is.even <- function(x) x %% 2 == 0

############ Toolbox of forecasting methods #################
toolbox = function(tsRef,rawSample,decompSample,decompSeasonCo,tool,origin,horizon,useRules=FALSE,checkArimas =FALSE,justToolbox=TRUE){
  
   if (tool == 1){
     #set rules - if useRules = TRUE, if FALSE rules not considered
    if (!useRules | (detailArray[tsRef,3] != 0)) {
      
      #log raw sample to account for multiplicative trend/errors
      lograwSample = log10(rawSample)
      mlmadjfit = tslm(lograwSample~seq(1,origin)+dummys[,2][1:origin]+dummys[,3][1:origin]+dummys[,4][1:origin])
      
      #forecast and undo the log
      result = 10^(forecast(mlmadjfit, h = origin)$mean[1:horizon])
    } else { result = 1:8}
    
  } else if (tool == 2){
    # Holt's (linear trend) Exponential Smoothing
    # additive errors and therefore heteroskedastic not appropriate
    # non-linearness of lm model residuals not overly considered as potentially just a poor model, not indicative of exponential etc
    #however heteroskedastic fairly solid
    if (!useRules | ((detailArray[tsRef,3] == 1)&(detailArray[tsRef,7] == 0)|(detailArray[tsRef,8] == 0))) {
      holtLT = ets(decompSample, model="AAN", damped=FALSE)
      result = (forecast(holtLT, h = horizon)$mean)*decompSeasonCo
    } else { result = 1:8}
    
  } else if (tool == 3){
    # Simple Exponential Smoothing
    #additive errors and no trend
    if (!useRules | (detailArray[tsRef,3] == 0)) {
      ses = ets(decompSample, model="ANN")
      result = (forecast(ses, h = horizon)$mean)*decompSeasonCo
    } else { result = 1:8}
    
  } else if (tool == 4){
    # H
    if (!useRules | (detailArray[tsRef,3] == 1) ) {
      esAAA = ets(rawSample, model="MAM", damped=FALSE)
      result = forecast(esAAA, h = horizon)$mean
    } else { result = 1:8}
  } else if (tool == 5){
    ### ETS Model MMM damped
    if (!useRules | ((detailArray[tsRef,3] == 1)&(detailArray[tsRef,3] == 1)) ) {
      esAAA = ets(rawSample, model="MMM", damped=TRUE)
      result = forecast(esAAA, h = horizon)$mean
    } else { result = 1:8}
    
  } else if (tool ==6){
    #Drift method, with seasonality adjusted (trend tick, seasonality tick, first dif)
    #Should perform well against level change
    try(arima2 <- Arima(decompSample, order=c(0,1,0), include.drift=TRUE,method="ML"),silent = TRUE)
    
    if ((!useRules | ((detailArray[tsRef,5] == 1) & (detailArray[tsRef,3] == 1))) & !checkArimas ) {
      #Nelder-Mead optim method as Hessian method formed errors on 2 timeSeries for no discernable reason; issue found online at https://stat.ethz.ch/pipermail/r-help/2015-February/425777.html
      result = forecast(arima2, h = horizon)$mean*decompSeasonCo
    } else if((length(arima2$residuals) > 11) & !((detailArray[tsRef,5] == 1) & (detailArray[tsRef,3] == 1)) & (Box.test(residuals(arima2), lag=8, type="Ljung")$p.value <0.05)){
      result = 1:8
    } else {
      result = forecast(arima2, h = horizon)$mean*decompSeasonCo
    }
  } else if (tool == 7){
      try(arima3 <- Arima(decompSample, order=c(2,0,0),method="ML"),silent = TRUE)
      if ((!useRules | (detailArray[tsRef,5] == 0)) & !checkArimas) {
        result = forecast(arima3, h = horizon)$mean*decompSeasonCo
      } else if((length(arima3$residuals) > 11) & (Box.test(residuals(arima3), lag=8, type="Ljung")$p.value <0.05)){
        result = 1:8
      } else if (detailArray[tsRef,5] == 0){
        result = forecast(arima3, h = horizon)$mean*decompSeasonCo
      }
    
  } else if (tool == 8){
    try(arima5  <- Arima(decompSample, order=c(0,2,0),method="ML"),silent = TRUE)
    if ((!useRules | (detailArray[tsRef,5] == 2)) & !checkArimas) {
      result = forecast(arima5, h = horizon)$mean*decompSeasonCo
    } else if((length(arima5$residuals) > 11) & (Box.test(residuals(arima5), lag=8, type="Ljung")$p.value <0.05)){
      result = 1:8
    } else if (detailArray[tsRef,5] == 2){
      result = forecast(arima5, h = horizon)$mean*decompSeasonCo
    }
  } else if (tool == 9){
    if (!useRules | (detailArray[tsRef,3] =! 0)) {
    result = dotm(decompSample, h=horizon)$mean*decompSeasonCo
    } else { result = 1:8}
  } else if (tool == 10){
    if (!useRules | (detailArray[tsRef,3] =! 0)) {
    result = stm(decompSample, h=horizon)$mean*decompSeasonCo
    } else { result = 1:8}
  }

######END OF TOOLBOX #### 
# Below contains non-toolbox selected models used initially.
# To view output, set justToolbox = FALSE and method number as 20

  if (tool == 11){
    ####Linear model on deseasoned data
     if (!justToolbox & ( useRules | ((detailArray[tsRef,8] == 0)&(detailArray[tsRef,7] == 0)))) {
        lmfit = tslm(decompSample~trend)
        result = (forecast(lmfit, h = horizon)$mean)*decompSeasonCo
     } else { result = 1:8}

  } else if (tool == 12){
    ###Damped multiplicative trend (Taylor 2003)
    #if theres a trend use model; left in damped as many economic data tend to plateau so this should work with
    #linear and decaying trends /damped trends
      if (!justToolbox & (useRules | (detailArray[tsRef,3] == 0))) {
        dampMT =  ets(rawSample, model="MAA", damped=TRUE)
         result = forecast(dampMT, h = horizon)$mean
      } else { result = 1:8}
 
  } else if (tool == 13){
    ### Holt-Winter's Exponential Smoothing (additive seasonality)
      if (!justToolbox & (useRules | (detailArray[tsRef,7] == 0))) {
        esAAA = ets(rawSample, model="AAA", damped=FALSE)
        result = forecast(esAAA, h = horizon)$mean
      } else { result = 1:8}

  } else if (tool == 14){
    ### ETS model MNM
      if (!justToolbox & (useRules | (detailArray[tsRef,4] == 0)) ){
        esAAA = ets(rawSample, model="MNM", damped=FALSE)
        result = forecast(esAAA, h = horizon)$mean
      } else { result = 1:8 }
    
  } else if (tool == 15){
    ### ETS model MMM
      if (!justToolbox & (useRules | (detailArray[tsRef,4] != 0) )) {
       esAAA = ets(rawSample, model="MMM", damped=FALSE)
       result = forecast(esAAA, h = horizon)$mean
      } else {result = 1:8}
    
  } else if (tool == 16){
      try(arima1 <- Arima(rawSample, order=c(1,1,0), seasonal=list(order=c(1,1,0)), method = "ML", optim.method="Nelder-Mead"), silent = TRUE)
      try(arima1 <- Arima(rawSample, order=c(1,1,0), seasonal=list(order=c(1,1,0)), method = "ML"), silent = TRUE)
      if (useRules | (checkArimas==FALSE) ) {
        #Nelder-Mead optim method as Hessian method formed errors on 2 timeSeries for no discernable reason; issue found online at https://stat.ethz.ch/pipermail/r-help/2015-February/425777.html
        result = forecast(arima1, h = horizon)$mean
        } else if (length(arima1$residuals) > 11) { if(Box.test(residuals(arima1), lag=8, type="Ljung")$p.value <0.05){
          result = 1:8
        } else {
          result = forecast(arima1, h = horizon)$mean
        }
      }
    
  } else if (tool == 17){
      try(arima4 <- Arima(rawSample, order=c(1,1,3), seasonal=list( order=c(0,1,0)), method = "ML", optim.method="Nelder-Mead"),silent=TRUE)
      try(arima4 <- Arima(rawSample, order=c(1,1,3), seasonal=list( order=c(0,1,0)), method = "ML"),silent=TRUE)
      if (!justToolbox & (useRules | (checkArimas==FALSE) ) ){
        result = forecast(arima4, h = horizon)$mean
      } else if((length(arima4$residuals) > 11) & (Box.test(residuals(arima4), lag=8, type="Ljung")$p.value <0.05)){
        result = 1:8
      } else { 
        result = forecast(arima4, h = horizon)$mean
      }
    
  } else if (tool == 18){
      try(arima6  <- Arima(decompSample, order=c(0,1,3),method="ML"))
      if (!justToolbox & (useRules | (checkArimas==FALSE) )) {
        result = forecast(arima6, h = horizon)$mean*decompSeasonCo
      } else if((length(arima6$residuals) > 11) & (Box.test(residuals(arima6), lag=8, type="Ljung")$p.value <0.05)){
        result = 1:8
      } else {
        result = forecast(arima6, h = horizon)$mean*decompSeasonCo
      }
    
  } else if (tool == 19){
      try(arima7  <- Arima(decompSample, order=c(1,1,3),method="ML"))
      if (!justToolbox & (useRules | (checkArimas==FALSE) )) {
        result = forecast(arima7, h = horizon)$mean*decompSeasonCo
      } else if((length(arima7$residuals) > 11) & (Box.test(residuals(arima7), lag=8, type="Ljung")$p.value <0.05)){
        result = 1:8
      } else {
        result = forecast(arima7, h = horizon)$mean*decompSeasonCo
      }
    
  } else if (tool == 20){
      if(!justToolbox){
        result  <- stm(decompSample, h=horizon)$mean*decompSeasonCo
      } else {result = 1:8}
}
  return(result)
  
}

#benchmark box - box of benchmark forecasting methods to compare efficacy of toolbox
benchmarkbox = function(inSample,benchmark,origin=FALSE,horizon=FALSE){
  if (benchmark == "naive"){
    result =  naive(inSample, h = horizon)$mean
  } 
  else if (benchmark == "MAPA"){
    mapa = mapa(inSample,4,fh=8,outplot=0, hybrid =FALSE)
    result = mapa$outfor
  } 
  else if (benchmark == "autoETS")    {
    autoETS =  ets(inSample)
    result = forecast(autoETS, h = horizon)$mean
  }
  ##stlf(forecast)    is an option
}




############## Step 1: Analyse time series to create detailed array ###############

detailArray = array(0,c(length(timeSeries),9))
dataTypes = c( "DEMOGRAPHIC", "FINANCE", "INDUSTRY", "MACRO", "MICRO", "OTHER")
dataPatterns = c("Trended","Seasonal","Non-Stationary","NS-Stationary","Heteroskedastic","Non-linear" ,"No trend")
for (j in 1: length(dataTypes)){
  for(i in 1:length(timeSeries)){
    if(M3[[timeSeries[i]]]$type == dataTypes[j]){
      series = M3[[timeSeries[i]]]$x
      if (is.even(length(series))){
        series2 = na.remove(decompose(series)$trend)
      }else { 
        series2 = ts(na.remove(decompose(series)$trend)[-(length(na.remove(decompose(series)$trend))+1)/2], frequency = 4)
      }
      
      detailArray[i,1] = timeSeries[i]
      detailArray[i,2] = dataTypes[j]
      if (cox.stuart.test(series2)$statistic < 0.05) {
        detailArray[i,3] = 1
        detailArray[i,9] = 0
      } else {
        detailArray[i,3] = 0
        detailArray[i,9] = 1
        
      }
      quarter =cycle(decompose(series,type = "m")$season)
      seasonalIndices =decompose(series, type = "m")$season
      ?ndiffs
      fdArray = array(0, (c(length(seasonalIndices),2)))
      fdArray[,2] = quarter
      fdArray[,1] = seasonalIndices
      ?friedman.test
      if(friedman.test(fdArray)$p.value <0.05){
        detailArray[i,4] = 1
      } else {
        detailArray[i,4] = 0
        
      }
      detailArray[i,5] = ndiffs(series)
      detailArray[i,6] = nsdiffs(series)

      tslm = tslm(series~trend+season)
      if (bptest(tslm)$p.value < 0.05){
        detailArray[i,7] = 1
      } else {
        detailArray[i,7] = 0
      }
      if (dwtest(tslm)$p.value < 0.05){
        detailArray[i,8] = 1
      } else {
        detailArray[i,8] = 0
      }
      
    }
  }
}



#Complete graph showing all time series
par(mfrow=c(1,1))
plot(0,ylim= c(-1.3,1.3),xlim=c(1959,1995))
abline(0, 0)  
palette = rainbow(timeSeries) 

for (i in 1:length(timeSeries)){
  
  data = M3[[timeSeries[i]]]$x
  tslm2 = tslm(data~trend+season)$residuals/mean(data)
  lines(tslm2, col=palette[i])
}


#split time series
par(mfrow=c(4,5))
par(mar=c(.5,.5,.5,.5),oma = c(2.5,3,1.5,1))
colors = c("red", "","grey" ,"blue"   ,"orange", "green"  ,  "purple")

for (z in c(1,7,5,6)){
  for (k in 1:5){
    #if first or last row add axis values, if not, dont.
    if(k==1){ yaxt = 's'} else { yaxt = 'n'}
    if(z==6){ xaxt = 's'} else { xaxt = 'n'}
    
    #Plot blank and known values of data (could do more dynamic but haven't)
    plot(0,ylim= c(-0.8,0.8),xlim=c(1980,1993.5), yaxt = yaxt, xaxt = xaxt, yaxp  = c(0.5, -0.5, 2))
    col = colors[z]
    #if first row of par plot or first column, give titles
    if(k==1){mtext(text=dataPatterns[z],side=2, line =2,cex = 0.8)}
    if(z==1){mtext(text=dataTypes[k],side=3, line =0.5)}
    abline(0,0)
    
    #set/reset count to zero
    count = 0
    for (i in 1:length(timeSeries)){
      if (detailArray[i,2] == dataTypes[k]){
        if (detailArray[i,z+2] != 0){
          ts = M3[[timeSeries[i]]]$x
          tslm2 = tslm(ts~trend+season)$residuals/mean(ts)
          lines(tslm2, col=col)
          #count every line plotted in a sub-graph
          count = count +1 
        }
      }
    }
    #label the sub-graph with the count
    text(1992, 0.5, label = count)
  }
}

#plot time series required 2 diffs to become stationary (only Macro in our 70 timeSeries)
par(mfrow=c(1,1))
z=3
k=4
plot(0,ylim= c(-0.6,0.6),xlim=c(1980,1993.5), yaxt = 's', xaxt = 's', yaxp  = c(0.5, -0.5, 2))
if(k==4){mtext(text=dataPatterns[z],side=2, line =2,cex = 0.8)}
if(z==3){mtext(text=dataTypes[k],side=3, line =0.5)}
abline(0,0)
for (i in 1:length(timeSeries)){
  if (detailArray[i,2] == dataTypes[k]){
    if (detailArray[i,z+2] == 2){
      print (i)
      data = M3[[timeSeries[i]]]$x
      tslm2 = tslm(data~trend+season)$residuals/mean(y)
      lines(tslm2, col=col)
    }
  }
}


############# STEP 2 Cross-validation of toolbox models ###############

for (i in 1:length(timeSeries)){
  y = M3[[timeSeries[i]]]$x
  # Define the origins for cross-validation 
  # (origins: periods from where the forecasts will be produced)
  origins = 8:(length(y)-8)
  # Define the forecast horizon
  horizon = 8
  no_methods = 10
  
  # define a matrix that will hold the point forecasts for all methods
  FCs = array(0, c(length(origins), horizon, no_methods))
  actuals = array(0, c(length(origins), horizon))
  
  # for-loop to run all the methods
  decompCut = na.remove(decompose(y,type="m")$trend)
  
  decSeason = decompose(y,type="m")$seasonal
  decSeasonAdjustment = decSeason[(length(decSeason)-7):length(decSeason)]
  
  for (origin in origins){
    inSample1 = ts(y[1:origin], frequency=4)
    decSample = ts(decompCut[1:origin], frequency=4)
    decSeasonCoef = decSeason[(length(decSample)+1):(length(decSample)+8)]
    actuals[which(origin==origins), ] = y[(origin+1):(origin+8)]
    for (m in 1:no_methods){
      FCs[which(origin==origins), , m] = toolbox(i,inSample1,decSample,decSeasonCoef,m,origin,horizon,useRules = TRUE,checkArimas = TRUE)
    }
  }
  LARsOrigin = array(0,c(length(origins),no_methods))
    # for-loop to calculate the MAPE for each method
    for (m in 1:no_methods){
      # calculate the MAPE for method m and save to the respective place of vector MAPEs
      for (k in 1 : length(origins)){
        FCs[FCs<=0] = 0.001
        FCs[is.na(FCs)] = 0.001
        LARsOrigin[k,m] = sum((log(FCs[k,,m]/actuals[k,]))^2)
      }
      
      #calculate weighted log accuracy ratio
      calcArray = array(0,c(length(LARsOrigin[,m]),3))
      calcArray[,1] = LARsOrigin[,m]
      calcArray[,2] = 1:length(LARsOrigin[,m])
      calcArray[,3] = calcArray[,1]*calcArray[,2]
      LARs[i,m] = sum(calcArray[,3])/sum(calcArray[,2])
    }
}

#Create table with best model for each timeseries
for (i in 1:length(timeSeries)){
  chosenModel[i,2] = which(LARs[i,]==min(LARs[i,]))[1]
  chosenModel[i,3] = min(LARs[i,]) #(tofallis 2015)

}


############ STEP 3 Forecast test data using selected time Series ###############

#set benchmarks to compare chosen model against
benchmarks = c("naive","MAPA","autoETS")
noBenchmarks = length(benchmarks)
# define a matrix that will hold the point forecasts for all methods
horizon = 8
finalFCs = array(0, c(length(timeSeries),horizon,noBenchmarks+1))
finalActuals = array(0, c(length(timeSeries), horizon))

for (i in 1:length(timeSeries)){
  #define data and decomposed data
  y = M3[[timeSeries[i]]]$x
  q = decompose(M3[[timeSeries[i]]]$x, type ="m")
  z = na.remove(q$trend)
  
  #take last 10 as trend will have to forecast 10 to get test 8. aligns to correct period as 2extra account for 2 missed.
  zSeason = q$seasonal[(length(z)-9):length(z)]
  finalActuals[i,] = M3[[timeSeries[i]]]$xx

  # Define the forecast horizon and origin (the last data point)
  horizon = 8
  origin = length(y)
  no_methods = 10
  reqDeason = c(2,3,6,7,8,9,10)
  
  if (chosenModel[i,2] %in% reqDeason){
    origin = length(z)
    horizon = horizon +2
  } else {
    origin = length(y)
  }
  finalFCs[i,,1] = toolbox(i,y,z,zSeason,chosenModel[i,2],origin,horizon,useRules=FALSE, checkArimas = FALSE, justToolbox = FALSE)[(horizon-7):horizon]
  
  #No decomposition for benchmarks so reset origin and horizon
  origin = length(y)
  horizon = 8
  for (j in 1:noBenchmarks){
    #forecast models based on benchmarks
    finalFCs[i,,(1+j)] = benchmarkbox(y,benchmarks[j],origin,horizon)
  }
}


#############PART C performance evaluation  ##################

#Set number of horizon categories and 
noMeasures = 3
noHorizons = 3

# define a vector where the the perfomance measures  for each method will be saved
finalPerfs = array(0, c(length(timeSeries),noBenchmarks+1,noMeasures))
horizonedPerfs = array(0, c(length(timeSeries),noBenchmarks+1,noHorizons))

# for-loop to calculate the perfomance measures for each method
for (ts in 1:length(timeSeries)){
  for (m in 1:(noBenchmarks+1)){
    #MAPE
    finalPerfs[ts,m,1] = 100*mean(abs(finalActuals[ts,] - finalFCs[ts,,m])/abs(finalActuals[ts,]))
    #log accuracy ratio
    finalPerfs[ts,m,2] = sum((log(finalFCs[ts,,m]/finalActuals[ts,]))^2)
    #MAAPE
    finalPerfs[ts,m,3] = mean(atan(abs(finalActuals[ts,] - finalFCs[ts,,m])/finalActuals[ts,]))
    
    #calculate the MAPEs at 3 horizons, short medium and long
    horizonedPerfs[ts,m,1] = 100*mean((abs(finalActuals[ts,] - finalFCs[ts,,m])/abs(finalActuals[ts,]))[1:2])
    horizonedPerfs[ts,m,2] = 100*mean((abs(finalActuals[ts,] - finalFCs[ts,,m])/abs(finalActuals[ts,]))[3:5])
    horizonedPerfs[ts,m,3] = 100*mean((abs(finalActuals[ts,] - finalFCs[ts,,m])/abs(finalActuals[ts,]))[6:8])
  }
}


## 1) Overall performance

genPerfs = data.frame(0, c(noBenchmarks+1,noMeasures))
par(mfrow=c(1,3))
par(mar=c(3,2,2,0.5),oma = c(1,2,1,1))
xaxlabels = c("MAPE", "Log Accuracy Ratio", "MAAPE")
for (b in 1:noMeasures){
  for (m in 1:4){
    genPerfs[b,m] = mean(finalPerfs[,m,b])
  }
  boxplot(finalPerfs[,,b])
  
  for (m in 1:4){
    text(m, 0.75*max(finalPerfs[,,b]), label = round(mean(finalPerfs[,m,b]),3), col = "blue")
    text(m, 0.72*max(finalPerfs[,,b]), label = round(median(finalPerfs[,m,b]),3), col = "red", cex = 0.95)
    points(m, finalPerfs[70,m,b], cex = 1.5, col = "darkgreen")
    points(m, finalPerfs[64,m,b], cex = 1.5, col = "green", pch = 0)
    points(m, finalPerfs[37,m,b], cex = 1.5, col = "lightgreen", pch = 2)
  }
  mtext(text=xaxlabels[b],side=1, line =2.2,cex = 0.8)
}



## 2) horizon performance 
horizLabs = c("1-2 Qs", "2-5 Qs", "6-8 Qs")
par(mfrow=c(1,3))
par(mar=c(3,1.7,2,0.5))
for (i in 1:3){
  if(i==1){ yaxt = 's'} else { yaxt = 'n'}
  boxplot(horizonedPerfs[,,i], ylim = c(0,130), yaxt = yaxt)
  mtext(text=horizLabs[i],side=1, line =2.2,cex = 0.8)
  if(i==1){ mtext(text="MAPE",side=2, line =2,cex = 0.8)}
  for (m in 1:4){
    text(m, 95.5, label = round(mean(horizonedPerfs[,m,i]),2), col = "blue")
    text(m, 92, label = round(median(horizonedPerfs[,m,i]),2), col = "red", cex = 0.95)
    points(m, horizonedPerfs[70,m,i], cex = 1.5, col = "darkgreen")
    points(m, horizonedPerfs[64,m,i], cex = 1.5, col = "green", pch = 0)
    points(m, horizonedPerfs[37,m,i], cex = 1.5, col = "lightgreen", pch = 2)
  }
  for (j in 1:3){
    for (k in 2:4){
      chisq = chisq.test(horizonedPerfs[,c(j,k),i])
      if ((j != k) & (chisq$p.value < 0.05)){
        text(mean(c(j,k)), 105.3+3.5*j+3.5*k, label = "*", cex=3)
        lines(c(j,k), c(105+3.5*j+3.5*k,105+3.5*j+3.5*k))
      } else {
        lines(c(j,k), c(105+3.5*j+3.5*k,105+3.5*j+3.5*k), col = "red" , lty = 3)
      }
    }
  }
}

#check other chisq values between horizons/methods
chisq = chisq.test(horizonedPerfs[,1,c(2,3)])
chisq

## 3) performance by dataType
par(mfrow=c(1,length(dataTypes)-1))
for(i in 1:5){
  if(i==1){ yaxt = 's'} else { yaxt = 'n'}
  boxplot(finalPerfs[which(detailArray[,2] == dataTypes[i]),,1], yaxt = yaxt, ylim = c(0,85))
  if(i==1){ mtext(text="MAPE",side=2, line =2,cex = 0.8)}
  which(detailArray[,2] == dataTypes[1])
  text(2.5, 75, label = paste("Count = ", length(finalPerfs[which(detailArray[,2] == dataTypes[i]),,1])), cex = 1)
  mtext(text=dataTypes[i],side=1, line =2.2,cex = 0.8)
  
  text(1.8, 84, label = "1", col = "black")
  text(3.2, 84, label = "2:4", col = "black")
  text(1.8, 78, label = round(median(finalPerfs[which(detailArray[,2] == dataTypes[i]),1,1]),2), col = "red", cex = 0.95)
  text(1.8, 81, label = round(mean(finalPerfs[which(detailArray[,2] == dataTypes[i]),1,1]),2), col = "blue")
  text(1.8, 78, label = round(median(finalPerfs[which(detailArray[,2] == dataTypes[i]),1,1]),2), col = "red", cex = 0.95)
  text(3.2, 81, label = round(mean(finalPerfs[which(detailArray[,2] == dataTypes[i]),c(2,3,4),1]),2), col = "blue")
  text(3.2, 78, label = round(median(finalPerfs[which(detailArray[,2] == dataTypes[i]),c(2,3,4),1]),2), col = "red", cex = 0.95)
  
  if (detailArray[70,2] == dataTypes[i]){
    for (m in 1:4){ points(m, finalPerfs[70,m,1], cex = 1.5, col = "darkgreen")}}
  if (detailArray[37,2] == dataTypes[i]){
    for (m in 1:4){ points(m, finalPerfs[37,m,1], cex = 1.5, col = "lightgreen", pch = 2)}}
  if (detailArray[64,2] == dataTypes[i]){
    for (m in 1:4){ points(m, finalPerfs[64,m,1], cex = 1.5, col = "green", pch = 0)}}
      
    }


## 4) ts characteristics
par(mfrow=c(5,2))
par(mar=c(1,1,1,1))


for(j in c(3,5:8)){
  for (i in 0:1){
    if(i==0){ yaxt = 's'} else { yaxt = 'n'}
    if(j==9){ xaxt = 's'} else { xaxt = 'n'}
    if (i %in% detailArray[,j]){
      boxplot(finalPerfs[c(which(detailArray[,j] == i), which(detailArray[,j] == (i*2))),,1], ylim = c(0,80), yaxt = yaxt, xaxt = xaxt)
      if(i==0){mtext(text=dataPatterns[(j-2)],side=2, line =2.2,cex = 0.8)}
      for (k in 1:4){
        text(k, 60, label = round(mean(finalPerfs[which(detailArray[,j] == i),k,1]),1), cex = 0.9, col = "blue")
       # text(k, 57, label = round(median(finalPerfs[which(detailArray[,j] == i),k,1]),1), cex = 0.8, col = "red")
      }
      text(2.5, 72, label = paste("Count = ", length(finalPerfs[which(detailArray[,j] == i),1,1])), cex = 1)
    } 
  }
}

## 5) MAPE performance by model
par(mfrow=c(1,1))
plot(chosenModel[,2], finalPerfs[,2,1], xlim= c(1,10), xaxp  = c(0, 10, 10))
for (i in 1:10){
  if (i %in% chosenModel[,2]){
  text(i+0.015, median(finalPerfs[which(chosenModel[,2] == i),2,1]), label = "-", col = "blue", cex = 3)
  }
}
mtext(text="MAPE",side=2, line =2,cex = 0.8)
mtext(text="Performance by model",side=3, line =0.5,cex = 1.2)
mtext(text="Model number",side=1, line =2,cex = 0.8)

finalTable = data.frame(detailArray, finalPerfs[,1,1],chosenModel[,2])
colnames(finalTable) = c("TS", "Type", dataPatterns, "MAPE", "model")
write.table(finalTable, "c:/users/samth/Documents/finalTable.txt", sep="\t")   


## 6) poorly performing models
MAPEvNaive = finalPerfs[,1,1] - finalPerfs[,2,1]

par(mfrow=c(2,5))
par(mar=c(2,0.5,2,0.5),oma = c(1,2,1,1))
for (i in 1:5){
  if(i==1){ yaxt = 's'} else { yaxt = 'n'}
  tsNoB = which(MAPEvNaive %in% (head(sort(MAPEvNaive),5)))
  if(i==5){ylim = c(0,22000)} else {ylim = c(0,12000)}
  plot(M3[[chosenModel[tsNoB,1][i]]], yaxt = yaxt, ylim = ylim)
  
  time1 = time(M3[[chosenModel[tsNoB,1][i]]]$xx)
  lines(ts(finalFCs[tsNoB[i],,1], start = time1[1], frequency = 4), col = "blue")
  lines(ts(finalFCs[tsNoB[i],,2], start = time1[1], frequency = 4), col = "green")
}

for (i in 1:5){
  if(i==1){ yaxt = 's'} else { yaxt = 'n'}
  tsNo = which(MAPEvNaive %in% (tail(sort(MAPEvNaive),5)))
  if(i==5){ylim = c(0,22000)} else {ylim = c(0,12000)}
  plot(M3[[chosenModel[tsNo,1][i]]], yaxt = yaxt, ylim = ylim)
  
  time1 = time(M3[[chosenModel[tsNo,1][i]]]$xx)
  lines(ts(finalFCs[tsNo[i],,1], start = time1[1], frequency = 4), col = "blue")
  lines(ts(finalFCs[tsNo[i],,2], start = time1[1], frequency = 4), col = "green")
}




############RESIDUAL DIAGNOSTICS

chosenModel[which(chosenModel[,1]==1207),2] = 3
chosenModel[which(chosenModel[,1]==1217),2] = 9 
chosenModel[which(chosenModel[,1]==1227),2] = 2

#set data
y = M3[[1227]]$x
q = decompose(y, type ="m")
decompSampleR = na.remove(q$trend)

#run models
#Algorithm chosen models:
ses = ets(decompSampleR, model="ANN")
dotm = dotm(decompSampleR)
holtLT = ets(decompSampleR, model="AAN", damped=FALSE)

#Comparitive models
autoETS = ets(decompSampleR)
lm = tslm(log10(decompSampleR)~trend)

resid = holtLT$residuals
resid = ses$residuals
resid = dotm$residuals
resid = autoETS$residuals
resid = lm$residuals

par(mfrow=c(1,1))
#linearity - residual plot

#residuals against fitted values
plot(fitted(holtLT), residuals(holtLT), pch=0)

#residuals against time and ACF plot
par(mfrow=c(2,2))
par(mar=c(2,1,1,1))
plot(resid, ylab="Residuals",xlab="Year")
mtext(text="Residuals Vs Time",side=3, line =0.2,cex = 1)
abline(0,0)

### heterskedasticity
BP = bptest(lm(resid~time(resid)))$p.value
text(1986,0.75*max(resid), label = paste("BP (p =", round(BP,3),")"),cex=0.7)

Acf(resid)
mtext(text="ACF of residuals",side=3, line =0.2,cex = 1)

#dwtest to consider autocorrelation/independence of residuals
DW = dwtest(lm(resid~time(resid)), alt="two.sided")$p
text((length(resid)/4),0.4, label = paste("DW p value =", round(DW,3)),cex=0.7)


####Normality
#Histogram of residuals
hist(resid,xlab="Residuals", prob=TRUE)
# Compare with normal distribution
min(resid)
lines(min(resid):max(resid), dnorm(min(resid):max(resid), 0, sd(resid)), col="red")

#normal probability plot; straight line?
a = qqnorm(resid)
qqline(resid, col="red")

#Shapiro test for normality
SH = shapiro.test(resid)$p.value
text(-1.0, 0.75*(max(a$y)), label = paste("Shapiro p value =", round(SH,3)),cex=0.7)






######## Model Residual correlation matrix plot
##toolbox run on a reduced sample with only one origin to identify similarity between models
#uses only in-sample data, not test data
##Used for relationship matrix graph
timeSeriescut = seq (707,1400,10)

#set validation sample - 1 origin being 8 short of the in-sample data
validationSample = array(0,c(length(timeSeriescut),8))
for(i in 1:length(timeSeriescut)){
  origin = length(M3[[timeSeriescut[i]]]$x) - 8
  validationSample[i,] = M3[[timeSeriescut[i]]]$x[(origin+1):length(M3[[timeSeriescut[i]]]$x)]
}

#Set array for forecasts
validationForecasts =  array(0, c(length(timeSeriescut),8,no_methods))

#for each timeseries, run one forecast
for(i in 1:length(timeSeriescut)){
  y = M3[[timeSeriescut[i]]]$x

  origins = length(M3[[timeSeriescut[i]]]$x) - 8
  origin = origins
  
  # Define the forecast horizon
  horizon = 8
  #run for all 20 methods
  no_methods = 20
  
  decompCut = na.remove(decompose(y,type="m")$trend)
  decSeason = decompose(y,type="m")$seasonal
  decSeasonAdjustment = decSeason[(length(decSeason)-7):length(decSeason)]

  inSample1 = ts(y[1:origin], frequency=4)
  decSample = ts(decompCut[1:origin], frequency=4)
  decSeasonCoef = decSeason[(length(decSample)+1):(length(decSample)+8)]
    for (m in 1:no_methods){
      validationForecasts[i, , m] = toolbox(i,inSample1,decSample,decSeasonCoef,m,origin,horizon, justToolbox = FALSE, useRules = FALSE, checkArimas = FALSE)
    }
}

#create array for errors for each method
valErrors =  array(0, c(length(timeSeriescut),8,no_methods))

#calculate relative errors for each time series for each method for 1 origin
for (i in 1:length(timeSeriescut)){
  for (m in 1:no_methods){
    valErrors[i,,m] = validationForecasts[i,,m]  - validationSample[i,]
  }
}

#create relationship matrix to hold correlation between errors/residuals for each time series
relationshipMatrix = array(0,c(no_methods,no_methods,length(timeSeriescut)))
#and one to hold the mean correlation for all timeseries
relationshipMatrixmean = array(0,c(no_methods,no_methods))

#for each timeseries calculate the correlation between each method and each other method
for (i in 1: length(timeSeriescut)){
  for (m in 1: no_methods){
    for (n in 1: no_methods){
      relationshipMatrix[m,n,i] = cor(valErrors[1,,m],valErrors[1,,n])
    }
  }
}

#calculate the mean correlations across time series
for (m in 1: no_methods){
  for (n in 1: no_methods){
    relationshipMatrixmean[m,n]= mean(relationshipMatrix[m,n,])
  }
}

#convert to data frame
data.frame(relationshipMatrixmean)

#plot as correlated plot                
par(mfrow=c(1,1))
install.packages("corrplot")
library(corrplot)
corrplot(relationshipMatrixmean, type = "upper", order = "hclust", 
        tl.col = "black", tl.srt = 45)


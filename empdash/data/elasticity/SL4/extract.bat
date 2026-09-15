@echo off
setlocal EnableDelayedExpansion
set NAME=%~n1
if not exist csv mkdir csv
echo XLAO xlab_o> xlab.map
sltoht -map=xlab.map %NAME%.sl4 %NAME%_xlab.har > nul 2>&1
if exist %NAME%_52.har del %NAME%_52.har
agghar %NAME%_xlab.har %NAME%_52.har supp52.har -P > nul 2>&1
head2csv %NAME%_xlab.har XLAO %NAME%_58.csv > nul 2>&1
head2csv %NAME%_52.har XLAO %NAME%_52.csv > nul 2>&1
set /p HDR=<%NAME%_52.csv
set HDR=!HDR:,P=,!
set HDR=!HDR:xlab_o=!
> csv\eta_%NAME%.csv echo !HDR!
more +1 %NAME%_52.csv >> csv\eta_%NAME%.csv
if exist csv\eta_%NAME%.csv (echo OK csv\eta_%NAME%.csv) else (echo FAILED %NAME%)
endlocal

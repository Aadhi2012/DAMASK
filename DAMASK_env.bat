:: sets up an environment for DAMASK on windows
:: usage:  ????
@echo off
chcp 1252
Title D�sseldorf Advanced Materials Simulation Kit - DAMASK, MPIE D�sseldorf

SET DAMASK_ROOT=%HOME%\DAMASK                                                                     
SET DAMASK_BIN=%DAMASK_ROOT%\bin
SET PYTHONPATH=%PYTHONPATH%:%DAMASK_ROOT%\lib
SET DAMASK_NUM_THREADS=2



echo.
echo D�sseldorf Advanced Materials Simulation Kit - DAMASK
echo Max-Planck-Institut f�r Eisenforschung, D�sseldorf
echo http://damask.mpie.de
echo.
echo Preparing environment ...
echo DAMASK_ROOT=%DAMASK_ROOT%
echo DAMASK_NUM_THREADS=%DAMASK_NUM_THREADS%



%% Simulator Launcher File
% launches time division duplex (TDD) scenario

%%
clc; close all; clear;


%% Launch Simulation
% Get simulation parameters
simuParams = scenarios.scenarioTimeDivisionDuplex();

% Invoke the ISAC simulator
[senResults, senRMSE, comResults] = simulation.isacSimulation(simuParams);

% Plot topology
networkTopology.plotTopology(simuParams.bsParams, senResults)

% Get estimation RMSEs
senRMSE = sensing.postProcessing.getRMSE(estResults.MUSIC, rdrEstParams);

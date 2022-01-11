function pipetteResistance = measurePipetteResistance(exptInfo,type,varargin)
%{
MEASUREPIPETTERESISTANCE

Aquires a Trial of voltage data obtained when the seal test is on 
and then use to calculate the pipette (or seal resistance) and also saves
that trace obtains from the recording

By default (set in acquireTrial) this will run of the time period specified by: 
settings.sealTest.Dur

INPUT
exptInfo (struct)
type 'pipette' or 'seal' (String)

OUTPUT
pipetteResistance (MOhms)

%}
[data,trialMeta] = acquireTrial(); 

% logical array for when voltage is above the mean
highVoltageLog1 = data.voltage > mean(data.voltage);

%steps 'up' from 0 to 1 find all of the starts of the pulse
allPulseStarts = strfind(highVoltageLog1',[0 1]);
pulseStart = allPulseStarts(1) + 1;

% steps 'down' from 1 to 0 to find all of the ends of pulse 
allPulseEnds = strfind(highVoltageLog1',[1 0]);
pulseEnd = allPulseEnds(1);

if pulseEnd < pulseStart
    pulseEnd = allPulseEnds(2);
end

pulseEnd = pulseEnd - 3;
pulseMid = round(pulseEnd - ((pulseEnd - pulseStart)/2));

troughStart = pulseEnd + 1;
troughEnd = allPulseStarts(2) -3 ;
troughMid = round(troughEnd - ((troughEnd - troughStart)/2));

peakCurrent = mean(data.current(pulseMid:pulseEnd));
peakVoltage = mean(data.voltage(pulseMid:pulseEnd));
baselineCurrent = mean(data.current(troughMid:troughEnd));
baselineVoltage = mean(data.voltage(troughMid:troughEnd));

voltDiff = peakVoltage - baselineVoltage; % delta voltage 
currDiff = peakCurrent - baselineCurrent; % delta current

VOLTS_PER_MiliVOLTS = 1e-3; % V /1000 mV
AMPS_PER_pA = 1e-12; % 1e-12 A / 1 pA
MEGAOHM_PER_OHM = 1e-6; % 1 MOhm / 1e6 Ohm

%calculates pipette resistance using change in Voltage and change in Current
pipetteResistance = ((voltDiff*VOLTS_PER_MiliVOLTS)/(currDiff*AMPS_PER_pA))*MEGAOHM_PER_OHM;  %(MOhms)

if nargin ~= 0
    [~, path, ~, idString] = getDataFileName(exptInfo);
    switch type
        case 'pipette'
            filename = [path,'\preExptTrials\',idString,'pipetteResistance'];
        case 'seal'
            filename = [path,'\preExptTrials\',idString,'sealResistance'];
    end
    save(filename,'data','exptInfo','trialMeta');
end




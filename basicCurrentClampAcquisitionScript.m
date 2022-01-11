% basicCurrentClampAcquisitionScript
% 
% simple aquisition script for aquiring electrophysiology data from 700B
% amplifier and NiDAQ card
%
% Yvette Fisher 1/2022
%% Input trial information and set up NiDAQ session object
clear all; close all

% trial information flyNum, trialNum... - TODO
settings.durSeconds = 60; % trial duration (seconds)

% I-Clamp settings
trialMeta.mode = 'I-Clamp Normal';


% Save Mulitclamp gain settings
settings.membranePotentialGain = 10; % 10mV/mV   % Units?
settings.membraneCurrentGain = 0.5; % 0.5V/nA
MiliVOLTS_PER_VOLT = 1000; % 1000 mV/V  
PICOAMP_PER_NANOAMP = 1000; % 1000 pA/nA

% Aquisition settings
settings.devID = 'Dev1'; % Device string for NI PCIe-6351
settings.sampRate  = 20e3; % Samp Rate in Hz, make sure this is 2x > filtering

% Setup daq session
nidaq = daq("ni"); % create daq object
nidaq.Rate = settings.sampRate; % set aquisition rate
addinput(nidaq, settings.devID, "ai0", "Voltage"); % add primary channel
addinput(nidaq, settings.devID, "ai1", "Voltage"); % add secondary channel

% nidaq.Channels(1).TerminalConfig = 'SingleEnded'; % save information that channel is in single ended on BOB
% nidaq.Channels(2).TerminalConfig = 'SingleEnded'; % save information that channel is in single ended on BOB

%% add in logic for current injection patterns

%output = makeInjectionWaveform( inputs...)

%% Atehsa added...Current clamp analysis from WinWCP
function [input_output_curve, varargout] = io_curve(normalised_io_data,...
    time, current_injections_norm_vector, range_to_average, pA_inj_protocol_start, firing_threshold)             
%This function outputs the io curve. The first section will average over the
%specified range for every trace in the file. This will include traces prior to the
%desired current injection protocol and after the cell has started spiking.
%The first injection of the current injection protocol and threshold over which the
%cell is considered spiking are taken as user input, with defaults hard-coded below.
%The second section of the function cuts down this initially trace, removing all data
%points prior the start of the current injection and after the cell starts spiking.
%However, if there are any errors in the current injection information for example,
%the function will break and only output the io curve from all records, requiring it
%to be cut down manually. 
%vargout{1} = input_output_curve_cut
%varargout{2} = rheobase_record
%varargout{3} = stim_start
%varargout{4} = plotting_index
%Takes optional user inputs - sets default if empty
pA_inj_protocol_start = str2num(pA_inj_protocol_start{1,1});
    if isempty(pA_inj_protocol_start) 
       pA_inj_protocol_start = -60; %Default
    end
    
firing_threshold = str2num(firing_threshold{1,1});
    if isempty(firing_threshold) 
       firing_threshold = 50; %Default
    end
%Outputs I/O curve with average data points over specified range_to_average
for k = 1:size(normalised_io_data,2)
    input_output_curve(k,2) = current_injections_norm_vector(k,1);
    input_output_curve(k,3) = mean(normalised_io_data([range_to_average,k],k));
    input_output_curve(k,1) = k;
end
%Creatse Index used by the plot_records function - includes min and max time + Vm
for k = 1:size(input_output_curve, 1)
    plotting_index{k,1} = k;
    plotting_index{k,2}{1,1}(1,1) = normalised_io_data(min(range_to_average),k);
    plotting_index{k,2}{1,1}(1,2) = normalised_io_data(max(range_to_average),k);
    plotting_index{k,2}{1,1}(2,1) = time(min(range_to_average),1);
    plotting_index{k,2}{1,1}(2,2) = time(max(range_to_average),1);
  
end
%% Optional Function - cut off Vm measurements before start of pA injections and after spiking starts
try %try-catch entire statement - will break if varargins are not given
%First index all records prior to first pA injection - Note! this assumes the first
%pA injection of the specified starting value is the start of the pA injections. If
%there are multiple pA injections at the pA starting value, this will index from the
%first one. 
stim_start = find(input_output_curve(:,2) == pA_inj_protocol_start, size(input_output_curve,1),'first'); 
%Find the first record in which the cell fires 
for k = 1:size(normalised_io_data, 2) %takes peak of every traces
    peak_of_trace(k,1) = max(normalised_io_data(:,k));
    peak_of_trace(k,2) = k;
end
for k = 1:(stim_start-1) %makes all records prior to pA injections starting 0 in case firing is seen here
    peak_of_trace(k,1) = 0;
end
j0 = (find(abs(peak_of_trace(:,1)) > firing_threshold , size(peak_of_trace,1),'first'))-1; %finds the record before the record containging the first spike 
rheobase_record(1,1) = j0(1,1)+1; %rheobase
rheobase_record(1,2) = current_injections_norm_vector(j0(1,1)+1,1);
%Cuts off all traces before stim_start and after after spiking has started. 
input_output_curve_cut(:,1) = input_output_curve(stim_start:(j0(1,1)),1); 
input_output_curve_cut(:,2) = current_injections_norm_vector(stim_start:(j0(1,1)),1);
input_output_curve_cut(:,3) = input_output_curve(stim_start:(j0(1,1)),3);
%cut out excess traces from plotting index
for k = 1:(stim_start(1, 1))-1
    plotting_index{k,1} = [];
    plotting_index{k,2} = [];
end
for k = size(input_output_curve_cut,1)+stim_start(1, 1):size(input_output_curve)
    plotting_index{k,1} = [];
    plotting_index{k,2} = [];
end
catch
    disp('error on optional outputs');
end
varargout{1} = input_output_curve_cut;
varargout{2} = rheobase_record;
varargout{3} = stim_start;
varargout{4} = plotting_index;
end



%% Aquire trial
data = read(nidaq, seconds(settings.durSeconds));


%% Plot recorded I-Clamp data
figure; %create figure
set(gcf, 'Color', 'w'); % set figure border to white
title ('Current clamp plot')

ax(1) = subplot(2,1,1); % create first plot region and asign axes handle (top)
voltage_mV = (data.Dev1_ai0*MiliVOLTS_PER_VOLT) / settings.membranePotentialGain; % mV
plot( data.Time, voltage_mV);
ylabel('membrane potential (mV), primary')
box off

ax(2) = subplot(2,1,2); % create second plot region and asign axes handle (top)
current_pA = (data.Dev1_ai1*PICOAMP_PER_NANOAMP) / settings.membraneCurrentGain; %pAmp
plot( data.Time, current_pA);
box off
ylabel('membrane current (pA), secondary'); %TOOD check these units

linkaxes(ax, 'x'); % link x-axis

 
% %% Save trial % TODO
% 
% % Data folder where you'd like to save the data
% dataDirectory = ''; % E.g. '/Users/evettita/Google Drive/EphyData/'
% 
% %save() 



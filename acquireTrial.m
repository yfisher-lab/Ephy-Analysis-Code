function [data, trialMeta] = acquireTrial(stimulus, exptInfo , preExptData, trialMeta , varargin)
%AQUIRETRIAL  Runs and Records trials from the amplifier and runs input stimluli
%
% This is the main aquisition function within the ephy recording setting
% It sets up a session with the NiDAQ aquisition system, which both triggers
% any external stimulus hardware (Odor valves, Visual Panel system)
% And also stores incoming data from the NiDAQ as the trial occurs
% At the end of the trial the data is save to the PC
% 
% INPUT
% stimulus = Struct that contains the information about the parameters and
% the array for injection command
% 
% OUTPUT
% 
% SAVED:
% data 
% stimulus
% trialMeta
% exptInfo
% 
% Yvette Fisher 8/2016, updated 2/2017, updated for 700b 1/2022
fprintf('\n*********** Acquiring Trial ***********\n' ) 
% load ephy settings
ephysSettings;

% Determine trial duration and build default stimulus command 
if exist('stimulus','var')
    trialDurSec = length(stimulus.command) / rigSettings.sampRate; % sec

else
    trialDurSec = rigSettings.defaultTrialDur; % sec

    % Create a default and empty command signal if one was not specified:
    stimulus.command = zeros( 1, rigSettings.defaultTrialDur * rigSettings.sampRate );
    stimulus.name = 'No Stimulus';
end


%% Set up DAQ session
nidaq = daq("ni"); % create daq object
nidaq.Rate = rigSettings.sampRate; % set aquisition rate
addinput(nidaq, rigSettings.devID, "ai0", "Voltage"); % add primary channel
addinput(nidaq, rigSettings.devID, "ai1", "Voltage"); % add secondary channel

addoutput(nidaq, rigSettings.devID,"ao0","Voltage"); % output channel for current or voltage injection command

% Because default is 'differential' this needs to be set explicitly
nidaq.Channels(1).TerminalConfig = 'SingleEnded'; % Set channel to single ended on BOB
nidaq.Channels(2).TerminalConfig = 'SingleEnded'; % Set channel to single ended on BOB

%% Build output array
% Specify scan data as an MxN double matrix, where M is the number of scans and N is the number of output channels.
outputMatrix = stimulus.command'; %each commmand needs to be a collumn vector

outputMatrix = makeFinalSignalsZerosForAllCommandChannels( outputMatrix ); 
% Note: DAQRESET does not reset the data acquisition hardware. It resets
% the DAQ Engine so this is needed to make sure the outputs returns to zero

% TODO add more logic here to combine other arrays as more output signals are needed.....

%% Aquire data (read and write in forground)
trialMeta.trialStartTime = datestr(now,'HH:MM:SS'); % record Trial time for record

rawData = readwrite(nidaq, outputMatrix);

%% Process and scale data
% code assumes that all modes of Multiclamp 700b have primary=membrane current & secondary=membrane potential
data.current = rawData.Dev1_ai0 * rigSettings.current.softGain_pA; % convert to pA
data.voltage = rawData.Dev1_ai1 * rigSettings.voltage.softGain_mV; % convert to mV

%% %% Process X and Y stimulus information from the Panel system
% % AND save the ficTrac ball position information for later
% if ( isfield( stimulus, 'panelParams') )
%     % stop the stimulus now and turn off the LEDs incase any were still on
%     Panel_com('stop')
%     Panel_com('all_off'); 
%     % Turn off having panel waiting for external trigger from amp to start
%     Panel_com('disable_extern_trig');
%     
%    % get channel index from ephysettings
%    xPosIndex = find(settings.bob.inChannelsUsed == settings.bob.panelDAC0X); % get index 
%    yPosIndex = find(settings.bob.inChannelsUsed == settings.bob.panelDAC1Y); % get index 
% 
%    data.xPanelVolts =  rawData (:, xPosIndex);
%    % Decode Xpos from voltage reading
%    data.xPanelPos = processPanelDataX ( data.xPanelVolts , stimulus.panelParams );
%    
%    data.yPanelVolts =  rawData (:, yPosIndex);
%    % Decode Ypos from voltage reading
%    data.yPanelPos = processPanelDataY ( data.yPanelVolts , stimulus.panelParams );
% end
% 
%    % Save FicTrac angular Position signal from DAQ/Virtual Machine
%    ficTracPosIndex = find( settings.bob.inChannelsUsed == settings.bob.ficTracAngularPosition); % get index
%    ficTracIntxIndex = find( settings.bob.inChannelsUsed == settings.bob.ficTracIntx); % get index
%    ficTracIntyIndex = find( settings.bob.inChannelsUsed == settings.bob.ficTracInty); % get index
%    
%    % if not closed loop trial this array might be empty/flat line, but that is fine
%    data.ficTracAngularPosition = rawData ( : , ficTracPosIndex);
%    data.ficTracIntx = rawData ( : , ficTracIntxIndex);
%    data.ficTracInty = rawData ( : , ficTracIntyIndex);

%% Save data if normal trial with stimulus (typically anything but seal test)
if nargin ~= 0
    % Get filename and save trial data
    [fileName, path, trialMeta.trialNum] = getDataFileName( exptInfo );
    fprintf(['\nTrial Number ', num2str( trialMeta.trialNum )])
    
    if ~isfolder(path)
        mkdir(path);
    end
    
    % save data, stimlulus command, and other info
     save(fileName, 'data','trialMeta','stimulus','exptInfo');
     disp( ['.... Trial # ' num2str( trialMeta.trialNum )   ' was Saved!'] );

    % Online plotting of data (doesn't plot seal test trials)
    plotTrialData( data, stimulus, rigSettings ); % plot the trial that was just aquired for the user to see
end

%% If there was a movie aquired then: %% Copy movies into trial folder within tmp video aqu.
 if ( isfield( stimulus, 'cameraTrigger') )
      copyFramesToTrialFolder( exptInfo, trialMeta );
 end

%% Pause code to view plots
% % make it so that the code pauses so I can look at the figure of data, but
% % only if we are NOT doing a the seal test where the stim is named No Stimulus
 if (~strcmp (stimulus.name, 'No Stimulus'))
    
%keyboard;
end

end


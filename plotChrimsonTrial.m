%%plotChrimsonTrial
% simple plotting script to display trace and when the light was on for
% chrimson stimulation
ephysSettings
FigHand = figure('Position',[50, 50, 1800, 300]);
set(gcf, 'Color', 'w');
timeArray = (1  :  length(data.current) ) / settings.sampRate; % seconds
% Shade in time points when the light was on
shutter =  stimulus.shutterCommand;
%shutter =  stimulus.command;
shutterOpenCloseFrames = find(  diff( shutter ) ~= 0);
shutterOpenCloseTimes = timeArray( shutterOpenCloseFrames );
xcord = sort( [shutterOpenCloseTimes shutterOpenCloseTimes] );
MIN_VOLTAGE_FOR_PLOT = -90;
ycord = MIN_VOLTAGE_FOR_PLOT * repmat([0 1 1 0], 1, (length(xcord) / 4) );
patch( xcord, ycord ,'g', 'FaceAlpha',1); hold on
voltage = data.scaledVoltage; % for current clamp traces
%voltage = data.voltage;
% plot voltage trace
plot( timeArray, voltage, 'k'); hold on;
title('voltage');
xlabel('time(s)')
ylabel('mV');
box off
title( [ num2str(exptInfo.dNum) ' fly#: ' num2str(exptInfo.flyNum) ' cell#: '  num2str(exptInfo.cellNum) ' expt#: ' num2str(exptInfo.cellExpNum) ' trial#: ' num2str(trialMeta.trialNum)])
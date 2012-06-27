function [stim, stimInfo] = loadWavAndCompensate(sweepNum, grid, expt)
% [stim, stimInfo] = loadWavAndCompensate(sweepNum, grid, expt)
%
% Load a wav file and compensate using however many compensation
% filters are available. The correct stimulus files are found by
% finding experiment parameters in the grid and expt structures, and 
% using constructStimPath to replace % tokens with appropriate values
% (sweepNum, etc)
% 
% sweepNum, grid, expt: standard benWare variables

fprintf(['  * Loading stimulus ' num2str(sweepNum) '...']);

% generate stimInfo structure
stimInfo.sweepNum = sweepNum;
stimInfo.stimGridTitles = grid.stimGridTitles;
stimInfo.stimParameters = grid.randomisedGrid(sweepNum, :);
stimInfo.stimFile = constructStimPath(grid, expt, sweepNum);

% load the stimulus
uncalib = wavread(stimInfo.stimFile);

% compensate and apply level offset
for chan = 1:length(grid.compensationFilters)
	stim(chan, :) = conv(uncalib, grid.compensationFilters{chan});
	stim(chan, :) = stim(chan, :) * 10^(grid.stimLevelOffsetDB(chan) / 20);
end

fprintf(['done after ' num2str(toc) ' sec.\n']);


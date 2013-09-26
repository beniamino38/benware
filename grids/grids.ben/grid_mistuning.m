function grid = grid_mistuning()
% grid_mistunings() -- defines Astrid's mistuning stimuli
%   Usage: 
%      grid  = grid_mistunings()
%   Outputs:
%      grid    return a benware(TM) grid with Astrid's mistuning stimuli permuted over the desired iterations
%
% Author: stef@nstrahl.de
% Version: $Id: grid_mistunings.m 109 2013-08-12 00:20:42Z stefan $

[status,hostname] = system('hostname');          % get name of host benware is currently running on

% controlling the sound presentation
grid.sampleRate                 = 24414.0625*4;  % ~100kHz, a sampling frequency the TDT System 3 Sigma Delta D/A converter can do
grid.stimGenerationFunctionName = 'loadStimAndCompensate';

% update the number after 'Mistuning' in the next line every penetration
grid.stimFilename               = 'Astrid_Mistuning_3_Set_%1.f32';

switch strtrim(hostname)
    case {'ATWSN647','schleppi'}
        grid.stimDir            = '../Stimuli/';
    otherwise
        grid.stimDir            = 'e:\auditory-objects\sounds-uncalib\mistuning\';        
end


% stimulus grid structure
% TODO: get automatically how many stim wav files,at the moment it needs to be edited manually

% NOTE: level parameter will do "level_offset = level - 80; stim = stim * 10^(level_offset / 20)";
% TODO: ask Ben if this is the program logic that achieves level calibration by assuming "20*log10(sqrt(var(wav))./20e-6) == 80 (dB SPL)"
grid.stimGridTitles = {'Stim set', 'Level'};

if false
    fprintf('Calibration only!!!! Press a key to continue');
    pause;
    grid.stimFilename               = 'AstridCalibration_Mistuning_Set_%1.f32';
    grid.stimGrid       = createPermutationGrid(1, 80);
else
    grid.stimGrid       = createPermutationGrid(1:15, 80);
end    


% set this using absolute calibration
% stefan_note: this is used in "prepareStimulus.m" doing "stim = stim * 10^(grid.stimLevelOffsetDB / 20)"
% TODO: ask Ben if I understood it correctly and we need only one scalar value and no 2x1
%grid.stimLevelOffsetDB = [0 0]-25; % can the two identical values be replaced by
grid.stimLevelOffsetDB = -16;      % just one scalar value?

% compensation filters
grid.initFunction = 'loadCompensationFilters';
switch strtrim(hostname)
    case {'ATWSN647','schleppi'}
        grid.compensationFilterFile = '../calibration/compensationFilters.100k.mat';
    case 'ben'
        grid.compensationFilterFile = '/Users/ben/scratch/expt.42/calib.expt42/compensationFilters100k.mat';
    otherwise
        grid.compensationFilterFile = 'e:\auditory-objects\calibration\calib.ben.2013.04.27\compensationFilters.100k.mat';
end

grid.compensationFilterVarNames = {'compensationFilters.L', 'compensationFilters.R'};

% sweep parameters
grid.postStimSilence = 0;         % no need of silence between stimulus sets, WAV files have trailing inter stimulus interval
grid.repeatsPerCondition = 1;     % we need permutation between stimuli so it is done within the WAV files

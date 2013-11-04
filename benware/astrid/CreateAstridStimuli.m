function stim = CreateExperimentStimuli(settingsfile,compensationfilterfile)
% CreateExperimentStimuli() -- generates experiment stimuli as defined by settings
%   Usage:
%      err = CreateExperimentStimuli(settingsfile,compensationfilterfile)
%   Parameters:
%      settingsfile                     this file contains the Settings defining the experiment
%      compensationfilterfile           this file contains the two compensation filters (compensationfilter(1,:) is left, compensationfilter(2,:) is right) [optional]
%   Outputs:
%      stim        struct containing sound stimuli (stim(1).L,stim(1).R,stim(2).L,stim(2).R,...)
%
% Author: stef@nstrahl.de, astrid.klinge-strahl@dpag.ox.ac.uk
% Version: $Id: CreateExperimentStimuli.m 130 2013-11-03 14:07:07Z stefan $

stim = [];
t    = clock;                                    % get current time as vector [year month day hour minute seconds]
seed = round(sum(100*t));                        % let's use new random numbers each time and a integer seed to remember it better
rand('twister', seed);                           % use Mersenne Twister pseudo-random number generator

if isempty(settingsfile)                         % if we are called within benware this will be empty and we ask online for the name
    settingsfile_default = sprintf('SettingsMistuned%d_%02.0f_%02.0f.m',t(1),t(2),t(3));
    settingsfile = input(['Please enter the name of the settings file if [' settingsfile_default '] is not correct, else <return>: ']);
    if isempty(settingsfile)                     % did we get just a return then use the offered default
        settingsfile = settingsfile_default;
    end
end
fprintf('Loading settings from %s...\n',settingsfile);

complex = []; % Matlab WTF - otherwise tries to call complex() from toolbox???
freqs = []; % Matlab WTF 2nd

run(settingsfile);                               % load settings

fid = fopen([logfile_directory 'CreateExperimentStimuli.log'],'a');    % open logfile in assigned directory
fprintf(fid,'%d-%02.0f-%02.0f %02.0f:%02.0f:%02.0f - CreateExperimentStimuli started using %s\n',t(1),t(2),t(3),t(4),t(5),t(6),settingsfile);
fprintf(fid,'  random_seed = %1.0f;\n',seed);      % store which random seed was used

switch settings_parser
    case 'CalibrationMistuned'
        fprintf(fid,'  frequency = %1.0f;',frequency);          % store frequency of calibration pure tone (Hz)
        fprintf(fid,'  stim_length = %1.0f;',stim_length);      % store duration of calibration pure tone (sec)
        fprintf(fid,'  level = %1.0f; % (dB SPL)',level);       % store level of calibration pure tone (dB SPL)
        amp = 20e-6*10.^(level/20);                             % convert dB SPL to amplitude
        fprintf(fid,'  amplitude = %f;\n',amp);                 % store amplitude of calibration pure tone

        if exist('compensationfilterfile','var')                % have we been called with a compensation filter
            [norm_left,norm_right,freq_bins_left,freq_bins_right] = get_normalized_compensations(compensationfilterfile);      % get the variables from an outsourced function that is executed below for both settings

            % interpolate power spectrum to get value at frequency Afreq
            Aamp_left  = amp * interp1(freq_bins_left, norm_left, frequency,'linear');
            Aamp_right = amp * interp1(freq_bins_right, norm_right, frequency,'linear');
        else
            Aamp_left  = amp;
            Aamp_right = amp;
        end

        stimuli{1}.command = 'gen_complex';
        stimuli{1}.parameters = sprintf('0,%f,1,%f,0,0,%f,%f',frequency,Aamp_left,stim_length, fs);
        stim(1).L = gen_waveform(stimuli);               % generate waveforms and return waveforms as a struct
        fprintf('DEBUG: max(abs(stim(1).L)): %1.3f mean: %1.3f stddev: %1.3f\n',max(abs(stim(1).L)),mean(stim(1).L),std(stim(1).L));
        stimuli{1}.parameters = sprintf('0,%f,1,%f,0,0,%f,%f',frequency,Aamp_right,stim_length, fs);
        stim(1).R = gen_waveform(stimuli);               % generate waveforms and return waveforms as a struct
        fprintf('DEBUG: max(abs(stim(1).R)): %1.3f mean: %1.3f stddev: %1.3f\n',max(abs(stim(1).R)),mean(stim(1).R),std(stim(1).R));
     case 'Mistuning'
        done = false;
        bestfrequency = [];
        while ~done
            in = input('Input the next BF, or <return> if there are no more: ');
            if isempty(in)
                done = true;
            else
                bestfrequency(end+1) = in;
                if length(bestfrequency) == 5
                    fprintf('Maximum of 5 best frequencies is reached\n')
                    done = true;
                end
            end
        end

        fprintf(fid,'  bestfrequency = [%s];',num2str(bestfrequency));   % store average BFs of each shank and recording site
        fprintf(fid,'  random_seed = %1.0f;',seed);                      % store which random seed was used
        fprintf(fid,'  F0s = [%s};',num2str(F0s'));                      % store current F0
        fprintf(fid,'  nharmonics = [%s];',num2str(nharmonics'));        % store number of components
        fprintf(fid,'  mistuned = [%s];',num2str(cell2mat(mistuned)));   % store which components of F0 to mistune
        fprintf(fid,'  freqshift = [%s];',num2str(freqshift));           % store mistunings to be applied
        fprintf(fid,'  level = %1.0f; % (dB SPL)\n',level);              % store level of calibration pure tone (dB SPL)
        amp = 20e-6*10.^(level/20);                                      % convert dB SPL to amplitude (Pascal)
        fprintf(fid,'  amplitude = %f;\n',amp);                          % store amplitude of calibration pure tone        
        fprintf(fid,'\n');                                               % return symbol

        if exist('compensationfilterfile','var') % have we been called with a compensation filter
            [norm_left, norm_right,freq_bins_left,freq_bins_right] = get_normalized_compensations(compensationfilterfile);     % get the variables from an outsourced function that is executed below for both settings
        end
        
        nsets = repetitions*length(F0s);         % save one file for each fundamental frequency
        n     = 0;                               % counter of current file
        for r=1:repetitions
            for f=1:length(F0s)                  % for each fundamental frequency
                n=n+1;
                fprintf('%s: Generate stimulus set %d out of %d\n',settings_parser,n,nsets);
                t   = clock;                               % get current time as vector [year month day hour minute seconds]
                stimuliL = struct([]);                      % generate an empty struct for left ear
                stimuliR = struct([]);                      % generate an empty struct for right ear

                s = 0;

                for b=1:length(bestfrequency)              % for each BF available at recording site
                    for m=1:length(mistuned{f})            % for each mistuned component
                        basefreq = bestfrequency(b) - F0s(f) * (mistuned{f}(m)-1);  % get basefreq that places mistuned component directly at the BF
                        basefreq = round(basefreq/F0s(f))*F0s(f);                   % we do harmonic complexes, quantize basefreq to be integer multiple of F0
                        if basefreq < F0s(f)               % is the BF of the current neuron to low
                            fprintf('skipped BF %1.1f Hz because too low and basefreq %1.1f < F0 %1.1f Hz\n',bestfrequency(b),basefreq, F0s(f));
                            continue;                      % then skip this mistuned component
                        end
                        %                         fprintf('BF:%d F0:%f mistuned:%d basefreq:%f\n',bestfrequency(b),F0s(f),mistuned{f}(m),basefreq);
                        for i=1:length(freqshift)
                            s=s+1;
                            stimuliL{s*2-1}.command = 'gen_complex';
                            stimuliR{s*2-1}.command = 'gen_complex';
                            shifts                  = zeros(1,nharmonics(f));
                            shifts(mistuned{f}(m))  = freqshift(i);
                            frequencies             = basefreq + (0:(nharmonics(f)-1))*F0s(f) + shifts;
                            if exist('compensationfilterfile','var')                % have we been called with a compensation filter
                                amps_left           = amp*interp1(freq_bins_left, norm_left, frequencies,'linear').*ones(1,nharmonics(f));
                                amps_right          = amp*interp1(freq_bins_right, norm_right, frequencies,'linear').*ones(1,nharmonics(f));
                            else
                                amps_left           = amp.*ones(1,nharmonics(f));
                                amps_right          = amp.*ones(1,nharmonics(f));
                            end

                            phases                    = zeros(1,nharmonics(f));
                            stimuliL{s*2-1}.parameters = sprintf('%f,%f,%d,[%s],[%s],[%s],%f,%f',F0s(f), basefreq, nharmonics(f), num2str(amps_left), num2str(shifts), num2str(phases), stim_length, fs);
                            stimuliL{s*2}.command      = 'gen_ISI';
                            stimuliL{s*2}.parameters   = sprintf('%s,%s',num2str(ISI),num2str(fs));
                            stimuliR{s*2-1}.parameters = sprintf('%f,%f,%d,[%s],[%s],[%s],%f,%f',F0s(f), basefreq, nharmonics(f), num2str(amps_right), num2str(shifts), num2str(phases), stim_length, fs);
                            stimuliR{s*2}.command      = 'gen_ISI';
                            stimuliR{s*2}.parameters   = sprintf('%s,%s',num2str(ISI),num2str(fs));
                        end % for i (each freqshift)
                    end % for m (each mistuned component)
                end % for b (each BF)
                if dopermute
                    permidx = randperm(s);                      % get random permutation
                    fprintf(fid,'permutation_sequence = [%s];\n',num2str(permidx)); % log which permutation was used
                    idx = [permidx *2-1; permidx *2];
                    stimuliL = stimuliL(idx(:));                % permute stimuli for left ear
                    stimuliR = stimuliR(idx(:));                % permute stimuli the same way for right ear

                end
                if isempty(stimuliL)                            % catch case where all components are below BF
                    n = n - 1;                                  % skip this set
                    continue
                end
                stim(n).L = gen_waveform(stimuliL);             % generate waveforms for left ear
                fprintf('DEBUG: max(abs(stim(%d).L)): %1.3f mean: %1.3f stddev: %1.3f\n',n,max(abs(stim(n).L)),mean(stim(n).L),std(stim(n).L));
                stim(n).R = gen_waveform(stimuliR);             % generate waveforms for right ear
                fprintf('DEBUG: max(abs(stim(%d).R)): %1.3f mean: %1.3f stddev: %1.3f\n',n,max(abs(stim(n).R)),mean(stim(n).R),std(stim(n).R));
            end % for f (each F0)
        end % for r (each repetiton)
    case 'CalibrationDRCVowel'
        fprintf(fid,'random_seed = %1.0f;\n',seed);             % store which random seed was used
        fprintf(fid,'complex = [%s];',num2str(complex'));
        fprintf(fid,'n_chord = %d',n_chord);
        fprintf(fid,'jitter = [%s]',num2str(jitter'));
        fprintf(fid,'freqs = [%s]',num2str(freqs));
        fprintf(fid,'chord_duration = %1.0f',chord_duration);
        fprintf(fid,'ramp_duration = %1.0f\n',ramp_duration);
        
        wave_drc = gen_drc(fs,freqs,levels,chord_duration,ramp_duration);
        if exist('compensationfilterfile','var')                % have we been called with a compensation filter
            fprintf('Applying compensation Filters...');
            load(compensationfilterfile);                       % get inverse filter as impulse response
            stim(1).L = filter(compensationFilters.L,1,wave_drc);
            stim(1).R = filter(compensationFilters.R,1,wave_drc);
            fprintf('done.\n');
        else
            stim(1).L = wave_drc;
            stim(1).R = wave_drc;
        end            
   case 'DRCvowel'
        fprintf(fid,'  random_seed = %1.0f;\n',seed);           % store which random seed was used
        fprintf(fid,'  %%% vowel settings %%%\n');
        fprintf(fid,'  stimlen = %1.0f;',stimlen);
        fprintf(fid,'  f0 = %1.0f;',f0);                        % store F0
        fprintf(fid,'  startvowel = [%s];',num2str(startvowel'));
        fprintf(fid,'  endvowel = [%s];',num2str(endvowel'));
        fprintf(fid,'  nsteps = %d;',nsteps);
        fprintf(fid,'  formants = %s;',num2str(formants));
        fprintf(fid,'  bandwidths = [%s];',num2str(bandwidths'));
        fprintf(fid,'  carriertype = %s;',carriertype);
        fprintf(fid,'  vowel_level = %1.0f;',vowel_level);
        vowel_amp = 20e-6*10.^(vowel_level/20);                 % convert dB SPL to amplitude (Pascal)
        fprintf(fid,'  vowel_amplitude = %f;\n',vowel_amp);     % store amplitude of calibration pure tone                
        fprintf(fid,'  vowel_position = [%s];\n',num2str(vowel_position'));
        fprintf(fid,'  %%% DRC settings %%%\n');
        fprintf(fid,'  complex = [%s];',num2str(complex'));
        fprintf(fid,'  n_chord = %d',n_chord);
        fprintf(fid,'  jitter = [%s]',num2str(jitter'));
        fprintf(fid,'  freqs = [%s]',num2str(freqs));
        fprintf(fid,'  chord_duration = %1.0f',chord_duration);
        fprintf(fid,'  ramp_duration = %1.0f\n',ramp_duration);

        if exist('compensationfilterfile','var')                % have we been called with a compensation filter
            load(compensationfilterfile);                       % get inverse filter as impulse response
        end            
        
        stim = [];
        for j = 1:size(jitter,1)     % for all jitter combinations
        fprintf('Jitter %d/%d: [%s]\n',j,size(jitter,1),num2str(jitter(j,:)));
        % generate random jittered frequencies and levels
            for b = 1:size(jitter,2)
                freqmat = repmat(complex',1,n_chord);
                randmat = ones(size(freqmat)) + (2*rand(size(freqmat))-1)*jitter(j,b);
                freqs_block{b} = freqmat.*randmat;
            end
            drc_freqs    = horzcat(freqs_block{:});
            drc_levels   = rand(length(complex),n_chord*size(jitter,2))*levels_range+levels_offset; % mean 50 dB with range [45,55] (=0..10+40) dB
            fprintf('Create DRC');
            wave_drc = gen_drc(fs,drc_freqs,drc_levels,chord_duration,ramp_duration);

            % generate Vowel
            wav = [];
            for f = 1:size(formants,2)
                for p = 1:length(vowel_position)
                    pos = round( (ramp_duration/2 + chord_duration*(n_chord + vowel_position(p))) * fs);

                    wave_vowel = gen_vowel(stimlen,vowel_amp,fs,f0,formants(:,f)',bandwidths,carriertype);
                    wav{end+1} = wave_drc;
                    wav{end}(pos:pos+length(wave_vowel)-1) = wav{end}(pos:pos+length(wave_vowel)-1) + wave_vowel;
                end % for p = 1:size(vowel_position)
            end % for f = 1:size(formants,2)
            temp = [wav{:}];
            if exist('compensationFilters','var')               % do we have compensation filter available?
                fprintf('Applying compensation Filters...');
                stim(end+1).L = filter(compensationFilters.L,1,temp);
                stim(end).R   = filter(compensationFilters.R,1,temp);
                fprintf('done.\n');
            else
                stim(end+1).L = temp;
                stim(end).R   = temp;
            end            
            clear temp;
        end % for j = 1:size(jitter,1)
    otherwise
        error('Unknown settings parser "%s"',settings_parser);
end % switch settings_parser

fclose(fid);

end % function CreateExperimentFiles

function [norm_left, norm_right,freq_bins_left,freq_bins_right] = get_normalized_compensations(compensationfilterfile)

load(compensationfilterfile);                       % get inverse filter as impulse response
% log individual compensation levels
% To get an amplitude correction factor, Aamp, for frequency Afreq:

% get impulse response of compensation filter for left and right channel
left_IR  = compensationFilters.L;
right_IR = compensationFilters.R;

% get power spectrum of compensation filter
left_fourier  = abs(fft(left_IR));
right_fourier = abs(fft(right_IR));
left_fourier  = left_fourier(1:length(left_fourier)/2);
right_fourier = right_fourier(1:length(right_fourier)/2);

% get frequencies corresponding to power spectrum
%freq_bins_left  = linspace(0, grid.sampleRate/2, length(left_fourier));
%freq_bins_right = linspace(0, grid.sampleRate/2, length(right_fourier));
freq_bins_left  = linspace(0, 100000/2, length(left_fourier));
freq_bins_right = linspace(0, 100000/2, length(right_fourier));

% find maximal attenuation value of speaker in frequency region
% of interest and normalize
max_filtervalue_left = max(left_fourier(freq_bins_left<25e3));
max_filtervalue_right = max(right_fourier(freq_bins_right<25e3));
norm_left = left_fourier/max_filtervalue_left;
norm_right = right_fourier/max_filtervalue_right;

end
function [stim, stimInfo] = make_and_compensate_dadida(sweepNum, grid, expt)

stimInfo.stimGridTitles = grid.stimGridTitles;
stimInfo.stimParameters = grid.randomisedGrid(sweepNum, :);
params = num2cell(stimInfo.stimParameters);

%  grid.stimGridTitles = {'BF (Hz)', 'Delta_f (oct)', ...
%      'f0 condition (1-5)', 'B offset', 'B random', 'N test cycles (A)', 'N test cycles (B)', ...
%      'Prestim', 'B rand2', 'B dist', 'B sigma','Level'};

[bf, delta_f, f0_cond, Bstart, Brand, ntestcycles(1), ntestcycles(2), ...
    prestim_type, Brand2, Bdist, Bsigma, level] = params{1:12};

f0_multipliers = [0:0.25:1] * delta_f;

Bfreq = bf * 2.^[f0_multipliers(f0_cond)];
Afreq = Bfreq / 2.^(delta_f);
interrupt_freq = Afreq / 2.^(3/12);

%Afreq = [bf * 2.^([0:0.25:1]*delta_f(1)) bf * 2.^([0:0.25:1]*delta_f(2))]; 
%freqB = [bf * 2.^(([0:0.25:1]-delta_f(1))*delta_f(1)) bf * 2.^(([0:0.25:1]-delta_f(2))*delta_f(2))];

c = grid.stimulusConstants;

for chan = 1:length(grid.compensationFilters)
    cf = grid.compensationFilters{chan};
 
    ft = abs(fft(cf));
    ft = ft(1:length(ft)/2);
    f = linspace(0, grid.sampleRate/2, length(ft));

    Aamp = interp1(f, ft, Afreq);
    Bamp = interp1(f, ft, Bfreq);
    interrupt_amp = interp1(f, ft, interrupt_freq);
    % have tested this against convolution and it works OK

    if prestim_type==0
        prestim = 0;
    elseif prestim_type==1
        prestim = [1 Afreq Aamp];
    elseif prestim_type==2
        prestim = [1 interrupt_freq interrupt_amp];
    end

    jitter = [0 0 0 Brand2 Bdist Bsigma];
    
% function stimoutput = dadidagen(Afreq,Alev,Agap,Bfreq,Blev,Bgap,Bstart,Brand,tondur, ...
%    intdur,nprecycles,ntestcycles,prestim,sampleRate,randseed,jitter,n)

    stim(chan, :) = dadidagen(Afreq, Aamp, c.Agap, Bfreq, Bamp, c.Bgap, Bstart, ...
        Brand, c.tondur, c.intdur, c.nprecycles, ntestcycles, prestim, grid.sampleRate, ...
        c.randomseed, jitter, c.n);
    stim(chan, :) = stim(chan, :) * 10^((grid.stimLevelOffsetDB(chan) + level)/20);
end

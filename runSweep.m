function [nSamples, spikeTimes, timeStamp, plotData] = runSweep(tdt, sweepLen, stim, nextStim, plotFunctions, detectSpikes, spikeFilter, spikeThreshold, dataFiles, plotData)
%% Run a sweep, ASSUMING THAT THE STIMULUS HAS ALREADY BEEN UPLOADED
%% Will fail if next stimulus is not on the TDT
%% Upload the next stimulus at the same time, then reset the stimDevice
%% and inform the stimDevice of the stimulus length

global state fakedata;

% reset data device and tell it how long the sweep will be
resetDataDevice(tdt.dataDevice, sweepLen*1000);

% check for stale data in data device buffer
if any(countAllData(tdt.dataDevice) ~= 0)
  error('Stale data in data buffer');
end

% check that the correct stimulus is in the stimDevice buffer
stimLen = size(stim, 2);
rnd = floor(100+rand*(stimLen-300));
checkData = [downloadStim(tdt.stimDevice, 0, 100) downloadStim(tdt.stimDevice, rnd, 100) downloadStim(tdt.stimDevice, stimLen-100, 100)];
d = max(max(abs(checkData - [stim(:, 1:100) stim(:, rnd+1:rnd+100) stim(:, end-99:end)])));

if d>10e-7
  error('Stimulus on stimDevice is not correct!');
end

% check stimulus length is correct
if getStimLength(tdt.stimDevice) ~= stimLen
  error('Stimulus length on stimDevice is not correct');
end
%if abs(getStimLength(tdt.stimDevice) - stimLen) > 2
%  error('Stimulus length on stimDevice is not correct');
%end


% reset stimulus device so it reads out from the beginning of the buffer
% when triggered
% probably not necessary (since circuit resets itself)
% replace with a check that it is in correct state?
resetStimDevice(tdt.stimDevice);
if getStimIndex(tdt.stimDevice)~=0
  error('Stimulus index not equal to zero at start of sweep');
end

% make matlab buffer for data
nSamplesExpected = floor(sweepLen*tdt.dataSampleRate)+1;
data = zeros(32, nSamplesExpected);
nSamplesReceived = zeros(1, 32);

filteredData = zeros(32, nSamplesExpected);
filterIndex = zeros(1,32);

% open data files
dataFileHandles = nan(1,32);
for chan = 1:32
  dataFileHandles(chan) = fopen(dataFiles{chan},'w');
end

% cell array for storing spike times
spikeTimes = cell(1, 32);
spikeIndex = zeros(1,32);

spikeTimesOld = cell(1,32);
spikeIndexOld = 0;

% keep track of how much of stimulus has been uploaded
samplesUploaded = 0;

% prepare data display
%plotData = feval(plotFunctions.init, [], tdt.dataSampleRate, nSamplesExpected);
plotData = feval(plotFunctions.reset, plotData);

% trigger stimulus presentation and data collection
timeStamp = clock;
triggerZBus(tdt.zBus);

fprintf(['  * Sweep triggered after ' num2str(toc) ' sec.\n']);

% while trial is running:
% * upload next stimulus as far as possible
% * download data as fast as possible while trial is running
% * plot incoming data

if ~isempty(fakedata)
  for chan = 1:32
    data{chan} = rand(1, nSamplesExpected)/5000;
  end
  data{1}(1:size(fakedata.signal, 1)) = fakedata.signal(:, floor(rand*size(fakedata.signal, 2)+1));
end

% loop until we've received all data
while any(nSamplesReceived~=nSamplesExpected)

  % upload stimulus
  if ~isempty(nextStim)
    % stimulus upload is limited by length of stimulus, or where the
    % stimDevice has got to in reading out the stimulus, whichever is lower
    maxStimIndex = min(getStimIndex(tdt.stimDevice),stimLen);

    if maxStimIndex>samplesUploaded
      uploadStim(tdt.stimDevice, nextStim(:, samplesUploaded+1:maxStimIndex), samplesUploaded);
      samplesUploaded = maxStimIndex;
      if samplesUploaded==stimLen
        fprintf(['  * Next stimulus uploaded after ' num2str(toc) ' sec.\n']);
      end
    end
    
  end

  % download data
  for chan = 1:32

    newdata = downloadData(tdt.dataDevice, chan, nSamplesReceived(chan));

    if isempty(fakedata) % I.E. NOT using fakedata
      data(chan, nSamplesReceived(chan)+1:nSamplesReceived(chan)+length(newdata)) = newdata;
    end

    nSamplesReceived(chan) = nSamplesReceived(chan)+length(newdata);
    fwrite(dataFileHandles(chan), newdata, 'float32');
    
    % filter data
    % previously, this would refuse to do less than 1 sec of data at a time
    % now, it's not restricted
    filtSig = filterSignal(data(chan, filterIndex(chan)+1:nSamplesReceived(chan)), spikeFilter);
    filteredData(chan, filterIndex(chan)+spikeFilter.deadTime+1:filterIndex(chan)+spikeFilter.deadTime+length(filtSig)) = filtSig;
    filterIndex(chan) = filterIndex(chan) + length(filtSig);
    
    % find spikes
    spikeSamples = findSpikes(data(chan,spikeIndex(chan):end), spikeThreshold);
    if length(times)>length(data(chan, spikeIndex(chan):end))/fs_in*1000
      spikeSamples = [];
      fprintf(['Too many spikes on channel ' num2str(chan) '. Ignoring.\n']);
    end
    newSpikeTimes = (spikeIndex + spikeSamples)/fs_in * 1000;
    
    spikeTimes{chan} = [spikeTimes{chan}; newSpikeTimes];
    
  end

  % check audio monitor is on the right channel
  if state.audioMonitor.changed
    setAudioMonitorChannel(tdt, state.audioMonitor.channel);
    state.audioMonitor.changed = false;
  end
  
  % filter new data
  [spikeTimesOld, spikeIndexOld] = appendSpikesOld(spikeTimesOld, tdt.dataSampleRate, data, nSamplesReceived, spikeIndexOld, spikeFilter, spikeThreshold, false);

  % plot data
  plotData = feval(plotFunctions.plot, plotData, data, nSamplesReceived, filteredData, filterIndex, spikeTimesOld, spikeTimes);
  drawnow;
end

fprintf(['  * Waveforms received and saved after ' num2str(toc) ' sec.\n']);

if ~isempty(nextStim)
  % finish uploading stimulus if necessary
  if samplesUploaded~=stimLen
    uploadStim(tdt.stimDevice, nextStim(:, samplesUploaded+1:end), samplesUploaded);
    samplesUploaded = stimLen;
    fprintf(['  * Next stimulus uploaded after ' num2str(toc) ' sec.\n']);
  end
  
  % inform stimDevice about length of the stimulus that has been uploaded
  % (i.e. the stimulus for the next sweep)
  setStimLength(tdt.stimDevice, size(nextStim,2));
end

% finish detecting spikes
if detectSpikes
  [spikeTimesOld, spikeIndexOld] = appendSpikes(spikeTimesOld, tdt.dataSampleRate, data, nSamplesReceived, spikeIndexOld, spikeFilter, spikeThreshold,true);
  fprintf(['  * ' num2str(sum(cellfun(@(i) length(i),spikeTimesOld))) ' spikes detected after ' num2str(toc) ' sec.\n']);
end

% final plot
plotData = feval(plotFunctions.plot, plotData, data, nSamplesReceived, filteredData, filterIndex, spikeTimesOld, spikeTimes);
drawnow;

% close data files
for chan = 1:32
  fclose(dataFileHandles(chan));
end

% data integrity check:
% 1. check all channels have the same amount of data
nSamples = unique(nSamplesReceived);
if length(nSamples)>1
  error('Different amounts of data from different channels');
end

fprintf(['  * Got ' num2str(nSamples) ' samples (expecting ' num2str(nSamplesExpected) ') from 32 channels (' num2str(nSamples/tdt.dataSampleRate) ' sec).\n']);

% 2. check that we got the expected number of samples
if (nSamples~=nSamplesExpected)
  error('Wrong number of samples');
end

% optional: check data thoroughly (too slow to be used normally)
global checkdata

if checkdata
  fprintf('  * Checking stim...');
  teststim = downloadStim(tdt.stimDevice, 0, samplesUploaded);
  d = max(max(abs(nextStim-teststim)));
  if d>10e-7
    error('Stimulus mismatch!');
  end
  fprintf([' ' num2str(size(teststim, 2)) ' samples verified.\n']);

  fprintf('  * Checking data...');
  testData = downloadAllData(tdt.dataDevice);
  for chan = 1:32
    diffInMem = max(abs(data(chan,:) - testData{chan}));
    if diffInMem > 0
      error('Data in memory doesn''t match TDT buffer!');
    end

    h = fopen(dataFiles{chan}, 'r');
    savedData = fread(h, inf, 'float32')';
    fclose(h);
    diffOnDisk = max(abs(savedData - testData{chan}));
    if diffOnDisk > 0
      error('Data on disk doesn''t match TDT buffer!');
    end
    
  end
  fprintf([' ' num2str(nSamples) ' samples verified.\n']);
  fprintf(['  * Check complete after ' num2str(toc) ' sec.\n']);
end

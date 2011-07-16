function [device, sampleRate] = ...
  dataDeviceInit(device, deviceName, requestedSampleRateHz, channelMapping)
% [device, sampleRate] = ...
%   dataDeviceInit(device, deviceName, requestedSampleRate, channelMapping)
% 
% Initialise TDT data device and set the channel mapping
% 
% device: Existing handle to the device, or [] if you don't have one
% deviceName: e.g. 'RZ5'
% requestedSampleRateHz: desired sample rate, e.g. 48828.125
% channelMapping: A vector specifying the order you want the channels in

[device, sampleRate] = deviceInit(device, deviceName, ...
  ['tdt/' deviceName '-nogain.rcx'], ...
  [deviceName 'NoGainVer'], 3, requestedSampleRateHz);

% NB! This mapping has to be uploaded to TDT as 32-bit integers
device.WriteTagVEX('ChanMap',0,'I32',channelMapping);

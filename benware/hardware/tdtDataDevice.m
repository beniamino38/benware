classdef tdtDataDevice < tdtDevice
  properties
      nChannels = nan;
  end

  methods

    function obj = tdtDataDevice(deviceName, requestedSampleRateHz, channelMap)

      rcxFilename = ['benware/tdt/' deviceName '-nogain.rcx'];
      versionTagName = [deviceName 'NoGainVer'];
      versionTagValue = 3;
      
      obj = obj@tdtDevice(deviceName, rcxFilename, versionTagName, versionTagValue, ...
                   requestedSampleRateHz);

      obj.handle.WriteTagVEX('ChanMap',0,'I32',channelMap);
      obj.nChannels = length(channelMap);
      
    end
    
    function map = channelMap(obj)
      map = obj.handle.ReadTagVEX('ChanMap', 0, obj.nChannels ,'I32', 'F64', 1);
    end
    
    function data = downloadAllData(obj)
        data = cell(1, obj.nChannels);
        for chan = 1:obj.nChannels
            maxIndex = obj.handle.GetTagVal(['ADidx' num2str(chan)]);
            data{chan} = obj.handle.ReadTagV(['ADwb' num2str(chan)],0,maxIndex);
        end
    end

    function data = downloadData(obj, chan, offset)
        maxIndex = obj.handle.GetTagVal(['ADidx' num2str(chan)]);
        if maxIndex-offset==0
          data = [];
        elseif maxIndex<offset
          data = [];
          errorBeep('Data requested beyond end of buffer!\n');
        else
          data = obj.handle.ReadTagV(['ADwb' num2str(chan)],offset,maxIndex-offset);
        end
    end
    
    function reset(obj, trialLen)
        if nargin==2
          obj.handle.SetTagVal('recdur',trialLen);
        end
        obj.handle.SoftTrg(9);
    end
    
    function setAudioMonitorChannel(obj, chan)
        obj.handle.SetTagVal('MonChan',chan);
    end
    
    function softTrigger(obj)
        obj.handle.SoftTrg(1);
    end

    function index = countAllData(obj, nChannels)
        % index = countAllData(dataDevice, nChannels)
        %
        % Count the number of samples available on each channel of the data Device
        % i.e. the index that the serial buffers have reached
        % 
        % dataDevice: A handle to the data device
        % nChannels: The number of channels that you want information about
        % index: 1xnChannels vector of buffer indexes

        index = nan(1, nChannels);
        for chan = 1:nChannels
            index(chan) = obj.handle.GetTagVal(['ADidx' num2str(chan)]);
        end
    end
    
    function index = countData(obj, chan)
        % index = countData(dataDevice, chan)
        %
        % Count number of samples available on a specified channel of the 
        % data device
        %
        % dataDevice: handle of the data device
        % chan: the number of the channel you want
        % index: the index that the serial buffer has reached

        index = obj.handle.GetTagVal(['ADidx' num2str(chan)]);
    end
    
  end
end

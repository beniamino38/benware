function grid = grid_mixmix_v3()

  % controlling the sound presentation
  grid.sampleRate = 24414.0625*2;  % ~50kHz
  grid.stimGenerationFunctionName = 'loadStereoFile';
  grid.stimDir = 'e:\auditory-objects\sounds-uncalib\mixmix\';
  grid.stimFilename = 'mixmix.mix.%1.%2.wav';
  
  % stimulus grid structure
  grid.stimGridTitles = {'Mixture', 'Sound ID', 'Level'};  
  grid.stimGrid = createPermutationGrid([0 1], 1:16, 80);
  
  global CALIBRATE;
  if CALIBRATE
    fprintf('== Calibration mode. Press a key to continue == ')
    pause;
    grid.stimGrid = createPermutationGrid(1, 1, 80); 
  end
  
  % sweep parameters
  grid.postStimSilence = 0;
  grid.repeatsPerCondition = 15;
  
  % set this using absolute calibration
  grid.legacyLevelOffsetDB = 0;
  
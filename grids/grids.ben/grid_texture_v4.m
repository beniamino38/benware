function grid = grid_texture_v4()

  % controlling the sound presentation
  grid.sampleRate = 24414.0625*2;  % ~50kHz
  grid.stimGenerationFunctionName = 'loadStereoFile';
  grid.stimDir = 'e:\auditory-objects\sounds-uncalib\texture.v2\';
  grid.stimFilename = 'texture.v2.id%1.type%2.wav';
  
  % stimulus grid structure
  grid.stimGridTitles = {'Sound ID', 'Condition', 'Level'};  
  grid.stimGrid = [createPermutationGrid(1:5, 1:9, 80); % sounds
                   createPermutationGrid(6,9,80)]; % silence

  global CALIBRATE;
  if CALIBRATE
    fprintf('== Calibration mode. Press a key to continue == ')
    pause;
    grid.stimGrid = createPermutationGrid(9, 9, 80);
  end

  % sweep parameters
  grid.postStimSilence = 0;
  grid.repeatsPerCondition = 7;
  
  % set this using absolute calibration
  grid.legacyLevelOffsetDB = 0;
  
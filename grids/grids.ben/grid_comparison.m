function grid = grid_comparison()

  % controlling the sound presentation
  grid.sampleRate = tdt100k;
  grid.stimGenerationFunctionName = 'loadStereoFile';
  grid.stimDir = 'e:\auditory-objects\sounds-uncalib\comparison\';
  grid.stimFilename = 'comparison.stimtype.%1.token.%2.wav';
  
  % stimulus grid structure
  grid.stimGridTitles = {'Stim type', 'Token'};  
  grid.stimGrid = [createPermutationGrid(0, 1:2); ... % fixed DRC
                    createPermutationGrid(1, 1:2); ... % var DRC
                    createPermutationGrid(2, 1:3); ... % TORC
                    createPermutationGrid(3, 1:2); ... % modnoise                  
                    createPermutationGrid(4, 1:2); ... % nat sounds
                    createPermutationGrid(6, 1:3); ... % pure tones
                    ];

  global CALIBRATE;
  if CALIBRATE
   fprintf('Calibration only!!\n');
   pause;
   grid.stimGrid = [0 1];
  end

  % sweep parameters
  grid.postStimSilence = 0;
  grid.repeatsPerCondition = 10;
  
  % set this to match nominal level of 80dB
  grid.legacyLevelOffsetDB = 9;
  
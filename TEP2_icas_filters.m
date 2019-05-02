

% Run TEP0_batch first (contains initialization parameters) + TEP1
% (pre-processing)

for dir_i = 1:size(raw_dirs,2) % this loop will run for each subject (directory) to analyze
    
    % Define subject-specific folders:
    eeg_filepath = [raw_dirs(dir_i).folder, '/', raw_dirs(dir_i).name, '/eeg'];
    beh_filepath = [raw_dirs(dir_i).folder, '/', raw_dirs(dir_i).name, '/beh'];
    new_filepath = [proc_filepath, '/', raw_dirs(dir_i).name];
    if ~exist(new_filepath, 'dir')
        mkdir(new_filepath);
    end 
        
    % Read and define file names
    cd(new_filepath)
    fileInfo = dir([new_filepath,filesep,'*_Dsampled.set']);
    nFiles = size(fileInfo,1);
    
    % Define the name of the future merged file
    fileprefix_merged = char(fileInfo(1).name(1:length(fileInfo(1).name) - 4)); 
    sprintf(fileprefix_merged)
    
    % Re-open EEGLAB - this reinitializes the loaded datasets
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    EEG = pop_loadset('filename',fileInfo(1).name,'filepath',new_filepath);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG);
    
    
    % --------- STEP 8: First ICA -----------------------------------------
    % Replace interpolated data around TMS pulse with constant amplitude data (-2 to 10 ms)
    EEG = pop_tesa_removedata( EEG, [-2 10] );
    
    % Remove TMS-evoked muscle activity (using FastICA and auto component selection)
    EEG = pop_tesa_fastica( EEG, 'approach', 'symm', 'g', 'tanh', 'stabilization', 'on' );
    EEG = pop_tesa_compselect( EEG,'comps',15,'figSize','small','plotTimeX',[-200 500],'plotFreqX',[1 100],'tmsMuscle','on','tmsMuscleThresh',8,'tmsMuscleWin',[11 30],'tmsMuscleFeedback','off','blink','off','blinkThresh',2.5,'blinkElecs',{'Fp1','Fp2'},'blinkFeedback','off','move','off','moveThresh',2,'moveElecs',{'F7','F8'},'moveFeedback','off','muscle','off','muscleThresh',0.6,'muscleFreqWin',[30 100],'muscleFeedback','off','elecNoise','off','elecNoiseThresh',4,'elecNoiseFeedback','off' );
    
    % Save point
    filename = [fileprefix_merged,'05_FirstICA.set'];
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, nFiles+1);
    EEG = pop_saveset( EEG, 'filename',filename,'filepath',new_filepath);
    
    
    % --------- STEP 9: Filtering -----------------------------------------
    % Extend data removal to 15 ms (-2 to 15 ms)
    EEG = pop_tesa_removedata( EEG, [-2 15] );
    
    % Interpolate missing data around TMS pulse
    EEG = pop_tesa_interpdata( EEG, 'cubic', [5,5] );
    
    % Bandpass (1-100 Hz) and bandstop (48-52 Hz) filter data;
    % Issues of baseline drift linked to the 1Hz high-pass filter. Test
    % without
    % EEG = pop_tesa_filtbutter( EEG, 1, 100, 4, 'bandpass' );
         % EEG = pop_eegfiltnew(EEG, [], 100, [], 0, 0, false);
         EEG = pop_eegfiltnew(EEG, 0.5, 100, 6600, 0, [], 1); % param from GUI
    
    %     % Remove baseline
    %     EEG = pop_rmbase( EEG, [-500  -50]);
    
    EEG = pop_tesa_filtbutter( EEG, 48, 52, 4, 'bandstop' );
    
    
    % --------- STEP 10: Second ICA ---------------------------------------
    % Replace interpolated data around TMS pulse with constant amplitude data (-2 to 15 ms)
    EEG = pop_tesa_removedata( EEG, [-2 15] );
    
    % Remove all other artifacts (using FastICA and auto component selection)
    EEG = pop_tesa_fastica( EEG, 'approach', 'symm', 'g', 'tanh', 'stabilization', 'off' );
    EEG = pop_tesa_compselect( EEG,'compCheck','on','comps',[],'figSize','small','plotTimeX',[-200 500],'plotFreqX',[1 100],'tmsMuscle','on','tmsMuscleThresh',8,'tmsMuscleWin',[11 30],'tmsMuscleFeedback','off','blink','off','blinkThresh',2.5,'blinkElecs',{'Fp1','Fp2'},'blinkFeedback','off','move','on','moveThresh',2,'moveElecs',{'F7','F8','AF7','AF8'},'moveFeedback','off','muscle','on','muscleThresh',0.6,'muscleFreqWin',[30 100],'muscleFeedback','off','elecNoise','on','elecNoiseThresh',4,'elecNoiseFeedback','off' );
    
    % Save point
    filename = [fileprefix_merged,'05_FirstICA_SecondICA.set'];
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, nFiles+1);
    EEG = pop_saveset( EEG, 'filename',filename,'filepath',new_filepath);
    
    
    % --------- STEP 11: Clean up: rereference and remove baseline --------
    % Interpolate missing data around TMS pulse
    EEG = pop_tesa_interpdata( EEG, 'cubic', [5,5] );
    
    % Interpolate missing channels
    EEG = pop_interp(EEG, EEG.allchan, 'spherical'); % this compares the original labels to the current ones - interpolates the missing channels
    
    % Re-reference to average
    EEG = pop_reref( EEG, []);
    
    % Remove baseline
    EEG = pop_rmbase( EEG, [-500  -50]);
    
    % Save point
    filename = [fileprefix_merged,'05_FirstICA_SecondICA_Cleaned.set'];
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, nFiles+1);
    EEG = pop_saveset( EEG, 'filename',filename,'filepath',new_filepath);
    
    
end
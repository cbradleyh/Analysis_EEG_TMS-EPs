
% Run TEP0_batch first (contains initialization parameters)
for dir_i = 1:size(raw_dirs,2) % this loop will run for each subject (directory) to analyze
    
    % Define subject-specific folders:
    eeg_filepath = [raw_dirs(dir_i).folder, '/', raw_dirs(dir_i).name, '/eeg'];
    beh_filepath = [raw_dirs(dir_i).folder, '/', raw_dirs(dir_i).name, '/beh'];
    new_filepath = [proc_filepath, '/', raw_dirs(dir_i).name];
    if ~exist(new_filepath, 'dir')
        mkdir(new_filepath);
    end
    
    % Go to the raw files and list all .vhdr files
    cd(eeg_filepath)
    fileInfo = dir([eeg_filepath,filesep,'*.vhdr']);
    nFiles = size(fileInfo,1);
    
    % Define the name of the future merged file
    fileprefix_merged = char(strcat(fileInfo(1).name(1:length(fileInfo(1).name) - 8),'_Merged')); % need to take 8 characters off the end of the file name ('-01.vhdr')
    sprintf(fileprefix_merged)
       
    % Open EEGLAB
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    
    for file_i=1:nFiles
        
        
        % --------- STEP 1: Load BrainVision file -------------------------
        % Read and define file names
        filename = fileInfo(file_i).name;
        sprintf(filename)
        new_file_name = char(strcat(filename(1:length(filename) - 5), '_', epoching, 'Epoched_Demeaned_TrialRej.set')); % need to take 5 characters off the end of the file name ('.vhdr')
        
        % Load the dataset to work on
        EEG = pop_loadbv(eeg_filepath, filename);
        
        % Load channel locations
        newchans = convertlocs(EEG.chanlocs, 'sph2all'); % converts Matlab spherical coordinates to all (cartesian 3D, topo, etc...)
        EEG.chanlocs = newchans;
        
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, file_i,'setname',new_file_name,'gui','off'); % create successive sets
        
        
        % --------- STEP 2: Epoch data (-1000 to 1000 ms) -----------------
        % Find TMS pulses (if no triggers recorded) - skipped here
        %EEG = pop_tesa_findpulse( EEG, 'Cz', 'refract', 4, 'rate', 10000, 'tmsLabel', 'TMS', 'plots', 'on');
        
        EEG = pop_epoch( EEG, trigger, [-1  1], 'epochinfo', 'yes');
        
        
        % --------- STEP 3: Demean data (-1000 ms to 1000 ms) -------------
        EEG = pop_rmbase( EEG, [-1000  1000]);
        
        
        % --------- STEP 4: Remove bad trials -----------------------------
        % Get the number of times EEG.event.type is S 3 (TMS stimulus)
        b = cellfun(@(x) sum(ismember({EEG.event.type},x)),trigger,'un',0);
        Initial_num_stimuli(file_i) = b
        
        % find the row number for current subject and block
        row_idx = find(ismember(bad_epoch_data(:,1),strcat({raw_dirs(dir_i).name}, '_01'))); % first block  
        row_idx = row_idx + file_i - 1; % first block adjust row number 
        
        % Give a warning signal if there seems to be different numbers of
        % epochs in the excel and actual file
        if bad_epoch_data{row_idx,2} ~= Initial_num_stimuli{file_i}
            error('Total epoch numbers dont match!')
        end
        
        % Define the trials to get rid of
        GetRidOfThese = []; % initialize
        for col_i = 3:size(bad_epoch_data,2) % start at the third column (first two are filename and total epochs)
            if isnan(cell2mat(bad_epoch_data(row_idx,col_i)))
                GetRidOfThese  = GetRidOfThese; % skip the NaNs
            else GetRidOfThese = [GetRidOfThese, bad_epoch_data{row_idx,col_i}]; % integrate the epochs to get rid of
            end
        end
        % select only the good trials - ie discard the bad ones
        EEG = pop_select( EEG,'notrial', GetRidOfThese);
        
        % Remove bad trials - automated
        % EEG = pop_jointprob(EEG,1,[1:size(EEG.data,1)],5,5,0,0);
        % pop_rejmenu(EEG,1);
        % pause_script = input('Highlight bad trials, update marks and then press enter');
        % EEG.BadTr = unique([find(EEG.reject.rejjp==1) find(EEG.reject.rejmanual==1)]);
        % EEG = pop_rejepoch( EEG, EEG.BadTr ,0);
        
        % Save the result
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, file_i);
        EEG = pop_saveset(EEG, 'filename', new_file_name, 'filepath', new_filepath, 'version', '7.3'); % 'version', '7.3' is necessary to save heavy datasets; also just generates one file .set
        
    end % file_i
    
    
    % --------- STEP 5: Merge all block files -----------------------------
    % Read and define file names
    fileInfo = dir([new_filepath,filesep,'*Demeaned_TrialRej.set']);
    nFiles = size(fileInfo,1)
    
    % Re-open EEGLAB - this reinitializes the loaded datasets
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    
    for file_i=1:nFiles % Load all (8) files at once
        %Import data to EEGLAB
        EEG = pop_loadset('filename',fileInfo(file_i).name,'filepath',new_filepath);
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG);
        
        % get the number of times EEG.event.type is the trigger of interest
        b=cellfun(@(x) sum(ismember({EEG.event.type},x)),trigger,'un',0);
        Num_stimuli(file_i) = b
    end % file_i
    save('Num_stimuli.mat', 'Num_stimuli')
    
    % Concatenate
    EEG = pop_mergeset(ALLEEG, (1:nFiles), 0);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, nFiles+1,'setname','Merged_dataset','gui','off');
    EEG.Num_stimuli = Num_stimuli; % storing the number of TMS stimuli per dataset
    
    
    % --------- STEP 6: Exclude and mark bad channels ---------------------
    EEG = pop_select(EEG, 'nochannel', {'TP9' 'TP10'}); % drop systematically noisy electrodes (TP9 and TP10)
    % Save the original EEG locations for use in interpolation later
    EEG.allchan = EEG.chanlocs; % We save these channel locations because we never want to look at TP9 and TP10
    
    % Extract bad channel information from the Excel file to be
    % interpolated
    sub_idx = find(ismember(bad_channel_data(:,1),{raw_dirs(dir_i).name})); % find the row number of current subject
    
    bad_channels=[];
    for col_i = 2:size(bad_channel_data,2)
        if isnan(cell2mat(bad_channel_data(sub_idx,col_i)))
            bad_channel_data(sub_idx,col_i)  = {'NaN'}; % transforming in string otherwise ismember function does not like the input
        end
        idx = find(ismember({EEG.chanlocs.labels},(bad_channel_data{sub_idx,col_i}))); % find the index for each channel
        if ~isnan(idx)
            bad_channels(col_i-1) = idx;
        end % end if
    end % end col_i
    
    EEG = pop_select( EEG,'nochannel', bad_channels);
    
    % Remove bad channels - Automated
    % [EEG, indelec] = pop_rejchan(EEG, 'elec',[1:size(EEG.data,1)] ,'threshold',2,'norm','on','measure','prob');
    % EEG.badelec=indelec;
    
      
    % --------- Step 7: Downsample data (5000 Hz to 1000 Hz) --------------
    
    % This step is necessary for avoiding downsampling issues 
    EEG = pop_tesa_removedata( EEG, [-2 10] );
    % Interpolate missing data around TMS pulse
    EEG = pop_tesa_interpdata( EEG, 'cubic', [1,1] );
    
    if EEG.srate>1000
        EEG = pop_resample(EEG, 1000);
    end
    
    
    % Save point
    filename = [fileprefix_merged,'_Chanrej_Dsampled.set'];
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, nFiles+1);
    EEG = pop_saveset( EEG, 'filename',filename,'filepath',new_filepath);
    
    
end % dir_i



%% Preparation:

% Open the 'BadEpoch' xlsx sheet
% In the first column, enter the file names for each block file; one on each row, without the extension

% Open the 'BadChan' xlsx sheet
% In the first column, enter the master file name for each participant; one on each row

% Open the block files in BrainVision Analyzer
% Segment on S3 (TMS pulse, -1000 to 1000ms); notch filter 50Hz;
% band-pass at 1-100Hz; apply baseline correction -800 to -400ms

% Quickly run through the epochs, taking note of any overly bad channel
% (ignoring the TMS artefact) and taking note of any trials that have abnormal activity (e.g. no TMS pulse or very high noise)
% If a channel is bad only for a few epochs, it is better to eliminate
% these epochs rather than interpolate the channel. Once 'bad channels' are
% determined, check that they should really be interpolated by reviewing
% very briefly once more their activity over all epochs and all blocks.

% In Brain Vision, remove extra channels (TP9 and TP10), interpolate
% selected electrodes, average + Grand-Average. Check that that fixed the issues.

% Enter channel names to be interpolated in 'BadChan.xlsx'; order does not matter.
% Enter enter the total initial epoch number for each block in the second column of 'BadEpoch.xlsx'.
% In the following columns, enter trial numbers to be rejected; order does not matter but better chronological.


%% General setup - paths

clear; close all; clc;

addpath /Users/uqcbrad2/Documents/MATLAB/eeglab13_6_5b;
addpath /Users/uqcbrad2/Documents/MATLAB/FastICA_25;
addpath /Volumes/CBradleyQBI/TMS-EEG-Visual/data/code/TEP_analysis;
addpath(genpath('/Users/uqcbrad2/Documents/MATLAB/custom_functions'))
addpath /Users/uqcbrad2/Documents/MATLAB/collegues_functions

%% Directories and folders

project_folder = '/Volumes/CBradleyQBI/TMS-EEG-Visual'; % change this if the project has been moved somewhere else
raw_filepath = strcat(project_folder, '/data');

% Define which event you want to epoch on
epoching = 'TMS';
if strcmp(epoching,'TMS') == 1
    trigger = {'S  3'};
    proc_filepath = strcat(project_folder, '/data/derivatives/EEG_TEPs');
elseif strcmp(epoching, 'VisStim') == 1
    trigger = {'S  2'};
    proc_filepath = strcat(project_folder, '/data/derivatives/EEG_VEPs');
elseif strcmp(epoching, 'Resp') == 1
    trigger = 'S  4'; 'S  6'; % need to combine both
    proc_filepath = strcat(project_folder, '/data/derivatives/EEG_Resp');
end

% Fetch trials to reject and channels to interpolate to be analysed from an external file
cd(proc_filepath) % go where the xlsx file is
[~,~,bad_channel_data] = xlsread('BadChan.xlsx');
[~,~,bad_epoch_data] = xlsread('BadEpoch.xlsx');

% Fetch subject folders and file information
cd(raw_filepath)
subjects_to_analyze = {'27'}; % 'all', or {'01','27'}

if strcmp(subjects_to_analyze,'all') == 1
    raw_dirs = dir('*sub-*'); % scan for all directories containing 'sub-'; get the details of the suject sub-directories
else
    raw_dirs = dir('*sub-*'); 
    temp = [];
    for sub_i = 1:length(subjects_to_analyze) % filter for the subjects to analyze
        idx = find(ismember({raw_dirs.name},['sub-' subjects_to_analyze{sub_i}])); % find the index for each subject
        temp = [temp, raw_dirs(idx)];
    end
    raw_dirs = temp; % update raw_dirs with the reduced number of participants
end

% Run TEP1_loading_all_files_session
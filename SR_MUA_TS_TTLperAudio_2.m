%% SR_MUA_TS_TTLperAudio

% This script processes extracellular recordings to generate raster plots, PSTHs,
% frequency-resolved spike analyses, and per-channel quantification, including spike amplitude and stimulus-evoked responses.
%The script was made for recordings that have a TTL marking each individual
%sound. To get the sequence of the sound and organize it by frequencies it
%uses an excel file called random_sequence.
%The channel map and number of shanks can be altered
%Each section also has a parameter part that can be changed

clear all; close all; clc;

%% Creat folder to save figures

% mkdir Figures
%
% addpath Figures


%% INPUT PARAMS

samp_freq = 30000; %sampling frequency (in Hz)

nchan = 72;
%nchan = 64;

nshanks = 4;

% 4-shank cambridge (64chan)
%siteMap = [64 62 59 57 55 53 51 47 50 52 54 56 58 60 61 63 37 39 41 46 44 33 35 48 36 34 49 43 45 42 40 38 27 25 23 20 22 31 29 18 30 32 15 21 19 24 26 28 2 4 5 7 9 11 13 17 16 14 12 10 8 6 3 1,65,66,67];

% 4-shank cambridge (64chan) + AUX
% siteMap = [38,37,40,39,42,41,45,46,43,44,49,33,34,35,36,48,63,64,61,62,60,59,58,57,56,55,54,53,52,51,50,47,1,2,3,4,6,5,8,7,10,9,12,11,14,13,16,17,28,27,26,25,24,23,19,20,21,22,15,31,32,29,30,18,65,66,67,68,69,70,71,72];

% 4-shank cambridge (64chan) + AUX
  siteMap = [59,57,55,52,54,48,64,62,49,61,63,53,51,56,58,60,33,35,37,39,41,43,45,47,50,46,44,42,40,38,36,34,31,29,27,25,23,21,19,17,16,20,22,24,26,28,30,32,5,7,9,14,12,18,2,4,15,3,1,11,13,10,8,6,65,66,67,68,69,70,71,72];

 % 4-shank cambridge (64chan) 
 % siteMap = [59,57,55,52,54,48,64,62,49,61,63,53,51,56,58,60,33,35,37,39,41,43,45,47,50,46,44,42,40,38,36,34,31,29,27,25,23,21,19,17,16,20,22,24,26,28,30,32,5,7,9,14,12,18,2,4,15,3,1,11,13,10,8,6];

%window_size for psth (bin size)

win = 10; %in seconds

win_samp = win*samp_freq;

chans_to_process = siteMap(1:64);

%% LOAD FILE

[FileName,PathName] = uigetfile('.dat'); %select file

contFile=fullfile(PathName,FileName); %create full file path with file name

s=dir(contFile);
file_size=s.bytes; %determine file size in byte

samples=file_size/2/nchan;

m=memmapfile(contFile,'Format',{'int16' [nchan samples] 'mapped'}); %create memory map of the file

data = m.Data;

duration_in_sec = size(double(data.mapped(1,:)),2) / samp_freq;


%% USE JRCLUST FOR SPIKE DETECTION
% you need the .prm file on the same folder as the .dat file, do not forget
% to change .prm params

 % jrc detect continuous_4shank_ASSY-77_E1_72channels.prm

 % jrc detect continuous_4shank_ASSY-77_E1_64channels.prm

%% load JRClust spike detection results for the recording

%load('continuous_2shank_ASSY-77_H4_res.mat')

 load('manual_detected_res.mat')

% load('continuous_4shank_ASSY-77_E1_64channels_res.mat')

%% Map JRClust site index 
% Assumes you've already: load('continuous_4shank_ASSY-77_E1_72channels_res.mat')
nSites = max(spikeSites);

% Define the translation map using your input siteMap
chan_for_site = siteMap(:); 

% Safety check: If JRClust detected more sites than entries in siteMap, pad with NaN
if numel(chan_for_site) < nSites
    chan_for_site(nSites) = NaN;           
    warning('siteMap has fewer entries than detected sites. Padding with NaN.');
end

% The key translation step
spikeChans_abs = chan_for_site(spikeSites);

% Quick diagnostics (replaces the old error-prone code)
fprintf('\n--- Mapping Diagnostics ---\n');
fprintf('Max JRClust site index: %d\n', nSites);
fprintf('Total spikes processed: %d\n', numel(spikeSites));

% Verify mapping success
in_list = ismember(spikeChans_abs, siteMap);
fprintf('Spikes successfully mapped to siteMap: %d / %d (%.1f%%)\n', ...
    sum(in_list), numel(spikeChans_abs), 100*mean(in_list));

% Count spikes on AUX channels (sites > 64)
nAuxSpikes = sum(spikeSites > 64);
fprintf('Spikes detected on AUX sites (>64): %d\n', nAuxSpikes);

% (Optional) quick diagnostics
nAuxSites = sum(spikeSites > 64);
fprintf('Max site index = %d; spikes on sites >64: %d\n', nSites, nAuxSites);

in_list = ismember(spikeChans_abs, siteMap);
fprintf('Mapped spikes in siteMap: %d / %d (%.1f%%)\n', ...
    sum(in_list), numel(spikeChans_abs), 100*mean(in_list));

sum(in_list), numel(spikeChans_abs), 100*mean(in_list);
%% load TTL events

%relatie file path
s1 = strcat('..\..\events\OE_FPGA_Acquisition_Board-107.Rhythm Data\TTL\');

events_TTL = readNPY(strcat(s1,'timestamps.npy'));

% to get global clock time

events_continuous = readNPY('timestamps.npy');


events_TTL_ON = events_TTL(1:2:end);

%synch events with global time

for b=1:size(events_TTL_ON,1)

    events_TTL_audio_ON(b) = find(round(events_continuous,6)==round(events_TTL_ON(b),6));

end


%% Create folders to save figures
fig_dir = fullfile(PathName, 'Figures');
raster_dir = fullfile(fig_dir, 'raster');

if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end
if ~exist(raster_dir, 'dir'); mkdir(raster_dir); end

%% Plot rasters (and save each figure as PNG)
win_bef_s = 1; %in seconds
win_aft_s = 1; %in seconds

win_bef = round(win_bef_s * samp_freq);
win_aft = round(win_aft_s * samp_freq);

window_time = -win_bef_s : 1/samp_freq : win_aft_s;
for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));

    figure('Visible','off'); % create invisible figure to speed up

    time_hist = zeros(1, samples);
    time_hist(sp_time) = 1;

    time_hist_zeros = time_hist;
    time_hist(time_hist==0) = NaN; % for raster plotting

    aa = 1; % row position in raster

    for iii = 3:length(events_TTL_audio_ON) % ignore first two TTLs

        idx1 = events_TTL_audio_ON(iii) - win_bef;
        idx2 = events_TTL_audio_ON(iii) + win_aft;

        if idx1 < 1 || idx2 > samples
            continue
        end

        raster_spikes = time_hist(idx1:idx2);

        plot(window_time, raster_spikes + aa, 's', ...
            'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 3);
        hold on;

        aa = aa + 1;
    end

    % Add red line at time zero (stim onset)
    line([0 0], [0 aa], 'Color', 'r', 'LineStyle', '--');

    title(sprintf('Raster - Channel %d', real_chan));
    xlabel('Time (s)');
    ylabel('Trial');

    xlim([-win_bef_s win_aft_s]);
    ylim([0 aa]);

    % Save figure
    saveas(gcf, fullfile(raster_dir, sprintf('raster_chan%d.png', real_chan)));
    close(gcf);
end

%% PSTH Plots
% PARAMETERS FOR PSTH
bin_size_ms = 10;         % bin size in milliseconds
psth_win_s = 2;           % total window around TTL (in seconds)
smoothing_ms = 25;        % Gaussian smoothing in milliseconds

% Derived parameters
bin_size_s = bin_size_ms / 1000;
smoothing_bins = round(smoothing_ms / bin_size_ms);
half_win_s = psth_win_s / 2;
bin_edges = -half_win_s : bin_size_s : half_win_s;
bin_centers = bin_edges(1:end-1) + bin_size_s/2;

% Create PSTH figure folder
psth_dir = fullfile(fig_dir, 'PSTH');
if ~exist(psth_dir, 'dir'); mkdir(psth_dir); end

% Generate PSTH per channel
for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));

    fprintf('Computing PSTH for channel %d (index %d)\n', real_chan, jj)

    nTrials = numel(events_TTL_audio_ON) - 2;
    all_rel_times = [];
    all_trial_ids = [];

    % Collect spike times relative to TTLs
    for t = 3:length(events_TTL_audio_ON)
        t0 = double(events_TTL_audio_ON(t)) / samp_freq;
        in_window = sp_times_sec >= (t0 - half_win_s) & sp_times_sec <= (t0 + half_win_s);
        if ~any(in_window), continue; end
        rel_spikes = sp_times_sec(in_window) - t0;
        all_rel_times = [all_rel_times; rel_spikes];
        all_trial_ids = [all_trial_ids; t*ones(size(rel_spikes))];
    end

    if isempty(all_rel_times), continue; end

    % Bin and normalize
    bin_idx = discretize(all_rel_times, bin_edges);
    valid = ~isnan(bin_idx);
    trial_col = all_trial_ids(valid) - 2;  % convert to 1-based trial
    bin_col = bin_idx(valid);
    nBins = numel(bin_edges)-1;

    M = accumarray([trial_col bin_col], 1, [nTrials nBins]) / bin_size_s; % rate (Hz)

    % Baseline subtraction using pre-stim bins (<0)
    baseMask = bin_edges(1:end-1) < 0;
    M = M - mean(M(:, baseMask), 2);  % subtract trialwise baseline

    % Mean and SEM
    psth_mean = mean(M,1);
    psth_sem = std(M,0,1) / sqrt(nTrials);

    % Smoothing
    gk = gausswin(2*smoothing_bins+1); gk = gk / sum(gk);
    psth_mean_sm = conv(psth_mean, gk, 'same');
    psth_sem_sm = conv(psth_sem, gk, 'same');

    % Plot PSTH
    figure('Visible','off','Color','w','Position',[200 200 450 230]);
    fill([bin_centers fliplr(bin_centers)], ...
        [psth_mean_sm - psth_sem_sm, fliplr(psth_mean_sm + psth_sem_sm)], ...
        [0.8 0.8 1], 'EdgeColor','none', 'FaceAlpha', 0.3); hold on;

    plot(bin_centers, psth_mean_sm, 'Color', [0 0 0.5], 'LineWidth', 2);
    xline(0, 'r--');

    title(sprintf('PSTH – Ch %d', real_chan));
    xlabel('Time (s)');
    ylabel('Δ Rate (Hz)');
    xlim([bin_edges(1) bin_edges(end)]);

    saveas(gcf, fullfile(psth_dir, sprintf('psth_chan%d.png', real_chan)));
    close(gcf);

end

%%  DATA organized by frequencies
%Important information:
% Index 2 =8Hz
%Index 3 = 12Hz
%Index 4 = 16Hz
%Index 5 = 20Hz
%Index 6 = 24Hz
%Index 7= 28Hz
% Index 8 = White noise
% Index 9 = White noise crescendo
%Each sound lasted 400ms

% PARAMETERS
bin_size_ms = 10;
psth_win_s = 2;
smoothing_ms = 25;

bin_size_s = bin_size_ms / 1000;
smoothing_bins = round(smoothing_ms / bin_size_ms);
half_win_s = psth_win_s / 2;
bin_edges = -half_win_s : bin_size_s : half_win_s;
bin_centers = bin_edges(1:end-1) + bin_size_s/2;

freq_code = csvread('C:\Users\ATOMIC\Desktop\SReis\OpenEphys\OE_evoked_HARP\Second Protocol_ TTL + WN\random_sequence.csv');

% --- Make TTL count match sound-code count (report + trim, never error) ---
nTTL   = numel(events_TTL_audio_ON);
nCodes = numel(freq_code);

fprintf('\n[INFO] Found %d TTLs but %d sound codes in random_sequence.csv.\n', nTTL, nCodes);

if nCodes > nTTL
    % More codes than TTLs -> trim codes
    warning('Sound code list is longer than TTLs — trimming codes to %d.', nTTL);
    freq_code = freq_code(1:nTTL);
elseif nCodes < nTTL
    % More TTLs than codes -> trim TTLs (ignore extra TTLs at the end)
    warning('More TTLs than sound codes — trimming TTLs to %d (ignoring %d extra).', ...
        nCodes, nTTL - nCodes);
    events_TTL_audio_ON = events_TTL_audio_ON(1:nCodes);
end

% (Optional) If you later use ttl_times_sec/nTrials, recompute after trimming:
ttl_times_sec = double(events_TTL_audio_ON) / samp_freq;
nTrials = numel(ttl_times_sec);

freq_labels = {'8Hz','12Hz','16Hz','20Hz','24Hz','28Hz','WN','WNcrescendo'};
freq_values = 2:9;

% Create folders
freq_dir = fullfile(fig_dir, 'frequencies');
raster_freq_dir = fullfile(freq_dir, 'raster_frequencies');
psth_freq_dir = fullfile(freq_dir, 'psth_frequencies');

if ~exist(raster_freq_dir, 'dir'); mkdir(raster_freq_dir); end
if ~exist(psth_freq_dir, 'dir'); mkdir(psth_freq_dir); end

%Loop through channels and frequencies
for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));
    fprintf('\n--- Channel %d ---\n', real_chan)

    sp_time_sec = double(sp_time) / samp_freq;

    for f = 1:length(freq_values)

        freq_val = freq_values(f);
        freq_label = freq_labels{f};

        % Find trial indices for this frequency
        trial_idx = find(freq_code == freq_val);
        nTrials = length(trial_idx);

        if nTrials == 0
            continue
        end

        all_rel_times = [];
        all_trial_ids = [];

        % Collect spikes aligned to TTLs for this frequency
        for tt = 1:nTrials
            t0_sample = events_TTL_audio_ON(trial_idx(tt));
            t0_sec = double(t0_sample) / samp_freq;

            in_window = sp_time_sec >= (t0_sec - half_win_s) & sp_time_sec <= (t0_sec + half_win_s);
            rel_spikes = sp_time_sec(in_window) - t0_sec;

            all_rel_times = [all_rel_times; rel_spikes];
            all_trial_ids = [all_trial_ids; tt * ones(size(rel_spikes))];
        end

        if isempty(all_rel_times), continue; end

        % Raster
        figure('Visible','off');
        plot(all_rel_times, all_trial_ids, 'k.', 'MarkerSize', 4); hold on;
        xline(0,'r--');
        xlim([bin_edges(1) bin_edges(end)]);
        ylim([0.5 nTrials + 0.5]);
        set(gca,'YDir','reverse');
        xlabel('Time (s)');
        ylabel('Trial');
        title(sprintf('Raster – %s – Ch %d', freq_label, real_chan));

        saveas(gcf, fullfile(raster_freq_dir, ...
            sprintf('raster_chan%d_freq%d.png', freq_val, real_chan)));
        close(gcf);

        % PSTH
        % Bin spikes
        bin_idx = discretize(all_rel_times, bin_edges);
        valid = ~isnan(bin_idx);
        trial_col = all_trial_ids(valid);
        bin_col = bin_idx(valid);
        nBins = numel(bin_edges)-1;

        M = accumarray([trial_col bin_col], 1, [nTrials nBins]) / bin_size_s;

        % Baseline subtract each trial
        baseMask = bin_edges(1:end-1) < 0;
        M = M - mean(M(:, baseMask), 2);

        psth_mean = mean(M,1);
        psth_sem = std(M,0,1) / sqrt(nTrials);

        % Smoothing
        gk = gausswin(2*smoothing_bins+1);
        gk = gk / sum(gk);
        psth_mean_sm = conv(psth_mean, gk, 'same');
        psth_sem_sm = conv(psth_sem, gk, 'same');

        % Plot PSTH
        figure('Visible','off','Color','w','Position',[200 200 450 230]);
        fill([bin_centers fliplr(bin_centers)], ...
            [psth_mean_sm - psth_sem_sm, fliplr(psth_mean_sm + psth_sem_sm)], ...
            [0.8 0.8 1], 'EdgeColor','none', 'FaceAlpha', 0.3); hold on;
        plot(bin_centers, psth_mean_sm, 'Color', [0 0 0.5], 'LineWidth', 2);
        xline(0, 'r--');
        xlim([bin_edges(1) bin_edges(end)]);
        xlabel('Time (s)');
        ylabel('Δ Rate (Hz)');
        title(sprintf('PSTH – %s – Ch %d', freq_label, real_chan));

        saveas(gcf, fullfile(psth_freq_dir, ...
            sprintf('psth_chan%d_freq%d.png', freq_val, real_chan)));
        close(gcf);
    end
end

%% Frequency Raster_All frequencies in one graph

Freqraster_dir = fullfile(freq_dir, 'Freq_rasters');
if ~exist(Freqraster_dir, 'dir'); mkdir(Freqraster_dir); end

% Prepare frequency info
freq_labels = {'8Hz','12Hz','16Hz','20Hz','24Hz','28Hz','WN','WNcrescendo'};
freq_values = 2:9;

% Convert spikeTimes to seconds
spikeTimes_sec_all = double(spikeTimes) / samp_freq;

for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));
    fprintf('\nGenerating Frequency raster – Channel %d\n', real_chan);

    sp_time_sec = double(sp_time) / samp_freq;

    all_rel_times = [];
    all_trial_labels = [];
    freq_id_per_trial = [];
    trial_freq_lines = [];
    trial_counter = 1;

    % loop over frequencies
    for f = 1:length(freq_values)
        freq_val = freq_values(f);
        trial_idx = find(freq_code == freq_val); % trials for this frequency
        nTrials = length(trial_idx);

        if nTrials == 0
            continue
        end

        for t = 1:nTrials
            t0_sample = events_TTL_audio_ON(trial_idx(t));
            t0_sec = double(t0_sample) / samp_freq;
            in_window = sp_time_sec >= (t0_sec - half_win_s) & sp_time_sec <= (t0_sec + half_win_s);
            rel_spikes = sp_time_sec(in_window) - t0_sec;

            all_rel_times = [all_rel_times; rel_spikes];
            all_trial_labels = [all_trial_labels; trial_counter * ones(size(rel_spikes))];
            freq_id_per_trial = [freq_id_per_trial; f];
            trial_counter = trial_counter + 1;
        end

        trial_freq_lines(end+1) = trial_counter - 0.5; % separator line
    end

    % Raster plot
    figure('Visible','off','Color','w','Position',[200 100 600 800]);
    plot(all_rel_times, all_trial_labels, 'k.', 'MarkerSize', 3); hold on;
    xline(0, 'r--');

    % Horizontal separators
    for l = 1:length(trial_freq_lines)
        yline(trial_freq_lines(l), 'Color', [0.5 0.5 0.5], 'LineStyle', '-');
    end

    xlim([-half_win_s half_win_s]);
    ylim([0.5 trial_counter - 0.5]);
    xlabel('Time (s)');
    ylabel('Trial');

    % Add secondary Y axis with frequency labels
    yyaxis right
    set(gca,'YColor','k');
    yticks_pos = [];
    yticks_lab = {};

    for f = 1:length(freq_values)
        trials_f = find(freq_id_per_trial == f);
        if isempty(trials_f), continue; end
        ycenter = mean([min(trials_f), max(trials_f)]);
        yticks_pos(end+1) = ycenter;
        yticks_lab{end+1} = freq_labels{f};
    end

    yticks(yticks_pos);
    yticklabels(yticks_lab);
    ylim([0.5 trial_counter - 0.5]);
    ylabel('Frequency');

    title(sprintf('Frequency Raster – Ch %d', real_chan));

    saveas(gcf, fullfile(Freqraster_dir, ...
        sprintf('raster_Frequency_chan%d.png', real_chan)));
    close(gcf);
end

%% Raster-like Heatmap of Firing Rate per Trial

heatmap_rate_raster_dir = fullfile(freq_dir, 'raster_heatmap_firingrate');
if ~exist(heatmap_rate_raster_dir, 'dir'); mkdir(heatmap_rate_raster_dir); end

% Parameters
bin_size_ms = 100;
psth_win_s = 2;

bin_size_s = bin_size_ms / 1000;
half_win_s = psth_win_s / 2;
bin_edges = -half_win_s : bin_size_s : half_win_s;
bin_centers = bin_edges(1:end-1) + bin_size_s/2;

freq_labels = {'8Hz','12Hz','16Hz','20Hz','24Hz','28Hz','WN','WNcrescendo'};
freq_values = 2:9;

for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));
    fprintf('\nGenerating firing-rate raster heatmap – Channel %d\n', real_chan);

    sp_time_sec = double(sp_time) / samp_freq;

    firing_matrix = [];      % trial × time
    freq_id_per_trial = [];  % one label per trial
    trial_freq_lines = [];
    trial_counter = 1;

    for f = 1:length(freq_values)
        freq_val = freq_values(f);
        trial_idx = find(freq_code == freq_val);
        nTrials = length(trial_idx);

        if nTrials == 0, continue; end

        for t = 1:nTrials
            t0_sample = events_TTL_audio_ON(trial_idx(t));
            t0_sec = double(t0_sample) / samp_freq;
            spk_window = sp_time_sec(sp_time_sec >= (t0_sec - half_win_s) & sp_time_sec <= (t0_sec + half_win_s));
            rel_spikes = spk_window - t0_sec;

            % Bin this trial
            counts = histcounts(rel_spikes, bin_edges);
            rate = counts / bin_size_s;
            firing_matrix(end+1, :) = rate;
            freq_id_per_trial(end+1) = f;
            trial_counter = trial_counter + 1;
        end

        trial_freq_lines(end+1) = trial_counter - 0.5;
    end

    if isempty(firing_matrix)
        warning('No valid spikes for channel %d – skipping.', real_chan);
        continue
    end

    % Plot heatmap
    figure('Visible','off','Color','w','Position',[200 100 600 800]);
    imagesc(bin_centers, 1:size(firing_matrix,1), firing_matrix);
    colormap(parula);
    colorbar;
    xline(0, 'r--');
    xlabel('Time (s)');
    ylabel('Trial');
    title(sprintf('Firing Rate Raster – Ch %d', real_chan));

    % Horizontal frequency separators
    for l = 1:length(trial_freq_lines)
        yline(trial_freq_lines(l), 'Color', [0.5 0.5 0.5], 'LineStyle', '-');
    end

    % Secondary Y axis with frequency labels
    yyaxis right
    set(gca,'YColor','k');
    yticks_pos = [];
    yticks_lab = {};

    for f = 1:length(freq_values)
        trials_f = find(freq_id_per_trial == f);
        if isempty(trials_f), continue; end
        ycenter = mean([min(trials_f), max(trials_f)]);
        yticks_pos(end+1) = ycenter;
        yticks_lab{end+1} = freq_labels{f};
    end

    yticks(yticks_pos);
    yticklabels(yticks_lab);
    ylim([0.5 size(firing_matrix,1) + 0.5]);
    ylabel('Frequency');

    saveas(gcf, fullfile(heatmap_rate_raster_dir, ...
        sprintf('raster_FR_heatmap_chan%d.png', real_chan)));
    close(gcf);
end


%% METRIC EXPORT PER CHANNEL

% Create output folder
quantDir = fullfile(fig_dir, 'Quantification');
if ~exist(quantDir, 'dir'), mkdir(quantDir); end

% Frequency codes
freq_labels = {'8Hz','12Hz','16Hz','20Hz','24Hz','28Hz','WN','WNcrescendo'};
freq_values = 2:9;
nFreqs = numel(freq_values);

% Parameters
baseline_window_s = 50;       % 50 seconds
stim_window_s = 0.4;           % 400 ms
pre_window_s = 0.4;            % for dF/F baseline

% TTL onset times (in seconds)
ttl_times_sec = double(events_TTL_audio_ON) / samp_freq;
nTrials = length(ttl_times_sec);

% Loop through channels
for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));
    fprintf('\n→ Quantifying channel %d...\n', real_chan);

    % Spikes for this channel
    sp_times_sec = double(spikeTimes(sp_mask)) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));

    % GLOBAL METRICS

    % Baseline: 150 s before first TTL
    base_start = ttl_times_sec(1) - baseline_window_s;
    base_end = ttl_times_sec(1);
    base_spk_idx = sp_times_sec >= base_start & sp_times_sec < base_end;
    base_count = sum(base_spk_idx);
    base_rate = base_count / baseline_window_s;
    base_amp = mean(sp_amps(base_spk_idx), 'omitnan');

    % Stimulus window: 0–0.4s after each TTL
    stim_spike_count = 0;
    stim_amps = [];

    for t = 1:nTrials
        t0 = ttl_times_sec(t);
        in_window = sp_times_sec >= t0 & sp_times_sec < t0 + stim_window_s;
        stim_spike_count = stim_spike_count + sum(in_window);
        stim_amps = [stim_amps; sp_amps(in_window)];
    end

    stim_rate = stim_spike_count / (nTrials * stim_window_s);
    stim_amp = mean(stim_amps, 'omitnan');

    % dF/F: based on 400ms before TTL vs 400ms after
    pre_spike_count = 0;
    for t = 1:nTrials
        t0 = ttl_times_sec(t);
        in_pre = sp_times_sec >= (t0 - pre_window_s) & sp_times_sec < t0;
        pre_spike_count = pre_spike_count + sum(in_pre);
    end

    pre_rate = pre_spike_count / (nTrials * pre_window_s);
    delta_rate_Hz = stim_rate - pre_rate;

    % Store global metrics
    GlobalMetrics = table;
    GlobalMetrics.BaselineSpikeCount = base_count;
    GlobalMetrics.BaselineFiringRate_Hz = base_rate;
    GlobalMetrics.BaselineAmplitude_uV = base_amp;
    GlobalMetrics.Stim400ms_SpikeCount = stim_spike_count;
    GlobalMetrics.Stim400ms_FiringRate_Hz = stim_rate;
    GlobalMetrics.Stim400ms_Amplitude_uV = stim_amp;
    GlobalMetrics.DeltaRate_Hz = delta_rate_Hz;

    %PER FREQUENCY METRICS

    freq_spike_count = zeros(nFreqs,1);
    freq_firing_rate = zeros(nFreqs,1);
    freq_amplitude = NaN(nFreqs,1);
    freq_df_f = NaN(nFreqs,1);

    for f = 1:nFreqs
        curr_freq = freq_values(f);  % temporary name
        trial_idx = find(freq_code == curr_freq);

        if isempty(trial_idx), continue; end

        total_spikes = 0;
        total_pre = 0;
        all_amps = [];

        for t = trial_idx(:)'  % go over trials with this frequency
            t0 = ttl_times_sec(t);
            in_stim = sp_times_sec >= t0 & sp_times_sec < t0 + stim_window_s;
            in_pre  = sp_times_sec >= (t0 - pre_window_s) & sp_times_sec < t0;

            total_spikes = total_spikes + sum(in_stim);
            total_pre = total_pre + sum(in_pre);
            all_amps = [all_amps; sp_amps(in_stim)];
        end

        freq_spike_count(f) = total_spikes;
        freq_firing_rate(f) = total_spikes / (length(trial_idx) * stim_window_s);
        freq_amplitude(f) = mean(all_amps, 'omitnan');

        pre_rate_f = total_pre / (length(trial_idx) * pre_window_s);
        stim_rate_f = freq_firing_rate(f);
        freq_df_f(f) = stim_rate_f - pre_rate_f;  % delta rate
    end



    PerFrequency = table(freq_labels', freq_spike_count, freq_firing_rate, freq_amplitude, freq_df_f, ...
        'VariableNames', {'Frequency', 'SpikeCount', 'FiringRate_Hz', 'Amplitude_uV', 'DeltaRate_Hz'});

    %SAVE TO XLSX

    xls_name = fullfile(quantDir, sprintf('Ch%d_Quantification.xlsx', real_chan));
    writetable(GlobalMetrics, xls_name, 'Sheet', 'GlobalMetrics');
    writetable(PerFrequency, xls_name, 'Sheet', 'PerFrequency');
end

fprintf('\n✓ Channel quantifications saved to %s\n', quantDir);
%% %% METRIC EXPORT PER CHANNEL

% Create output folder
quantDir = fullfile(fig_dir, 'Quantification100ms');
if ~exist(quantDir, 'dir'), mkdir(quantDir); end

% Frequency codes
freq_labels = {'8Hz','12Hz','16Hz','20Hz','24Hz','28Hz','WN','WNcrescendo'};
freq_values = 2:9;
nFreqs = numel(freq_values);

% Parameters
baseline_window_s = 50;       % 150 seconds
stim_window_s = 0.1;           % 100 ms
pre_window_s = 0.1;            % for dF/F baseline

% TTL onset times (in seconds)
ttl_times_sec = double(events_TTL_audio_ON) / samp_freq;
nTrials = length(ttl_times_sec);

% Loop through channels
for jj = 1:64
    real_chan = chans_to_process(jj);

    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);

    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end

    % EXTRACT spikes specifically for this site
    sp_mask = (spikeSites == site_id);
    sp_time = spikeTimes(sp_mask);
    sp_times_sec = double(sp_time) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));
    fprintf('\n→ Quantifying channel %d...\n', real_chan);

    % Spikes for this channel
    sp_mask = (spikeSites == site_id);
    sp_times_sec = double(spikeTimes(sp_mask)) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));

    % GLOBAL METRICS

    % Baseline: 150s before first TTL
    base_start = ttl_times_sec(1) - baseline_window_s;
    base_end = ttl_times_sec(1);
    base_spk_idx = sp_times_sec >= base_start & sp_times_sec < base_end;
    base_count = sum(base_spk_idx);
    base_rate = base_count / baseline_window_s;
    base_amp = mean(sp_amps(base_spk_idx), 'omitnan');

    % Stimulus window: 0–0.4s after each TTL
    stim_spike_count = 0;
    stim_amps = [];

    for t = 1:nTrials
        t0 = ttl_times_sec(t);
        in_window = sp_times_sec >= t0 & sp_times_sec < t0 + stim_window_s;
        stim_spike_count = stim_spike_count + sum(in_window);
        stim_amps = [stim_amps; sp_amps(in_window)];
    end

    stim_rate = stim_spike_count / (nTrials * stim_window_s);
    stim_amp = mean(stim_amps, 'omitnan');

    % dF/F: based on 100ms before TTL vs 100ms after
    pre_spike_count = 0;
    for t = 1:nTrials
        t0 = ttl_times_sec(t);
        in_pre = sp_times_sec >= (t0 - pre_window_s) & sp_times_sec < t0;
        pre_spike_count = pre_spike_count + sum(in_pre);
    end

    pre_rate = pre_spike_count / (nTrials * pre_window_s);
    delta_rate_Hz = stim_rate - pre_rate;

    % Store global metrics
    GlobalMetrics = table;
    GlobalMetrics.BaselineSpikeCount = base_count;
    GlobalMetrics.BaselineFiringRate_Hz = base_rate;
    GlobalMetrics.BaselineAmplitude_uV = base_amp;
    GlobalMetrics.Stim100ms_SpikeCount = stim_spike_count;
    GlobalMetrics.Stim100ms_FiringRate_Hz = stim_rate;
    GlobalMetrics.Stim100ms_Amplitude_uV = stim_amp;
    GlobalMetrics.DeltaRate_Hz = delta_rate_Hz;

    % PER FREQUENCY METRICS

    freq_spike_count = zeros(nFreqs,1);
    freq_firing_rate = zeros(nFreqs,1);
    freq_amplitude = NaN(nFreqs,1);
    freq_df_f = NaN(nFreqs,1);

    for f = 1:nFreqs
        curr_freq = freq_values(f);  % temporary name
        trial_idx = find(freq_code == curr_freq);

        if isempty(trial_idx), continue; end

        total_spikes = 0;
        total_pre = 0;
        all_amps = [];

        for t = trial_idx(:)'  % go over trials with this frequency
            t0 = ttl_times_sec(t);
            in_stim = sp_times_sec >= t0 & sp_times_sec < t0 + stim_window_s;
            in_pre  = sp_times_sec >= (t0 - pre_window_s) & sp_times_sec < t0;

            total_spikes = total_spikes + sum(in_stim);
            total_pre = total_pre + sum(in_pre);
            all_amps = [all_amps; sp_amps(in_stim)];
        end

        freq_spike_count(f) = total_spikes;
        freq_firing_rate(f) = total_spikes / (length(trial_idx) * stim_window_s);
        freq_amplitude(f) = mean(all_amps, 'omitnan');

        pre_rate_f = total_pre / (length(trial_idx) * pre_window_s);
        stim_rate_f = freq_firing_rate(f);
        freq_df_f(f) = stim_rate_f - pre_rate_f;  % delta rate
    end



    PerFrequency = table(freq_labels', freq_spike_count, freq_firing_rate, freq_amplitude, freq_df_f, ...
        'VariableNames', {'Frequency', 'SpikeCount', 'FiringRate_Hz', 'Amplitude_uV', 'DeltaRate_Hz_200ms'});

    % SAVE TO XLSX

    xls_name = fullfile(quantDir, sprintf('Ch%d_Quantification.xlsx', real_chan));
    writetable(GlobalMetrics, xls_name, 'Sheet', 'GlobalMetrics');
    writetable(PerFrequency, xls_name, 'Sheet', 'PerFrequency');
end

fprintf('\n✓ Channel quantifications saved to %s\n', quantDir);

%% 4. GENERATE PSTH CSV (FOR GRAPHPAD)
siteMap = [59,57,55,52,54,48,64,62,49,61,63,53,51,56,58,60,33,35,37,39,41,43,45,47,50,46,44,42,40,38,36,34,31,29,27,25,23,21,19,17,16,20,22,24,26,28,30,32,5,7,9,14,12,18,2,4,15,3,1,11,13,10,8,6,65,66,67,68,69,70,71,72];
% SETUP DIRECTORIES & PARAMS
fig_dir = fullfile(PathName, 'Figures');
mkdir(fullfile(fig_dir, 'psth_csv'));

% Freq parameters
freq_code = csvread('C:\Users\ATOMIC\Desktop\SReis\OpenEphys\OE_evoked_HARP\Second Protocol_ TTL + WN\random_sequence.csv');
% Window parameters (matches your 400ms stim logic)
pre_t = 0.4; stim_t = 0.4; post_t = 0.2;
bin_size_s = 0.01; % 10ms
psth_edges = -pre_t : bin_size_s : (stim_t + post_t);
bin_centers = psth_edges(1:end-1) + bin_size_s/2;

for jj = 1:64
    real_chan = chans_to_process(jj);

    % 1. CORRECT CHANNEL MAPPING
    site_id = find(siteMap == real_chan);
    if isempty(site_id), continue; end

    % Get spikes for this site
    sp_mask = (spikeSites == site_id);
    sp_time_sec = double(spikeTimes(sp_mask)) / samp_freq;
    sp_amps = double(spikeAmps(sp_mask));

    fprintf('Processing Ch %d (Site %d)...\n', real_chan, site_id);

    all_rel_times = [];
    all_trial_ids = [];

    % 2. ALIGN SPIKES TO TTLs
    for t = 3:min(length(events_TTL_audio_ON), length(freq_code))
        t0 = double(events_TTL_audio_ON(t)) / samp_freq;
        in_win = sp_time_sec(sp_time_sec >= t0-pre_t & sp_time_sec <= t0+stim_t+post_t) - t0;
        all_rel_times = [all_rel_times; in_win(:)];
        all_trial_ids = [all_trial_ids; t * ones(size(in_win(:)))];
    end

    if isempty(all_rel_times), continue; end
    bin_idx = discretize(all_rel_times, psth_edges);
    valid = ~isnan(bin_idx);
    counts = accumarray(bin_idx(valid), 1, [length(psth_edges)-1, 1]);
    % Normalize to Hz (Total Trials * bin_size)
    nTrialsUsed = max(all_trial_ids) - 2;
    avg_firing_rate = counts / (nTrialsUsed * bin_size_s);

    T_psth = table(bin_centers', avg_firing_rate, 'VariableNames', {'Time_s', 'FiringRate_Hz'});
    writetable(T_psth, fullfile(fig_dir, 'psth_csv', sprintf('psth_ch%d.csv', real_chan)));
end

fprintf('\nDone! Everything is saved in: %s\n', fig_dir);

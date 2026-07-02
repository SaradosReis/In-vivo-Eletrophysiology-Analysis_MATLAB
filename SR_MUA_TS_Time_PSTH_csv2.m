%% SR_MUA_TS_IntervalBins_csv_withBaselineDelta
% Bin spikes into user-defined time intervals (no TTLs).
% Exports per-channel CSVs with: Time_s, Value, Interval, Channel, OutputKind
% PLUS baseline-referenced columns: DeltaFromBL, PercentFromBL, ZscoreFromBL.
%
% Baseline is taken from the interval named ref_interval_name (e.g., 'baseline')
% This is for instance to check the CNO effect
clear all; close all; clc;

%% Create folder to save figures (CSV folder will be inside)
% mkdir Figures
% addpath Figures

%% INPUT PARAMS
samp_freq = 30000;      % sampling frequency (Hz)
nchan     = 72;
nshanks   = 4;

% 4-shank cambridge (64chan) + AUX mapped from Code 2
siteMap = [59,57,55,52,54,48,64,62,49,61,63,53,51,56,58,60, ...
           33,35,37,39,41,43,45,47,50,46,44,42,40,38,36,34, ...
           31,29,27,25,23,21,19,17,16,20,22,24,26,28,30,32, ...
           5,7,9,14,12,18,2,4,15,3,1,11,13,10,8,6, ...
           65,66,67,68,69,70,71,72];

chans_to_open = siteMap(1:64); % Process the first 64 channels by default

% ====== Define analysis intervals (in seconds) ======
intervals = struct( ...
    'name', {'baseline','stimulus'}, ...
    't0',   {0,               5*60}, ...
    't1',   {5*60,           30*60} ...
);

% ---- OUTPUT CONFIG ----
bin_size_ms       = 60000;       % try 50–200 ms or 1000 ms for per-second bins
output_mode       = 'rate';      % 'rate'|'count'|'binary'|'prob'
prob_window_s     = 1.0;         % only for 'prob': rolling-mean window (s)
smooth_sigma_ms   = 0;           % optional Gaussian smoothing AFTER output (0=skip)
normalize_to_unit = false;       % true to rescale each interval to [0,1] before deltas

% ---- BASELINE REFERENCE CONFIG ----
ref_interval_name = 'baseline';  % which interval defines baseline
baseline_stat     = 'mean';      % 'mean' or 'median' (for BL center)
baseline_spread   = 'std';       % 'std' or 'mad'    (for BL variability)
export_interval_summary = true;  % also save per-interval mean/sem per channel

bin_size_s  = bin_size_ms / 1000;

% Channels to process (index in 'chans_to_open'); set 1:64 to skip AUX
process_idx = 1:numel(chans_to_open);

%% LOAD FILE
[FileName,PathName] = uigetfile('.dat'); % select file
if isequal(FileName,0)
    error('No .dat file selected.');
end
contFile = fullfile(PathName,FileName);
s = dir(contFile);
file_size = s.bytes;
samples = file_size/2/nchan;
m = memmapfile(contFile,'Format',{'int16' [nchan samples] 'mapped'});
data = m.Data; %#ok<NASGU>
duration_in_sec = size(double(m.Data.mapped(1,:)),2) / samp_freq;
fprintf('Recording duration ~ %.2f s (%.2f min)\n', duration_in_sec, duration_in_sec/60);

%% USE JRCLUST FOR SPIKE DETECTION
 % jrc detect continuous_4shank_ASSY-77_E1_72channels.prm

%% Load JRClust spike detection results for the recording
load('manual_detected_res.mat', ...
     'spikeTimes', 'spikeSites', 'spikeAmps');
if ~exist('spikeTimes','var') || ~exist('spikeSites','var')
    error('spikeTimes or spikeSites not found in the loaded *_res.mat file.');
end
if ~exist('spikeAmps','var')
    error('spikeAmps not found in the loaded *_res.mat file.');
end

%% Map JRClust site index (Imported from Code 2)
nSites = max(spikeSites);
chan_for_site = siteMap(:); 
if numel(chan_for_site) < nSites
    chan_for_site(nSites) = NaN;           
    warning('siteMap has fewer entries than detected sites. Padding with NaN.');
end
spikeChans_abs = chan_for_site(spikeSites);

fprintf('\n--- Mapping Diagnostics ---\n');
fprintf('Max JRClust site index: %d\n', nSites);
fprintf('Total spikes processed: %d\n', numel(spikeSites));
in_list = ismember(spikeChans_abs, siteMap);
fprintf('Spikes successfully mapped to siteMap: %d / %d (%.1f%%)\n', ...
    sum(in_list), numel(spikeChans_abs), 100*mean(in_list));
nAuxSpikes = sum(spikeSites > 64);
fprintf('Spikes detected on AUX sites (>64): %d\n', nAuxSpikes);

%% Prepare output folder
fig_dir = fullfile(PathName, 'Figures');
csv_dir = fullfile(fig_dir, 'IntervalBins_csv');
if ~exist(csv_dir, 'dir'); mkdir(csv_dir); end

%% Truncate intervals to recording duration
for k = 1:numel(intervals)
    if intervals(k).t0 >= intervals(k).t1
        error('Interval "%s" has t0 >= t1.', intervals(k).name);
    end
    if intervals(k).t0 < 0 || intervals(k).t1 > duration_in_sec
        warning('Interval "%s" [%g,%g] exceeds bounds [0,%g]; truncating.', ...
            intervals(k).name, intervals(k).t0, intervals(k).t1, duration_in_sec);
        intervals(k).t0 = max(intervals(k).t0, 0);
        intervals(k).t1 = min(intervals(k).t1, duration_in_sec);
    end
end
% Find baseline interval index
ref_k = find(strcmp({intervals.name}, ref_interval_name), 1, 'first');
if isempty(ref_k)
    error('Baseline interval "%s" not found in intervals.', ref_interval_name);
end

%% Helper funcs for baseline center/spread
get_center = @(x) (strcmpi(baseline_stat,'median') * median(x) + ...
                   strcmpi(baseline_stat,'mean')   * mean(x));
get_spread = @(x) (strcmpi(baseline_spread,'mad') * mad(x,1) + ...
                   strcmpi(baseline_spread,'std') * std(x,0,1));

%% Export CSV per channel
fprintf('\n=== Exporting interval-binned CSVs (%s) with baseline deltas for %d channels ===\n', output_mode, numel(process_idx));
% Pre-allocate summary cell (optional)
if export_interval_summary
    summary_all = {};
    summary_hdr = {'Channel','OutputKind','Interval','Mean','SEM','N_Bins','BL_Mean','BL_Spread'};
end

for ii = process_idx
    real_chan = chans_to_open(ii);  % physical channel label for naming
    
    % FIND the site index that corresponds to this physical channel (from Code 2)
    site_id = find(siteMap == real_chan);
    if isempty(site_id)
        warning('Channel %d not found in siteMap. Skipping.', real_chan);
        continue;
    end
    jj = site_id; % site index as used in spikeSites
    
    fprintf('→ Channel %d (site idx %d)\n', real_chan, jj);
    
    % Spike times for this site
    sp_time = spikeTimes(spikeSites == jj);
    if isempty(sp_time)
        warning('No spikes for channel %d (site %d). Skipping.', real_chan, jj);
        continue
    end
    sp_time_sec = double(sp_time) / samp_freq;
    
    % First pass: build per-interval tables and collect baseline values
    T_all = [];
    BL_values = [];  % baseline Value series (for center/spread)
    
    for k = 1:numel(intervals)
        t0 = intervals(k).t0;
        t1 = intervals(k).t1;
        
        % Bin edges
        edges = t0:bin_size_s:t1;
        if edges(end) < t1
            edges = [edges, t1];
        end
        if numel(edges) < 2
            continue
        end
        
        % Spikes in interval
        in_win = (sp_time_sec >= t0) & (sp_time_sec <= t1);
        sp_i   = sp_time_sec(in_win);
        
        % Bin counts
        counts          = histcounts(sp_i, edges);
        bin_centers     = (edges(1:end-1) + edges(2:end))/2;
        bin_durations   = diff(edges);
        bin_size_s_eff  = median(bin_durations);
        
        % Compute requested output
        switch lower(output_mode)
            case 'rate'       % Hz
                y = counts(:) ./ bin_durations(:);
            case 'count'      % spikes/bin
                y = counts(:);
            case 'binary'     % 0/1
                y = double(counts(:) > 0);
            case 'prob'       % rolling probability 0..1
                bin_binary = double(counts(:) > 0);
                w_bins = max(1, round(prob_window_s / bin_size_s_eff));
                y = movmean(bin_binary, w_bins, 'Endpoints', 'shrink');
            otherwise
                error('Unknown output_mode "%s".', output_mode);
        end
        
        % Optional smoothing AFTER output
        if smooth_sigma_ms > 0
            sigma_bins = max(1, round((smooth_sigma_ms/1000) / bin_size_s_eff));
            r = -3*sigma_bins : 3*sigma_bins;
            g = exp(-(r.^2) / (2*sigma_bins^2));
            g = g / sum(g);
            y = conv(y, g(:), 'same');
        end
        
        % Optional normalization BEFORE deltas (interval-wise)
        if normalize_to_unit
            ymin = min(y); ymax = max(y);
            if ymax > ymin, y = (y - ymin) / (ymax - ymin); else, y = zeros(size(y)); end
        end
        
        % Collect baseline values
        if k == ref_k
            BL_values = [BL_values; y(:)];
        end
        
        % Pack interval table (deltas filled later)
        T_k = table( ...
            bin_centers(:), ...
            y(:), ...
            repmat(string(intervals(k).name), numel(y), 1), ...
            repmat(real_chan, numel(y), 1), ...
            repmat(string(output_mode), numel(y), 1), ...
            nan(numel(y),1), nan(numel(y),1), nan(numel(y),1), ...
            'VariableNames', {'Time_s','Value','Interval','Channel','OutputKind', ...
                              'DeltaFromBL','PercentFromBL','ZscoreFromBL'} ...
        );
        
        % Accumulate
        if isempty(T_all), T_all = T_k; else, T_all = [T_all; T_k]; %#ok<AGROW> 
        end
        
        % Optional: gather summary per interval for this channel
        if export_interval_summary
            mu  = mean(y);
            se  = std(y) / sqrt(max(1, numel(y)));
            summary_all(end+1, :) = {real_chan, output_mode, char(intervals(k).name), mu, se, numel(y), NaN, NaN}; %#ok<AGROW>
        end
    end
    
    if isempty(T_all)
        warning('No bins produced for channel %d.', real_chan);
        continue
    end
    
    % Compute baseline reference for this channel
    if isempty(BL_values)
        warning('No baseline data for channel %d; delta columns remain NaN.', real_chan);
        BL_center = NaN; BL_spread_val = NaN;
    else
        % center
        switch lower(baseline_stat)
            case 'median', BL_center = median(BL_values);
            otherwise,     BL_center = mean(BL_values);
        end
        % spread
        switch lower(baseline_spread)
            case 'mad', BL_spread_val = mad(BL_values,1);
            otherwise,  BL_spread_val = std(BL_values);
        end
        
        % Fill deltas
        T_all.DeltaFromBL   = T_all.Value - BL_center;
        if BL_center ~= 0
            T_all.PercentFromBL = 100 * (T_all.Value - BL_center) / BL_center;
        else
            T_all.PercentFromBL = NaN(height(T_all),1);
        end
        if BL_spread_val > 0
            T_all.ZscoreFromBL  = (T_all.Value - BL_center) / BL_spread_val;
        else
            T_all.ZscoreFromBL  = NaN(height(T_all),1);
        end
    end
    
    % Sort by time and save
    T_all = sortrows(T_all, 'Time_s');
    csv_file = fullfile(csv_dir, sprintf('interval_bins_%s_chan%d.csv', lower(output_mode), real_chan));
    writetable(T_all, csv_file);
    
    % Back-fill BL stats into summary rows for this channel
    if export_interval_summary && ~isempty(BL_values)
        for r = 1:size(summary_all,1)
            if summary_all{r,1} == real_chan
                summary_all{r,7} = BL_center;
                summary_all{r,8} = BL_spread_val;
            end
        end
    end
end
fprintf('\n✓ Interval-binned CSVs saved to %s\n', csv_dir);

%% ---- SUMMARY: Firing rate + amplitude in first 5 min and last 5 min per channel ----
fprintf('\n=== Computing 5-min firing-rate + amplitude summary per channel ===\n');
summary_FR = [];  % will become a table later
FR_first5   = zeros(numel(process_idx),1);
FR_last5    = zeros(numel(process_idx),1);
Amp_first5  = NaN(numel(process_idx),1);
Amp_last5   = NaN(numel(process_idx),1);
ChanList    = zeros(numel(process_idx),1);

rec_duration = duration_in_sec;
first5_t0    = 0;
first5_t1    = min(300, rec_duration);           % 5 minutes = 300 s
last5_t1     = rec_duration;
last5_t0     = max(0, rec_duration - 300);

for ii = process_idx
    real_chan   = chans_to_open(ii);
    
    % FIND the site index that corresponds to this physical channel
    site_id = find(siteMap == real_chan);
    if isempty(site_id)
        continue;
    end
    jj = site_id;                      % site index in spikeSites
    
    ChanList(ii)= real_chan;
    
    % spikes for this site
    sp_mask     = (spikeSites == jj);
    sp_time     = spikeTimes(sp_mask);
    sp_time_sec = double(sp_time) / samp_freq;
    sp_amps     = double(spikeAmps(sp_mask));   % same spikes -> same indices
    
    % ---- first 5 min ----
    in_first5        = (sp_time_sec >= first5_t0) & (sp_time_sec < first5_t1);
    FR_first5(ii)    = sum(in_first5) / max(eps, (first5_t1 - first5_t0));   % Hz
    Amp_first5(ii)   = mean(abs(sp_amps(in_first5)), 'omitnan');            % mean |amp|
    
    % ---- last 5 min ----
    in_last5         = (sp_time_sec >= last5_t0) & (sp_time_sec <= last5_t1);
    FR_last5(ii)     = sum(in_last5) / max(eps, (last5_t1 - last5_t0));     % Hz
    Amp_last5(ii)    = mean(abs(sp_amps(in_last5)), 'omitnan');             % mean |amp|
end

% Build table
Summary5min = table(ChanList(:), FR_first5(:), FR_last5(:), ...
                    Amp_first5(:), Amp_last5(:), ...
    'VariableNames', {'Channel', 'FR_first5min_Hz', 'FR_last5min_Hz', ...
                      'Amp_first5min', 'Amp_last5min'});

% Save
sum5_file = fullfile(csv_dir, 'summary_5min_FiringRates.csv');
writetable(Summary5min, sum5_file);
fprintf('✓ 5-min firing-rate + amplitude summary saved to %s\n', sum5_file);

%% Optional: export per-interval summary across bins per channel
if export_interval_summary && ~isempty(summary_all)
    SummaryTbl = cell2table(summary_all, 'VariableNames', summary_hdr);
    sum_file = fullfile(csv_dir, sprintf('interval_summary_%s.csv', lower(output_mode)));
    writetable(SummaryTbl, sum_file);
    fprintf('✓ Interval summary saved to %s\n', sum_file);
end
# In-vivo-Eletrophysiology-Analysis_MATLAB

About the SR_MUA_TS_TTL_perAudio.m:
This MATLAB script processes raw extracellular neurophysiological data to analyze auditory-evoked neural activity across multi-shank multi-channel silicon probes (e.g., Cambridge NeuroTech probes). It maps physical hardware channels, integrates spike sorting outputs from EphysInspector or JRClust, and aligns neural events with external TTL pulses denoting distinct auditory stimuli.

To use this pipeline you need the following:
- .dat file (from your recording)
- res.mat file (either from JRCluster or from the EphysInspector)
- Auditory Sequence (.csv)

The pipeline automatically creates a structured Figures/ folder containing the following analytical plots for each processed channel:
-  Raster Plots: Displays individual spike events across all trials relative to the sound onset
  <img width="938" height="1250" alt="raster_Frequency_chan58" src="https://github.com/user-attachments/assets/687a180c-b60d-4943-82dc-cd2137a4ba8e" />
  <img width="875" height="656" alt="raster_chan58" src="https://github.com/user-attachments/assets/11299d38-9e71-4a9d-be44-f63516c7f56d" />

-  PSTH: Computes smooth, Gaussian-filtered  delta firing rates) with standard error of the mean
<img width="703" height="359" alt="psth_chan58" src="https://github.com/user-attachments/assets/976316c1-01f4-4629-bef9-a3f99d212022" />

-  Firing Rate Heatmaps: Renders a time-by-trial intensity matrix highlighting trial-by-trial dynamics and variations over the course of the session.
-  Global Metrics: Baseline firing rates vs. stimulus-evoked rates
-  Per-Frequency Metrics

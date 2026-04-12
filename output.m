clc;
clear;
close all;

%% ================================================================
%  compare_outputs.m
%  Runs both pipelines (MATLAB-only & Simulink) and compares them.
%
%  Requirements:
%    - stdmdl_2.m and fix.m must be on the MATLAB path (or same folder)
%    - Simulink model 'dsp_proj_v3_2024_n_2024b.slx' must be available
%      for the Simulink branch to execute.
%
%  Outputs:
%    Figure 1 – Real parts overlaid (time domain)
%    Figure 2 – Imaginary parts overlaid (time domain)
%    Figure 3 – Magnitude spectra overlaid (frequency domain)
%    Figure 4 – Complex difference signal (time domain)
%    Figure 5 – Spectrum of the difference signal
%    Console   – RMSE and peak error statistics
%% ================================================================

%% ---------------------------------------------------------------
%  BLOCK 1 – Run the MATLAB-only model (stdmdl_2.m internals)
%  (copied inline so we can capture 'y' without side effects)
%% ---------------------------------------------------------------
fprintf('=== Running MATLAB-only model ===\n');

N      = 3000;
Fsf    = 60e6;
Fs1    = 10e6;
Fs2    = 15e6;
Fs3    = 20e6;

n  = (0:N-1)';
t1 = n / Fs1;
t2 = n / Fs2;
t3 = n / Fs3;

f1 = 1e6;  x1 = exp(1j*2*pi*f1*t1);
f2 = 2e6;  x2 = exp(1j*2*pi*f2*t2);
f3 = 3e6;  x3 = exp(1j*2*pi*f3*t3);

x1_up = upsample(x1, 6);
x2_up = upsample(x2, 4);
x3_up = upsample(x3, 3);

% d_1 = designfilt('lowpassfir','PassbandFrequency',0.18, ...
%     'StopbandFrequency',0.24,'PassbandRipple',0.1, ...
%     'StopbandAttenuation',80,'DesignMethod','equiripple');
% b_1 = d_1.Coefficients;
% 
% d_2 = designfilt('lowpassfir','PassbandFrequency',0.25, ...
%     'StopbandFrequency',0.35,'PassbandRipple',0.1, ...
%     'StopbandAttenuation',80,'DesignMethod','equiripple');
% b_2 = d_2.Coefficients;
% 
% d_3 = designfilt('lowpassfir','PassbandFrequency',0.3, ...
%     'StopbandFrequency',0.35,'PassbandRipple',0.1, ...
%     'StopbandAttenuation',80,'DesignMethod','equiripple');
% b_3 = d_3.Coefficients;
d_1 = designfilt('lowpassfir', ...
    'FilterOrder', 40, ...
    'PassbandFrequency', 0.18, ...
    'StopbandFrequency', 0.24, ...
    'DesignMethod', 'equiripple');
b_1 = d_1.Coefficients;

% Filter 2
d_2 = designfilt('lowpassfir', ...
    'FilterOrder', 40, ...
    'PassbandFrequency', 0.25, ...
    'StopbandFrequency', 0.35, ...
    'DesignMethod', 'equiripple');
b_2 = d_2.Coefficients;

% Filter 3
d_3 = designfilt('lowpassfir', ...
    'FilterOrder', 40, ...
    'PassbandFrequency', 0.3, ...
    'StopbandFrequency', 0.35, ...
    'DesignMethod', 'equiripple');
b_3 = d_3.Coefficients;

y1 = 5 * downsample(filter(b_1, 1, x1_up), 5);
y2 = 5 * downsample(filter(b_2, 1, x2_up), 5);
y3 = 5 * downsample(filter(b_3, 1, x3_up), 5);

olen = min([length(y1), length(y2), length(y3)]);
y1 = y1(1:olen);
y2 = y2(1:olen);
y3 = y3(1:olen);
y_sum = y1 + y2 + y3;

% Remove transient (same as stdmdl_2.m)
start_std = 300;
y_matlab  = y_sum(start_std:end);          % complex column vector

% Build a uniform time axis at the OUTPUT rate
% After upsample-by-6 and downsample-by-5, effective rate = Fs1*6/5 = 12 MHz
% But the three branches share the 60 MHz grid then downsample by 5 → 12 MHz
Fs_matlab = Fsf / 5;                       % = 12 MHz output sample rate
Ts_matlab  = 1 / Fs_matlab;
t_matlab   = (0:length(y_matlab)-1)' * Ts_matlab;

fprintf('MATLAB model done. %d samples at %.1f MHz output rate.\n', ...
    length(y_matlab), Fs_matlab/1e6);

%% ---------------------------------------------------------------
%  BLOCK 2 – Run the Simulink model (fix.m internals)
%% ---------------------------------------------------------------
fprintf('\n=== Running Simulink model ===\n');

simulink_ok = false;
try
    % ---- Fixed-point quantisation & RAM init data ----
    ram1_vals = complex(fi(real(x1),1,8,6),  fi(imag(x1),1,8,6));
    ram2_vals = complex(fi(real(x2),1,10,8), fi(imag(x2),1,10,8));
    ram3_vals = complex(fi(real(x3),1,12,10),fi(imag(x3),1,12,10));

    ram1_init_data = ram1_vals; ram1_init_data(4096) = 0;
    ram2_init_data = ram2_vals; ram2_init_data(4096) = 0;
    ram3_init_data = ram3_vals; ram3_init_data(4096) = 0;

    % ---- Filter coefficients (same as above) ----
    % b_1, b_2, b_3 already computed in Block 1

    % ---- Run Simulink ----
    out = sim('dsp_proj_v3_2024_n');

    logged_signal  = out.logsout.get(1);
    final_data     = logged_signal.Values.Data;
    final_time_raw = logged_signal.Values.Time;

    y_sim_raw = double(squeeze(final_data));

    % Remove transient (same as fix.m)
    start_sim = 200;
    y_sim     = y_sim_raw(start_sim : end-1);
    t_sim_vec = final_time_raw(start_sim : end-1);
    Fs_sim    = 1 / mean(diff(t_sim_vec));

    fprintf('Simulink model done. %d samples at %.1f MHz output rate.\n', ...
        length(y_sim), Fs_sim/1e6);
    simulink_ok = true;

catch ME
    warning('Simulink run failed: %s\nOnly MATLAB model results will be plotted.', ...
        ME.message);
end

%% ---------------------------------------------------------------
%  BLOCK 3 – Align lengths for comparison
%% ---------------------------------------------------------------
if simulink_ok
    % Interpolate Simulink output onto the MATLAB time grid (or vice-versa)
    % Strategy: resample both to the longer common grid via interp1
    t_start = max(t_matlab(1),   t_sim_vec(1));
    t_end   = min(t_matlab(end), t_sim_vec(end));

    % Common uniform grid at MATLAB rate (12 MHz)
    t_common  = (t_start : Ts_matlab : t_end)';

    y_mat_c   = interp1(t_matlab,   y_matlab, t_common, 'linear');
    y_sim_c   = interp1(t_sim_vec,  y_sim,    t_common, 'linear');

    diff_sig  = y_mat_c - y_sim_c;
    L_c       = length(t_common);
    Fs_common = Fs_matlab;
end

%% ---------------------------------------------------------------
%  BLOCK 4 – Statistics
%% ---------------------------------------------------------------
if simulink_ok
    rmse_real = sqrt(mean(real(diff_sig).^2));
    rmse_imag = sqrt(mean(imag(diff_sig).^2));
    rmse_cmplx = sqrt(mean(abs(diff_sig).^2));
    peak_err  = max(abs(diff_sig));

    fprintf('\n=== Comparison Statistics ===\n');
    fprintf('  RMSE (real part)    : %.6f\n', rmse_real);
    fprintf('  RMSE (imag part)    : %.6f\n', rmse_imag);
    fprintf('  RMSE (complex mag)  : %.6f\n', rmse_cmplx);
    fprintf('  Peak |error|        : %.6f\n', peak_err);
end

%% ---------------------------------------------------------------
%  BLOCK 5 – Plotting
%% ---------------------------------------------------------------

% ---- Helper: compute two-sided amplitude spectrum ----
calc_spectrum = @(sig, Fs) deal( ...
    linspace(-Fs/2, Fs/2, length(sig)), ...
    abs(fftshift(fft(sig))) / length(sig) );

% ===== Figure 1: Real Part (Time Domain) =====
figure('Name','Real Part – Time Domain','NumberTitle','off');
plot(t_matlab*1e6, real(y_matlab), 'b', 'LineWidth', 1.2, 'DisplayName', 'MATLAB model');
if simulink_ok
    hold on;
    plot(t_sim_vec*1e6, real(y_sim), 'r--', 'LineWidth', 1.2, 'DisplayName', 'Simulink model');
end
xlabel('Time (µs)'); ylabel('Amplitude');
title('Real Part – Time Domain Comparison');
legend; grid on;

% ===== Figure 2: Imaginary Part (Time Domain) =====
figure('Name','Imaginary Part – Time Domain','NumberTitle','off');
plot(t_matlab*1e6, imag(y_matlab), 'b', 'LineWidth', 1.2, 'DisplayName', 'MATLAB model');
if simulink_ok
    hold on;
    plot(t_sim_vec*1e6, imag(y_sim), 'r--', 'LineWidth', 1.2, 'DisplayName', 'Simulink model');
end
xlabel('Time (µs)'); ylabel('Amplitude');
title('Imaginary Part – Time Domain Comparison');
legend; grid on;

% ===== Figure 3: Amplitude Spectra =====
figure('Name','Amplitude Spectra','NumberTitle','off');
[f_mat, P_mat] = calc_spectrum(y_matlab, Fs_matlab);
plot(f_mat/1e6, P_mat, 'b', 'LineWidth', 1.4, 'DisplayName', 'MATLAB model');
if simulink_ok
    hold on;
    [f_sim, P_sim] = calc_spectrum(y_sim, Fs_sim);
    plot(f_sim/1e6, P_sim, 'r--', 'LineWidth', 1.4, 'DisplayName', 'Simulink model');
end
xlabel('Frequency (MHz)'); ylabel('Amplitude');
title('Amplitude Spectrum Comparison');
legend; grid on;
xlim([-Fs_matlab/2/1e6, Fs_matlab/2/1e6]);

if simulink_ok
    % ===== Figure 4: Complex Difference (Time Domain) =====
    figure('Name','Difference Signal – Time Domain','NumberTitle','off');
    subplot(2,1,1);
    plot(t_common*1e6, real(diff_sig), 'm', 'LineWidth', 1.2);
    xlabel('Time (µs)'); ylabel('Error');
    title('Difference (Real Part): MATLAB − Simulink');
    grid on;

    subplot(2,1,2);
    plot(t_common*1e6, imag(diff_sig), 'Color',[0.6 0 0.6], 'LineWidth', 1.2);
    xlabel('Time (µs)'); ylabel('Error');
    title('Difference (Imaginary Part): MATLAB − Simulink');
    grid on;

    % ===== Figure 5: Spectrum of Difference Signal =====
    figure('Name','Difference Spectrum','NumberTitle','off');
    [f_diff, P_diff] = calc_spectrum(diff_sig, Fs_common);
    plot(f_diff/1e6, P_diff, 'Color',[0.8 0.2 0], 'LineWidth', 1.4);
    xlabel('Frequency (MHz)'); ylabel('Amplitude');
    title('Spectrum of Difference Signal (MATLAB − Simulink)');
    grid on;
    xlim([-Fs_common/2/1e6, Fs_common/2/1e6]);

    % ===== Figure 6: |error| vs time =====
    figure('Name','|Error| Magnitude vs Time','NumberTitle','off');
    plot(t_common*1e6, abs(diff_sig), 'k', 'LineWidth', 1.2);
    xlabel('Time (µs)'); ylabel('|Error|');
    title('Complex Error Magnitude vs Time');
    grid on;
    yline(rmse_cmplx, 'r--', sprintf('RMSE = %.4f', rmse_cmplx), 'LineWidth', 1.5);
end

fprintf('\nDone. Check the figures for comparison results.\n');
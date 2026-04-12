clc;
clear;
close all;

%% -------------------------------
% 1. Simulation Parameters
%% -------------------------------
N = 3000;           % Exact number of data points to load into RAM
Fs_master = 60e6;   % Master Simulation Rate (LCM of 10, 15, 20)

% Individual Sampling rates
Fs1 = 10e6;   % RAM1
Fs2 = 15e6;   % RAM2
Fs3 = 20e6;   % RAM3

%% -------------------------------
% 2. Generate Discrete Time Vectors
%% -------------------------------
% Using an index vector 'n' guarantees exactly 1000 points 
% regardless of the sampling frequency.
n = (0:N-1)'; 

t1 = n * (1/Fs1);
t2 = n * (1/Fs2);
t3 = n * (1/Fs3);

%% -------------------------------
% 3. Generate Complex Signals
%% -------------------------------
% Frequencies chosen to stay within the specified Bandwidths
f1 = 1e6; % Tone for BW 2MHz
f2 = 2e6; % Tone for BW 4MHz
f3 = 3e6; % Tone for BW 6MHz

x1 = exp(1j*2*pi*f1*t1);
x2 = exp(1j*2*pi*f2*t2);
x3 = exp(1j*2*pi*f3*t3);

%% -------------------------------
% 4. Quantization (Fixed-Point)
%% -------------------------------
% RAM1: 8-bit complex (Signed, 8 bit total, 6 fractional)
ram1_vals = complex(fi(real(x1), 1, 8, 6), fi(imag(x1), 1, 8, 6));

% RAM2: 10-bit complex (Signed, 10 bit total, 8 fractional)
ram2_vals = complex(fi(real(x2), 1, 10, 8), fi(imag(x2), 1, 10, 8));

% RAM3: 12-bit complex (Signed, 12 bit total, 10 fractional)
ram3_vals = complex(fi(real(x3), 1, 12, 10), fi(imag(x3), 1, 12, 10));

%% -------------------------------
% 5. Format for Direct RAM/Lookup Table Loading
%% -------------------------------
% We export these as pure 1D fixed-point arrays. 
% No timestamps. No timetables. Just raw data for hardware addressing.
%% -------------------------------
% 5. Format for Direct RAM Loading
%% -------------------------------
ram1_init_data = ram1_vals;
ram2_init_data = ram2_vals;
ram3_init_data = ram3_vals;

% Expand arrays to 4096 to match a 12-bit address space
ram1_init_data(4096) = 0; 
ram2_init_data(4096) = 0;
ram3_init_data(4096) = 0;

disp('Data padded to 4096 entries to match RAM depth.');

disp('Data prepared for Index-Based Simulink Loading.');
disp('Use variables: ram1_init_data, ram2_init_data, ram3_init_data');

%%
% Design the filter using normalized frequencies (0 to 1)
d_1 = designfilt('lowpassfir', ...
    'PassbandFrequency', 0.18, ...
    'StopbandFrequency', 0.24, ...
    'PassbandRipple', 0.1, ...
    'StopbandAttenuation', 80, ...
    'DesignMethod', 'equiripple');

% Extract the hardware coefficients
b_1 = d_1.Coefficients;


% Design the filter using normalized frequencies (0 to 1)
d_2 = designfilt('lowpassfir', ...
    'PassbandFrequency', 0.25, ...
    'StopbandFrequency', 0.35, ...
    'PassbandRipple', 0.1, ...
    'StopbandAttenuation', 80, ...
    'DesignMethod', 'equiripple');

% Extract the hardware coefficients
b_2 = d_2.Coefficients;
disp('Designing Universal FIR Filter for Hardware...');

% Design the filter using normalized frequencies (0 to 1)
d_3 = designfilt('lowpassfir', ...
    'PassbandFrequency', 0.3, ...
    'StopbandFrequency', 0.35, ...
    'PassbandRipple', 0.1, ...
    'StopbandAttenuation', 80, ...
    'DesignMethod', 'equiripple');

% Extract the hardware coefficients
b_3 = d_3.Coefficients;

%% -------------------------------
% 6. Simulink Setup Notes (Hardware Accurate Method)
%% -------------------------------
% Output bit requirement: 14-bit complex, 11 fractional bits
output_dt = fixdt(1, 14, 11);

% INSTRUCTIONS FOR SIMULINK:
% 1. Set 'Fixed-step size' to 1/60e6 and 'Stop time' to 999 * (1/60e6).
% 2. Use a 'Counter Limited' block set to 999 (Sample time: 1/60e6).
% 3. For each RAM branch, use a 'Direct Lookup Table (n-D)':
%    - Set Table data to: ram1_init_data (or 2 or 3).
%    - Feed the Counter into the Lookup Table.
% 4. Connect the Lookup Table output to your Single Port RAM 'Data In'.
% 5. Connect the Counter to the Single Port RAM 'Addr'.
% 6. Apply a Constant '1' to the 'WE' port to write the data.

%% ---------------------------------
out = sim('dsp_proj_v3_2024_n'); 

logged_signal = out.logsout.get(1); % Gets the first logged signal
final_data = logged_signal.Values.Data;
final_time = logged_signal.Values.Time;

complex_out_data = double(squeeze(final_data));

%% Plot the Final Result (Time Domain)

figure;
plot(final_time, real(complex_out_data), 'b', final_time, imag(complex_out_data), 'r--');
title('Final Processed Output from Simulink (Real & Imaginary)');
xlabel('Time (s)');
ylabel('Amplitude');
legend('Real Part', 'Imaginary Part');
grid on;

disp('Calculating Complex FFT...');


dt = mean(diff(final_time)); 
Fs_out = 1 / dt; 

start_idx = 200;
%Ignore transients
steady_data = complex_out_data(start_idx : length(complex_out_data));
L=length(steady_data);

Y = fftshift(fft(steady_data));
P_amp = abs(Y / L);


f = linspace(-Fs_out/2, Fs_out/2 - Fs_out/L, L);


figure;
plot(f, P_amp, 'LineWidth', 1.5);
title('Amplitude Spectrum of 60 MHz Output');
xlabel('Frequency (MHz)');
ylabel('Amplitude');
grid on;
xlim([0 5]);
disp('Designing Universal FIR Filter for Hardware...');

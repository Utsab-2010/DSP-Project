clc;
clear;
close all;

%% -------------------------------
% Number of samples / Time
%% -------------------------------
% FIX 1: Increased T to give the FFT enough data for high resolution
T = 1e-4; 

%% -------------------------------
% Sampling rates
%% -------------------------------
Fs1 = 10e6;   % RAM1
Fs2 = 15e6;   % RAM2
Fs3 = 20e6;   % RAM3

%% -------------------------------
% Time vectors
%% -------------------------------
% FIX 2: Added transpose (') to make these column vectors for the timetable
t1 = (0:1/Fs1:T)';
t2 = (0:1/Fs2:T)';
t3 = (0:1/Fs3:T)';

%% -------------------------------
% Generate complex signals
% Keep freq within bandwidth
%% -------------------------------
% RAM1: BW = 2 MHz → choose 1 MHz tone
f1 = 1e6;
x1 = exp(1j*2*pi*f1*t1);

% RAM2: BW = 4 MHz → choose 2 MHz tone
f2 = 2e6;
x2 = exp(1j*2*pi*f2*t2);

% RAM3: BW = 6 MHz → choose 3 MHz tone
f3 = 3e6;
x3 = exp(1j*2*pi*f3*t3);

%% -------------------------------
% Quantization (IMPORTANT)
%% -------------------------------
% RAM1: 8-bit complex
x1_real = fi(real(x1), 1, 8, 6);
x1_imag = fi(imag(x1), 1, 8, 6);
ram1_data_val = complex(x1_real, x1_imag);
ram1_data = ram1_data_val;

% RAM2: 10-bit complex
x2_real = fi(real(x2), 1, 10, 8);
x2_imag = fi(imag(x2), 1, 10, 8);
ram2_data_val = complex(x2_real, x2_imag);
ram2_data = ram2_data_val;

% RAM3: 12-bit complex
x3_real = fi(real(x3), 1, 12, 10);
x3_imag = fi(imag(x3), 1, 12, 10);
ram3_data_val = complex(x3_real, x3_imag);
ram3_data = ram3_data_val;

%% Display info

disp('RAM1 (8-bit) sample:');
disp(ram1_data_val(1:5));
disp('RAM2 (10-bit) sample:');
disp(ram2_data_val(1:5));
disp('RAM3 (12-bit) sample:');
disp(ram3_data_val(1:5));

%%  Optional: plot real parts of input

figure;
subplot(3,1,1); plot(t1, real(ram1_data_val)); title('RAM1 Signal (Real Part)');
subplot(3,1,2); plot(t2, real(ram2_data_val)); title('RAM2 Signal (Real Part)');
subplot(3,1,3); plot(t3, real(ram3_data_val)); title('RAM3 Signal (Real Part)');

%% -------------------------------
% Run Simulation and Extract Output
%% -------------------------------
% disp('Running Simulink model...');
% 
% % Run the simulation. 
% out = sim('dsp_proj_v2'); 
% 
% logged_signal = out.logsout.get(2); % Gets the first logged signal
% final_data = logged_signal.Values.Data;
% final_time = logged_signal.Values.Time;
% 
% % FIX 3: Keep the full complex signal! Do not use real() here.
% complex_out_data = double(squeeze(final_data));
% 
% %% -------------------------------
% % Plot the Final Result (Time Domain)
% %% -------------------------------
% figure;
% plot(final_time, real(complex_out_data), 'b', final_time, imag(complex_out_data), 'r--');
% title('Final Processed Output from Simulink (Real & Imaginary)');
% xlabel('Time (s)');
% ylabel('Amplitude');
% legend('Real Part', 'Imaginary Part');
% grid on;
% 
% %% -------------------------------
% % Complex Frequency Domain Analysis (FFT)
% %% -------------------------------
% disp('Calculating Complex FFT...');
% 
% % 1. Determine the actual sampling rate of the output data (Should be 60 MHz)
% dt = mean(diff(final_time)); 
% Fs_out = 1 / dt; 
% L = length(complex_out_data);
% 
% % 2. Compute the Shifted Complex Fast Fourier Transform
% Y = fftshift(fft(complex_out_data));
% 
% % 3. Calculate true amplitude
% P_amp = abs(Y / L);
% 
% % 4. Define the frequency domain vector (From -Fs/2 to +Fs/2)
% f = linspace(-Fs_out/2, Fs_out/2 - Fs_out/L, L);
% 
% % 5. Plot the Complex Spectrum
% figure;
% plot(f / 1e6, P_amp, 'LineWidth', 1.5);
% title('Complex Amplitude Spectrum of 60 MHz Output');
% xlabel('Frequency (MHz)');
% ylabel('Amplitude');
% grid on;
% 
% % FIX 4: Zoom the X-axis to focus on the -5 to +5 MHz range
% xlim([0 5]);

disp('Running Simulink model...');

% Run the simulation. 
out = sim('dsp_proj_v2_2024'); 

logged_signal = out.logsout.get(2); % Gets the first logged signal
final_data = logged_signal.Values.Data;
final_time = logged_signal.Values.Time;

% FIX 3: Keep the full complex signal! Do not use real() here.
complex_out_data = double(squeeze(final_data));

%% Plot the Final Result (Time Domain)

figure;
plot(final_time, real(complex_out_data), 'b', final_time, imag(complex_out_data), 'r--');
title('Final Processed Output from Simulink (Real & Imaginary)');
xlabel('Time (s)');
ylabel('Amplitude');
legend('Real Part', 'Imaginary Part');
grid on;

%% Complex Frequency Domain Analysis (FFT)

disp('Calculating Complex FFT...');

% 1. Determine the actual sampling rate of the output data (Should be 60 MHz)
dt = mean(diff(final_time)); 
Fs_out = 1 / dt; 
L = length(complex_out_data);

% 2. Compute the Shifted Complex Fast Fourier Transform
Y = fftshift(fft(complex_out_data));

% 3. Calculate true amplitude
P_amp = abs(Y / L);

% 4. Define the frequency domain vector (From -Fs/2 to +Fs/2)
f = linspace(-Fs_out/2, Fs_out/2 - Fs_out/L, L);

% 5. Plot the Complex Spectrum
figure;
plot(f / 1e6, P_amp, 'LineWidth', 1.5);
title('Complex Amplitude Spectrum of 60 MHz Output');
xlabel('Frequency (MHz)');
ylabel('Amplitude');
grid on;

xlim([0 5]);


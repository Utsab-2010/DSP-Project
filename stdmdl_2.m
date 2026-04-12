clc;
clear;
close all;

%% -------------------------------
% 1. Simulation Parameters
%% -------------------------------
N = 3000;           % Exact number of data points to load into RAM
Fsf = 60e6;   % Master Simulation Rate (LCM of 10, 15, 20)

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

x1_up = upsample(x1,6);
x2_up = upsample(x2,4);
x3_up = upsample(x3,3);

%%
% Design the filter using normalized frequencies (0 to 1)
d_3 = designfilt('lowpassfir', ...
    'PassbandFrequency', 0.18, ...
    'StopbandFrequency', 0.24, ...
    'PassbandRipple', 0.1, ...
    'StopbandAttenuation', 80, ...
    'DesignMethod', 'equiripple');

% Extract the hardware coefficients
b_3 = d_3.Coefficients;


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
d_1 = designfilt('lowpassfir', ...
    'PassbandFrequency', 0.3, ...
    'StopbandFrequency', 0.35, ...
    'PassbandRipple', 0.1, ...
    'StopbandAttenuation', 80, ...
    'DesignMethod', 'equiripple');

% Extract the hardware coefficients
b_1 = d_1.Coefficients;

y1 = 6*downsample(filter(b_3,1,x1_up),5);
y2 = 4*downsample(filter(b_2,1,x2_up),5);
y3 = 3*downsample(filter(b_1,1,x3_up),5);
olen = min([length(y1) length(y2) length(y3)]); 
y1 = y1(1:olen); % To leave out extra samples due to edge effects of filters and up/downsampling
y2 = y2(1:olen);
y3 = y3(1:olen);

y = y1 + y2 + y3; % end of processing

% plotting stage
start_idx = 300;    % to remove transience          
y = y(start_idx:length(y));           % ensure column vector
L = length(y);      % number of samples

% FFT
Y = fftshift(fft(y));

% Amplitude normalization
P = abs(Y) / L;

% Frequency axis (two-sided)
f = linspace(-Fsf/10, Fsf/10, L);

% Plot
figure;
plot(f, P, 'LineWidth', 1.5);
xlabel('Frequency (MHz)');
ylabel('Magnitude');
title('Output Spectrum');
grid on;

% Optional zoom (since your tones are within ~±5 MHz)
xlim([-Fsf/10 +Fsf/10]);


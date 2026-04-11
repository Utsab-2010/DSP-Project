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

fp1 = 0.3;
fp2 = 0.25;
fp3 = 0.18;

fs1 = 0.35;
fs2 = 0.35;
fs3 = 0.24;

rp = 0.1; % max passband ripple
rs = 80; % stopband attenuation

delta_p = (10^(rp/20)-1)/(10^(rp/20)+1);
delta_s = 10^(-rs/20);

[n1, fo1, ao1, w1] = firpmord([fp1 fs1], [1 0], [delta_p delta_s]);
[n2, fo2, ao2, w2] = firpmord([fp2 fs2], [1 0], [delta_p delta_s]);
[n3, fo3, ao3, w3] = firpmord([fp3 fs3], [1 0], [delta_p delta_s]);

h1 = firpm(n1, fo1, ao1, w1);
h2 = firpm(n2, fo2, ao2, w2);
h3 = firpm(n3, fo3, ao3, w3);

y1 = downsample(filter(h1,1,x1_up),5);
y2 = downsample(filter(h2,1,x2_up),5);
y3 = downsample(filter(h3,1,x3_up),5);
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
f = linspace(-Fsf/2, Fsf/2 - Fsf/L, L);

% Plot
figure;
plot(f, P, 'LineWidth', 1.5);
xlabel('Frequency (MHz)');
ylabel('Magnitude');
title('Output Spectrum');
grid on;

% Optional zoom (since your tones are within ~±5 MHz)
xlim([-Fsf/2 +Fsf/2]);


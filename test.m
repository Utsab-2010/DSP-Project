%% Simulink Emulation Script (Hardware-Specific Types)
clear; clc;

% 1. Initialization - Matching the 'sfix' types from your image
% h0, h1, h2: sfix6_En4 (c) -> Signed, 6-bit total, 4-bit fraction, Complex
h_type = numerictype(1, 6, 4);
h = fi([5, 6, 7] + 0i, h_type);

% Data_in: sfix8_En6 (c) -> Signed, 8-bit total, 6-bit fraction, Complex
data_type = numerictype(1, 8, 6);
data_size = 100;
Data_in = fi(randn(1, data_size) + 0i, data_type)';

% 2. Control Signals (Booleans & uint8)
EN = true;          % Boolean
WE = true;          % Boolean
Add_Ext = uint8(0); % uint8 (c) for the RAM address

% 3. Memory Allocation
% Pre-allocating as Fixed-Point Complex to avoid type mismatch
Input_RAM = fi(complex(zeros(1, data_size)), data_type);
Memory_data = fi(complex(zeros(1, data_size)), data_type); 

% 4. Processing Loop
for count = 1:data_size
    % Emulating the Hardware Counter (starts at 0, ends at 99)
    current_addr = uint8(count - 1); 
    
    if EN
        % Write to Input RAM if WE is active
        if WE
            Input_RAM(count) = Data_in(count);
        end
        
        % Processing Subsystem (MAC Logic)
        if count == 1
            Y_n = h(1) * Input_RAM(count);
        elseif count == 2
            Y_n = h(1) * Input_RAM(count) + h(2) * Input_RAM(count-1);
        else
            Y_n = h(1) * Input_RAM(count) + ...
                  h(2) * Input_RAM(count-1) + ...
                  h(3) * Input_RAM(count-2);
        end
        
        % Store result in Output RAM
        Memory_data(count) = Y_n;
    end
    
    % Termination Check
    if current_addr == 99
        fprintf('Processing finished at address 99.\n');
    end
end

% 5. Quick Plot
plot(real(Memory_data));
title('Real Part of Fixed-Point Processed Data');
grid on;
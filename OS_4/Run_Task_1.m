%% -- EM.411 OS 4 Task 1 -- %%

% Surface transportation system performance for three architecture cases
Passenger_Volume = [1000, 2000, 750];
Peak_Passenger_Throughput = [75, 100, 75];
Average_wait_time = [8, 12, 6];
Availability = [0.7, 0.6, 0.8];

% Define Stakeholder utilities (Appendix A)
Passenger_Trips_per_day = [0 500 1000 1500 2000];
Passenger_Trips_per_day_utility = [0 0.2 0.4 0.8 1.0]; %0 = unacceptable performance, 1 = ideal performance 

Minutes_average_wait_time = [0 5 10 15 20 30];
Minutes_average_wait_time_utility = [1.0 0.95 0.75 0.4 0.2 0];

Peak_passenger_throughput_per_hour = [0 50 100 150 200];
Peak_passenger_throughput_per_hour_utility = [0 0.2 0.5 0.9 1.0];

availability = [0 0.2 0.4 0.6 0.8 1.0];
availability_utility = [0 0.2 0.4 0.6 0.8 1.0];

% Define Stakeholder priorities (weights)
stakeholder_priorities.passenger_volume = 0.15;
stakeholder_priorities.peak_passenger_throughput = 0.25;
stakeholder_priorities.average_wait_time = 0.35;
stakeholder_priorities.avalibility = 0.25;

% Preallocate arrays for speed
U_passenger_volume = zeros(1,3);
U_peak_throughput = zeros(1,3);
U_wait_time = zeros(1,3);
U_availability = zeros(1,3);
MAU = zeros(1,3);

% Compute utilities and total MAU for each case
for i = 1:3
    % Interpolate utilities for each performance measure
    U_passenger_volume(i) = interp1(Passenger_Trips_per_day, Passenger_Trips_per_day_utility, Passenger_Volume(i), 'linear', 'extrap');
    U_peak_throughput(i) = interp1(Peak_passenger_throughput_per_hour, Peak_passenger_throughput_per_hour_utility, Peak_Passenger_Throughput(i), 'linear', 'extrap');
    U_wait_time(i) = interp1(Minutes_average_wait_time, Minutes_average_wait_time_utility, Average_wait_time(i), 'linear', 'extrap');
    U_availability(i) = interp1(availability, availability_utility, Availability(i), 'linear', 'extrap');

    % Compute Multi-Attribute Utility (weighted sum)
    MAU(i) = (stakeholder_priorities.passenger_volume * U_passenger_volume(i)) + ...
              (stakeholder_priorities.peak_passenger_throughput * U_peak_throughput(i)) + ...
              (stakeholder_priorities.average_wait_time * U_wait_time(i)) + ...
              (stakeholder_priorities.avalibility * U_availability(i));
end

% Store results
T = table((1:3)', Passenger_Volume', Peak_Passenger_Throughput', Average_wait_time', Availability', ...
          U_passenger_volume', U_peak_throughput', U_wait_time', U_availability', MAU', ...
          'VariableNames', {'Case','PassengerVol','PeakThroughput','WaitTime','Availability','U_PV','U_Peak','U_Wait','U_Avail','MAU'});

% Export results to Excel
filename = 'Transportation_System_Performance.xlsx';
writetable(T, filename);

%Plot MAU
figure;
bar(MAU);
title('Multi-Attribute Utility Comparison');
xlabel('Architecture Case');
ylabel('Overall Utility');
grid on;
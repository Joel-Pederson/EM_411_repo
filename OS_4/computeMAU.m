function [MAU] = computeMAU(design)
%Compute Multi-Attribute Utility (MAU) function
%Using Weighted sum aggrigation per reccomendation of professor during MIT SDM SE Lecture 5
%Inputs: System designs
%Outputs: MAU - a utility score ranging from 0 to 1

%% -- Define Weights (from Appendix A) -- %%
weight.passenger_volume = 0.15;
weight.peak_passenger_throughput = 0.25;
weight.average_wait_time = 0.35;
weight.availability = 0.25;

%% -- Define Utility (from Appendix A) -- %%
Passenger_Trips_per_day = [0 500 1000 1500 2000];
Passenger_Trips_per_day_utility = [0 0.2 0.4 0.8 1.0]; %0 = unacceptable performance, 1 = ideal performance

Minutes_average_wait_time = [0 5 10 15 20 30];
Minutes_average_wait_time_utility = [1.0 0.95 0.75 0.4 0.2 0];

Peak_passenger_throughput_per_hour = [0 50 100 150 200];
Peak_passenger_throughput_per_hour_utility = [0 0.2 0.5 0.9 1.0];

availability = [0 0.2 0.4 0.6 0.8 1.0];
availability_utility = [0 0.2 0.4 0.6 0.8 1.0];

%% -- Define Attributes -- %%
% Extract from design struct
attribute.peak_passenger_throughput = design.FleetThroughput_pass_hr; %Passenger Volume
attribute.average_wait_time = design.AvgWaitTime_min; %Average Wait Time
% Compute Effective Avalibility
road_avail = design.Road_Availability;
bike_avail = design.Bike_Availability;
num_road = design.Fleet_Composition_Road_Vehicles;
num_bike = design.Fleet_Composition_Bike_Vehicles;

% Handle cases where values might be 0 instead of NaN from Task 2 script
is_mixed = (num_road > 0 && road_avail > 0) && (num_bike > 0 && bike_avail > 0);
is_road_only = (num_road > 0 && road_avail > 0) && (num_bike == 0);
is_bike_only = (num_road == 0) && (num_bike > 0 && bike_avail > 0);

if is_mixed
    total_vehicles = num_road + num_bike;
    weight_road = num_road / total_vehicles;
    weight_bike = num_bike / total_vehicles;
    attribute.availability = (weight_road * road_avail) + (weight_bike * bike_avail);
elseif is_road_only
    attribute.availability = road_avail;
elseif is_bike_only
    attribute.availability = bike_avail;
else
    attribute.availability = 0; % Default if no vehicles or availability is zero
    warning('No Vehicles defined, check inputs');
end

% Compute Daily Passenger Volume
demand_profile_per_hr = [15, 5, 15, 50, 150, 150, 150, 100, 75, 100, 50, 35]; % from Appendix B
total_daily_volume = 0;
for hour_demand = demand_profile_per_hr
    % Passengers served = min(hourly demand, hourly capacity) * 2 hours per block
    passengers_served_in_block = min(hour_demand, attribute.peak_passenger_throughput) * 2; % One Block = 2 hr
    total_daily_volume = total_daily_volume + passengers_served_in_block;
end
attribute.passenger_volume = total_daily_volume; % Max possible value is 1140 (demand-limited modeling assumption)

%% -- Calculate Single-Attribute Utilities (SAUs) -- %%
% Approach: Use linear interpolation (interp1) to find the utility score 
% for each performance metric based on the Appendix A utility curves.
U_vol   = interp1(Passenger_Trips_per_day,   Passenger_Trips_per_day_utility,   attribute.passenger_volume, 'linear', 'extrap'); %linear interpolation
U_peak  = interp1(Peak_passenger_throughput_per_hour,  Peak_passenger_throughput_per_hour_utility,  attribute.peak_passenger_throughput,'linear', 'extrap');
U_wait  = interp1(Minutes_average_wait_time,  Minutes_average_wait_time_utility,  attribute.average_wait_time, 'linear', 'extrap');
U_avail = interp1(availability, availability_utility, attribute.availability, 'linear', 'extrap');

% Clamp SAU values
U_vol   = max(0, min(U_vol, 1)); %bound utility value between 0 and 1
U_peak  = max(0, min(U_peak, 1));
U_wait  = max(0, min(U_wait, 1));
U_avail = max(0, min(U_avail, 1));

%% -- Calculate Final MAU (Weighted Sum) -- %%
MAU = (weight.passenger_volume * U_vol) + (weight.peak_passenger_throughput * U_peak) + ...
      (weight.average_wait_time * U_wait) + (weight.availability * U_avail);

% Clamp final MAU
MAU = max(0, min(MAU, 1));

end %end function
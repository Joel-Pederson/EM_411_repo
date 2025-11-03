%% -- EM.411 OS 4 Task 4 - Full Tradespace Exploration -- %%
% Explores pure road, pure bike, and strategic mixed fleets using parfor.
% Calculates fleet size, cost, and utility for each valid design.
% Dependencies: MATLAB Parallel Computing Toolbox
% https://github.com/Joel-Pederson/EM_411_repo
%% Scenario:
% Off-peak traffic scenario (50 pass/hr at 2000 hrs)
% Model Note: This uses a demand-limited modeling approach. So the
% performance of the system cannot exceed mean demand as defined in appendix B
clear all; close all;

%% -- Load Database -- %%
[roadDB, bikeDB] = load_DB();

% -- Define Reference Architectures (from Task 3) -- %%
% 8 total architectures (5 baseline + 3 Pareto)
ref_designs = {};     % Stores the component indices for each architecture
ref_archTypes = {};   % Stores the type: 'road' or 'bike'
ref_fleetSizes = struct();  % Stores the fleet size assumption for each architecture

%Arch 2: Autonomous Shuttle Fleet
ref_designs{1}.chassis = 4;         %C4 (8 pax shuttle)
ref_designs{1}.battery_pack = 3;    %P3 (150kWh)
ref_designs{1}.battery_charger = 3; %G3 (60 kW)
ref_designs{1}.motor = 3;           %M3 (210 kW)
ref_designs{1}.autonomy = 2;        %A4 (Level 4)
ref_archTypes{1} = 'road';
ref_fleetSizes.road{1} = 4;         %count of vehicles
ref_fleetSizes.bike{1} = 0;         %count of bikes

%Arch 6: Task 3 Pareto Point 1
ref_designs{2}.chassis = 8;         %C8 (30 pax shuttle)
ref_designs{2}.battery_pack = 1;    %P1 (50 kWh)
ref_designs{2}.battery_charger = 3; %G3 (60 kW)
ref_designs{2}.motor = 1;           %M1 (50 kW)
ref_designs{2}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{2} = 'road';
ref_fleetSizes.road{2} = 1;         %count of vehicles (1 shuttle)
ref_fleetSizes.bike{2} = 0;         %count of bikes

%Arch 7: Task 3 Pareto Point 2
ref_designs{3}.chassis = 6;         %C6 (16 pax shuttle)
ref_designs{3}.battery_pack = 1;    %P1 (50 kWh)
ref_designs{3}.battery_charger = 3; %G3 (60 kW)
ref_designs{3}.motor = 1;           %M1 (50 kW)
ref_designs{3}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{3} = 'road';
ref_fleetSizes.road{3} = 2;         %count of vehicles (2 shuttles)
ref_fleetSizes.bike{3} = 0;         %count of bikes

%Arch 8: Task 3 Pareto Point 3
ref_designs{4}.chassis = 7;         %C7 (20 pax shuttle)
ref_designs{4}.battery_pack = 6;    %P6 (310 kWh)
ref_designs{4}.battery_charger = 3; %G3 (60 kW)
ref_designs{4}.motor = 1;           %M1 (50 kW)
ref_designs{4}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{4} = 'road';
ref_fleetSizes.road{4} = 2;         %count of vehicles (2 shuttles)
ref_fleetSizes.bike{4} = 0;         %count of bikes

%% -- Define Fleet-Level Model Assumptions -- %%
%Values from Table 1 unless otherwise noted
max_travel_time_min = 7; %max transportation time
dwell_time_s = 60; %time for passengers get in and out
average_trip_time_min = (max_travel_time_min + (dwell_time_s / 60));
avgTripTime_h = average_trip_time_min / 60;
peak_demand_pass_hr = 50; % Target throughput
load_factor_per_trip = 0.75; %from appendix B

mix_ratios_road = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]; % Road contribution target
num_ratios = length(mix_ratios_road);

%% -- Initialize Results Storage -- %%
% Calculate total number of designs for pre-allocation
num_c = length(roadDB.chassis); num_b_r = length(roadDB.battery_pack); num_g_r = length(roadDB.battery_charger); num_m_r = length(roadDB.motor); num_a = length(roadDB.autonomy);
num_f = length(bikeDB.frame); num_b_b = length(bikeDB.battery_pack); num_g_b = length(bikeDB.battery_charger); num_m_b = length(bikeDB.motor);

num_road_designs = num_c * num_b_r * num_g_r * num_m_r * num_a;
num_bike_designs = num_f * num_b_b * num_g_b * num_m_b;
num_mixed_designs = num_road_designs * num_bike_designs * num_ratios;
total_designs_estimate = num_road_designs + num_bike_designs + num_mixed_designs;

% Pre-allocate result cell arrays for speed
results_cost = NaN(total_designs_estimate, 1);
results_mau = NaN(total_designs_estimate, 1);
results_throughput = NaN(total_designs_estimate, 1);
results_waittime = NaN(total_designs_estimate, 1);
results_road_avail = NaN(total_designs_estimate, 1);
results_bike_avail = NaN(total_designs_estimate, 1);
results_road_speed = NaN(total_designs_estimate, 1);
results_bike_speed = NaN(total_designs_estimate, 1);
results_road_range = NaN(total_designs_estimate, 1);
results_bike_range = NaN(total_designs_estimate, 1);
results_road_cost = NaN(total_designs_estimate, 1);
results_bike_cost = NaN(total_designs_estimate, 1);
results_arch_type = cell(total_designs_estimate, 1);
results_specs = cell(total_designs_estimate, 1);
results_fleet_road = NaN(total_designs_estimate, 1);
results_fleet_bike = NaN(total_designs_estimate, 1);

%% -- Initialize Progress Dialog and DataQueue -- %%
processed_count = 0; % Use regular variable for tracking total progress
update_frequency = 500; % Update UI less often with DataQueue
%Note: This progress dialog and dataqueue section was made with the
%significant help of MATLAB Copilot and Google Gemini because I always mess
%this up in MATLAB. It's very convoluted to do right in a prallel
%configuration. It took both tools to get right because Gemini was
%confidently lying about figure windows and MATLAB co-pilot knew the syntax
%but didn't know how to configure correctly in the context of my nested
%loops.

% Create the UI components
% Create a VISIBLE figure to host the dialog.
%    This is the most reliable way to ensure the handle is valid.
fig = uifigure('Name', 'Tradespace Progress');
drawnow; % Force MATLAB to draw it

% Create the dialog *inside* the visible figure
d = uiprogressdlg(fig, 'Title','Running Tradespace Exploration','Message','Starting exploration...',...
    'Value',0, 'Cancelable','off');

% Create DataQueue and specify the callback
queue = parallel.pool.DataQueue;
% Create an anonymous function to pass the dialog handle (d),
% total designs, and update frequency to the callback.
afterEach(queue, @(~) updateProgress(d, total_designs_estimate, update_frequency));

% Function to update progress dialog (nested function)
function updateProgress(d, total_designs, freq) % Accept arguments
% Use a persistent counter inside the function
persistent persistent_processed_count;
if isempty(persistent_processed_count)
    persistent_processed_count = 0;
end

persistent_processed_count = persistent_processed_count + 1; % Increment based on message received

% Use the passed-in arguments 'freq' and 'total_designs'
if mod(persistent_processed_count, freq) == 0 || persistent_processed_count == total_designs
    progress_value = min(1.0, persistent_processed_count / total_designs); % Clamp value
    if isvalid(d) % Check if dialog handle is still valid
        d.Value = progress_value;
        d.Message = sprintf('Processing design %d of ~%d (%.0f%%)...', ...
            persistent_processed_count, total_designs, progress_value*100);
        drawnow limitrate; % Update UI, limit rate
    end
end
end

%% -- Explore all Pure Road Vehicle Architectures -- %%
road_offset = 0; % Starting index for road results

parfor c_idx = 1:num_c % PARFOR loop
    % Need temporary storage inside parfor loop as jobs are handed out
    temp_cost = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_mau = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_throughput = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_waittime = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_road_avail = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_bike_avail = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_road_speed = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_bike_speed = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_road_range = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_bike_range = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_road_cost = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_bike_cost = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_type = cell(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_specs = cell(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_fleet_r = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_fleet_b = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    valid_count_slice = 0; % Count valid designs in this "slice"

    for bb = 1:num_b_r %symetric iteration through all combos
        for gg = 1:num_g_r
            for mm = 1:num_m_r
                for aa = 1:num_a
                    % Build Road Vehicle
                    design = struct('chassis', c_idx, 'battery_pack', bb, 'battery_charger', gg, 'motor', mm, 'autonomy', aa);
                    [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);

                    if ~isValid
                        send(queue, 1); % Send update even for invalid
                        continue;
                    end

                    passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;
                    singleVehicleThroughput_up = passengersPerTrip / avgTripTime_h;
                    effectiveVehicleThroughput = singleVehicleThroughput_up * Road_EV_Design.availability;

                    if effectiveVehicleThroughput <= 0 % Not a valid solution
                        send(queue, 1);
                        continue;
                    end
                    requiredFleetSize = ceil(peak_demand_pass_hr / effectiveVehicleThroughput);
                    totalFleetCost = cost.total_vehicle_cost * requiredFleetSize;

                    actualFleetThroughput = requiredFleetSize * effectiveVehicleThroughput;
                    fleetTripsPerHr = actualFleetThroughput / passengersPerTrip;
                    headway_min = 60 / fleetTripsPerHr;
                    avgWaitTime_min = 0.5 * headway_min;

                    design_metrics = struct('FleetThroughput_pass_hr', actualFleetThroughput, 'AvgWaitTime_min', avgWaitTime_min, ...
                        'Road_Availability', Road_EV_Design.availability, 'Bike_Availability', 0, ...
                        'Fleet_Composition_Road_Vehicles', requiredFleetSize, 'Fleet_Composition_Bike_Vehicles', 0);

                    valid_count_slice = valid_count_slice + 1;
                    temp_cost(valid_count_slice) = totalFleetCost;
                    temp_mau(valid_count_slice) = computeMAU(design_metrics);
                    temp_throughput(valid_count_slice) = actualFleetThroughput;
                    temp_waittime(valid_count_slice) = avgWaitTime_min;
                    temp_road_avail(valid_count_slice) = Road_EV_Design.availability;
                    temp_bike_avail(valid_count_slice) = 0;
                    temp_road_speed(valid_count_slice) = Road_EV_Design.mean_speed_km_h;
                    temp_bike_speed(valid_count_slice) = 0;
                    temp_road_range(valid_count_slice) = Road_EV_Design.range_km;
                    temp_bike_range(valid_count_slice) = 0;
                    temp_road_cost(valid_count_slice) = cost.total_vehicle_cost;
                    temp_bike_cost(valid_count_slice) = 0;
                    temp_type{valid_count_slice} = 'Road';
                    temp_specs{valid_count_slice} = sprintf("C%d, P%d, G%d, M%d, A%d", c_idx, bb, gg, mm, aa);
                    temp_fleet_r(valid_count_slice) = requiredFleetSize;
                    temp_fleet_b(valid_count_slice) = 0;

                    send(queue, 1); % Send message to DataQueue to update counter
                end
            end
        end
    end
    % Store results from this slice
    %Calculate start/end indices based on valid counts (needs careful handling)
    %Using a simpler approach: accumulate results in cell arrays and concatenate later
    slice_results{c_idx} = {temp_cost(1:valid_count_slice), temp_mau(1:valid_count_slice), ...
        temp_type(1:valid_count_slice), temp_specs(1:valid_count_slice), ...
        temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice), ...
        temp_throughput(1:valid_count_slice), temp_waittime(1:valid_count_slice), ...
        temp_road_avail(1:valid_count_slice), temp_bike_avail(1:valid_count_slice), ...
        temp_road_speed(1:valid_count_slice), temp_bike_speed(1:valid_count_slice), ...
        temp_road_range(1:valid_count_slice), temp_bike_range(1:valid_count_slice), ...
        temp_road_cost(1:valid_count_slice), temp_bike_cost(1:valid_count_slice)};
end % End parfor c_idx

% Consolidate Road Results
idx = 1;
for i = 1:num_c
    if ~isempty(slice_results{i}) %likely redundant but added for robustness
        num_valid_in_slice = length(slice_results{i}{1});
        if num_valid_in_slice > 0
            end_idx = idx + num_valid_in_slice - 1;
            results_cost(idx:end_idx) = slice_results{i}{1};
            results_mau(idx:end_idx) = slice_results{i}{2};
            results_arch_type(idx:end_idx) = slice_results{i}{3};
            results_specs(idx:end_idx) = slice_results{i}{4};
            results_fleet_road(idx:end_idx) = slice_results{i}{5};
            results_fleet_bike(idx:end_idx) = slice_results{i}{6};
            results_throughput(idx:end_idx) = slice_results{i}{7};
            results_waittime(idx:end_idx) = slice_results{i}{8};
            results_road_avail(idx:end_idx) = slice_results{i}{9};
            results_bike_avail(idx:end_idx) = slice_results{i}{10};
            results_road_speed(idx:end_idx) = slice_results{i}{11};
            results_bike_speed(idx:end_idx) = slice_results{i}{12};
            results_road_range(idx:end_idx) = slice_results{i}{13};
            results_bike_range(idx:end_idx) = slice_results{i}{14};
            results_road_cost(idx:end_idx) = slice_results{i}{15};
            results_bike_cost(idx:end_idx) = slice_results{i}{16};
            idx = end_idx + 1;
        end
    end
end
final_road_idx = idx - 1;
clear slice_results; % Clear temporary storage


%% -- Explore all Pure Bike Vehicle Architectures -- %%
bike_offset = final_road_idx; % Start index for bike results
slice_results = cell(num_f, 1); % Reinitialize for bikes

parfor f_idx = 1:num_f
    temp_cost = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_mau = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_throughput = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_waittime = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_road_avail = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_bike_avail = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_road_speed = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_bike_speed = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_road_range = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_bike_range = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_road_cost = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_bike_cost = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_type = cell(num_b_b * num_g_b * num_m_b, 1);
    temp_specs = cell(num_b_b * num_g_b * num_m_b, 1);
    temp_fleet_r = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_fleet_b = NaN(num_b_b * num_g_b * num_m_b, 1);
    valid_count_slice = 0;

    for bb = 1:num_b_b
        for gg = 1:num_g_b
            for mm = 1:num_m_b

                design = struct('frame', f_idx, 'battery_pack', bb, 'battery_charger', gg, 'motor', mm);
                [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);

                if ~isValid
                    send(queue, 1);
                    continue;
                end
                %Compute metrics
                passengersPerTrip = Bike_EV_Design.Pax * load_factor_per_trip;
                singleVehicleThroughput_up = passengersPerTrip / avgTripTime_h;
                effectiveVehicleThroughput = singleVehicleThroughput_up * Bike_EV_Design.availability;

                if effectiveVehicleThroughput <= 0
                    send(queue, 1);
                    continue;
                end
                requiredFleetSize = ceil(peak_demand_pass_hr / effectiveVehicleThroughput);
                totalFleetCost = cost.total_vehicle_cost * requiredFleetSize;

                actualFleetThroughput = requiredFleetSize * effectiveVehicleThroughput;
                fleetTripsPerHr = actualFleetThroughput / passengersPerTrip;
                headway_min = 60 / fleetTripsPerHr;
                avgWaitTime_min = 0.5 * headway_min;

                design_metrics = struct('FleetThroughput_pass_hr', actualFleetThroughput, 'AvgWaitTime_min', avgWaitTime_min, ...
                    'Road_Availability', 0, 'Bike_Availability', Bike_EV_Design.availability, ...
                    'Fleet_Composition_Road_Vehicles', 0, 'Fleet_Composition_Bike_Vehicles', requiredFleetSize);

                valid_count_slice = valid_count_slice + 1;
                temp_cost(valid_count_slice) = totalFleetCost;
                temp_mau(valid_count_slice) = computeMAU(design_metrics);
                temp_throughput(valid_count_slice) = actualFleetThroughput;
                temp_waittime(valid_count_slice) = avgWaitTime_min;
                temp_road_avail(valid_count_slice) = 0;
                temp_bike_avail(valid_count_slice) = Bike_EV_Design.availability;
                temp_road_speed(valid_count_slice) = 0;
                temp_bike_speed(valid_count_slice) = Bike_EV_Design.mean_speed_km_h;
                temp_road_range(valid_count_slice) = 0;
                temp_bike_range(valid_count_slice) = Bike_EV_Design.range_km;
                temp_road_cost(valid_count_slice) = 0;
                temp_bike_cost(valid_count_slice) = cost.total_vehicle_cost;
                temp_type{valid_count_slice} = 'Bike';
                temp_specs{valid_count_slice} = sprintf("B%d, E%d, G%d, K%d", f_idx, bb, gg, mm);
                temp_fleet_r(valid_count_slice) = 0;
                temp_fleet_b(valid_count_slice) = requiredFleetSize;

                send(queue, 1); % Send message to DataQueue
            end
        end
    end
    slice_results{f_idx} = {temp_cost(1:valid_count_slice), temp_mau(1:valid_count_slice), ...
        temp_type(1:valid_count_slice), temp_specs(1:valid_count_slice), ...
        temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice), ...
        temp_throughput(1:valid_count_slice), temp_waittime(1:valid_count_slice), ...
        temp_road_avail(1:valid_count_slice), temp_bike_avail(1:valid_count_slice), ...
        temp_road_speed(1:valid_count_slice), temp_bike_speed(1:valid_count_slice), ...
        temp_road_range(1:valid_count_slice), temp_bike_range(1:valid_count_slice), ...
        temp_road_cost(1:valid_count_slice), temp_bike_cost(1:valid_count_slice)};
end % End parfor f_idx

% Consolidate Bike Results
idx = final_road_idx + 1; % Start after last road result
for i = 1:num_f
    if ~isempty(slice_results{i})
        num_valid_in_slice = length(slice_results{i}{1});
        if num_valid_in_slice > 0
            end_idx = idx + num_valid_in_slice - 1;
            results_cost(idx:end_idx) = slice_results{i}{1};
            results_mau(idx:end_idx) = slice_results{i}{2};
            results_arch_type(idx:end_idx) = slice_results{i}{3};
            results_specs(idx:end_idx) = slice_results{i}{4};
            results_fleet_road(idx:end_idx) = slice_results{i}{5};
            results_fleet_bike(idx:end_idx) = slice_results{i}{6};
            results_throughput(idx:end_idx) = slice_results{i}{7};
            results_waittime(idx:end_idx) = slice_results{i}{8};
            results_road_avail(idx:end_idx) = slice_results{i}{9};
            results_bike_avail(idx:end_idx) = slice_results{i}{10};
            results_road_speed(idx:end_idx) = slice_results{i}{11};
            results_bike_speed(idx:end_idx) = slice_results{i}{12};
            results_road_range(idx:end_idx) = slice_results{i}{13};
            results_bike_range(idx:end_idx) = slice_results{i}{14};
            results_road_cost(idx:end_idx) = slice_results{i}{15};
            results_bike_cost(idx:end_idx) = slice_results{i}{16};
            idx = end_idx + 1;
        end
    end
end
final_bike_idx = idx - 1;
clear slice_results;

%% -- Explore Mixed Fleet Architectures -- %%
mix_offset = final_bike_idx;
mix_ratios_road = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]; % Road contribution target
num_ratios = length(mix_ratios_road);
slice_results = cell(num_c, 1); % Reinitialize for mixed
parfor c_idx = 1:num_c % PARFOR loop for road chassis
    % Preallocate temp storage for ONE slice of the outer loop
    max_inner_iterations = num_b_r*num_g_r*num_m_r*num_a * num_bike_designs * num_ratios;
    temp_cost = NaN(max_inner_iterations, 1);
    temp_mau = NaN(max_inner_iterations, 1);
    temp_throughput = NaN(max_inner_iterations, 1);
    temp_waittime = NaN(max_inner_iterations, 1);
    temp_road_avail = NaN(max_inner_iterations, 1);
    temp_bike_avail = NaN(max_inner_iterations, 1);
    temp_road_speed = NaN(max_inner_iterations, 1);
    temp_bike_speed = NaN(max_inner_iterations, 1);
    temp_road_range = NaN(max_inner_iterations, 1);
    temp_bike_range = NaN(max_inner_iterations, 1);
    temp_road_cost = NaN(max_inner_iterations, 1);
    temp_bike_cost = NaN(max_inner_iterations, 1);
    temp_type = cell(max_inner_iterations, 1);
    temp_specs = cell(max_inner_iterations, 1);
    temp_fleet_r = NaN(max_inner_iterations, 1);
    temp_fleet_b = NaN(max_inner_iterations, 1);
    valid_count_slice = 0; % Index within this slice
    for b_r = 1:num_b_r
        for g_r = 1:num_g_r
            for m_r = 1:num_m_r
                for a = 1:num_a

                    design_road = struct('chassis', c_idx, 'battery_pack', b_r, 'battery_charger', g_r, 'motor', m_r, 'autonomy', a);
                    [Road_EV_Design, cost_road, isValid_road] = calculateRoadVehicle(design_road, roadDB);

                    if ~isValid_road
                        % Need to account for skipped iterations in progress counter
                        num_skipped = num_bike_designs * num_ratios;
                        send(queue, ones(num_skipped,1)); % Send multiple updates
                        continue;
                    end
                    pass_r = Road_EV_Design.Pax * load_factor_per_trip;
                    thrpt_up_r = pass_r / avgTripTime_h;
                    eff_thrpt_r = thrpt_up_r * Road_EV_Design.availability;
                    if eff_thrpt_r <= 0
                        num_skipped = num_bike_designs * num_ratios;
                        send(queue, ones(num_skipped,1));
                        continue;
                    end
                    % Run Road EV Design against all bike combos
                    for f = 1:num_f
                        for b_b = 1:num_b_b
                            for g_b = 1:num_g_b
                                for m_b = 1:num_m_b
                                    design_bike = struct('frame', f, 'battery_pack', b_b, 'battery_charger', g_b, 'motor', m_b);
                                    [Bike_EV_Design, cost_bike, isValid_bike] = calculateBikeVehicle(design_bike, bikeDB);
                                    if ~isValid_bike
                                        num_skipped = num_ratios;
                                        send(queue, ones(num_skipped,1));
                                        continue;
                                    end
                                    pass_b = Bike_EV_Design.Pax * load_factor_per_trip;
                                    thrpt_up_b = pass_b / avgTripTime_h;
                                    eff_thrpt_b = thrpt_up_b * Bike_EV_Design.availability;
                                    if eff_thrpt_b <= 0
                                        num_skipped = num_ratios;
                                        send(queue, ones(num_skipped,1));
                                        continue;
                                    end
                                    % Determine Optimum Road Vehicle/Bike mix for designs
                                    for ratio_road = mix_ratios_road
                                        ratio_bike = 1 - ratio_road;
                                        target_thrpt_r = peak_demand_pass_hr * ratio_road;
                                        target_thrpt_b = peak_demand_pass_hr * ratio_bike;
                                        req_fs_r = ceil(target_thrpt_r / eff_thrpt_r);
                                        req_fs_b = ceil(target_thrpt_b / eff_thrpt_b);
                                        totalFleetCost = (cost_road.total_vehicle_cost * req_fs_r) + (cost_bike.total_vehicle_cost * req_fs_b);
                                        actual_thrpt_r = req_fs_r * eff_thrpt_r;
                                        actual_thrpt_b = req_fs_b * eff_thrpt_b;
                                        totalActualThrpt = actual_thrpt_r + actual_thrpt_b;
                                        totalFleetTrips = (actual_thrpt_r / pass_r) + (actual_thrpt_b / pass_b);
                                        headway_min = 60 / totalFleetTrips;
                                        avgWaitTime_min = 0.5 * headway_min;
                                        design_metrics = struct('FleetThroughput_pass_hr', totalActualThrpt, 'AvgWaitTime_min', avgWaitTime_min, ...
                                            'Road_Availability', Road_EV_Design.availability, 'Bike_Availability', Bike_EV_Design.availability, ...
                                            'Fleet_Composition_Road_Vehicles', req_fs_r, 'Fleet_Composition_Bike_Vehicles', req_fs_b);
                                        valid_count_slice = valid_count_slice + 1;
                                        temp_cost(valid_count_slice) = totalFleetCost;
                                        temp_mau(valid_count_slice) = computeMAU(design_metrics);
                                        temp_throughput(valid_count_slice) = totalActualThrpt;
                                        temp_waittime(valid_count_slice) = avgWaitTime_min;
                                        temp_road_avail(valid_count_slice) = Road_EV_Design.availability;
                                        temp_bike_avail(valid_count_slice) = Bike_EV_Design.availability;
                                        temp_road_speed(valid_count_slice) = Road_EV_Design.mean_speed_km_h;
                                        temp_bike_speed(valid_count_slice) = Bike_EV_Design.mean_speed_km_h;
                                        temp_road_range(valid_count_slice) = Road_EV_Design.range_km;
                                        temp_bike_range(valid_count_slice) = Bike_EV_Design.range_km;
                                        temp_road_cost(valid_count_slice) = cost_road.total_vehicle_cost;
                                        temp_bike_cost(valid_count_slice) = cost_bike.total_vehicle_cost;
                                        temp_type{valid_count_slice} = 'Mixed';

                                        temp_specs{valid_count_slice} = sprintf("R(C%d..A%d)+B(F%d..M%d)", c_idx, a, f, m_b); % Abbreviated

                                        temp_fleet_r(valid_count_slice) = req_fs_r;
                                        temp_fleet_b(valid_count_slice) = req_fs_b;
                                        send(queue, 1); % Update counter
                                    end % ratio loop
                                end % bike motor
                            end % bike charger
                        end % bike battery
                    end % bike frame
                end % road autonomy
            end % road motor
        end % road charger
    end % road battery
    slice_results{c_idx} = {temp_cost(1:valid_count_slice), temp_mau(1:valid_count_slice), ...
        temp_type(1:valid_count_slice), temp_specs(1:valid_count_slice), ...
        temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice), ...
        temp_throughput(1:valid_count_slice), temp_waittime(1:valid_count_slice), ...
        temp_road_avail(1:valid_count_slice), temp_bike_avail(1:valid_count_slice), ...
        temp_road_speed(1:valid_count_slice), temp_bike_speed(1:valid_count_slice), ...
        temp_road_range(1:valid_count_slice), temp_bike_range(1:valid_count_slice), ...
        temp_road_cost(1:valid_count_slice), temp_bike_cost(1:valid_count_slice)};
end % End parfor c_idx

% Consolidate Mixed Results
idx = final_bike_idx + 1; % Start after last bike result
for i = 1:num_c
    if ~isempty(slice_results{i})
        num_valid_in_slice = length(slice_results{i}{1});
        if num_valid_in_slice > 0
            end_idx = idx + num_valid_in_slice - 1;
            results_cost(idx:end_idx) = slice_results{i}{1};
            results_mau(idx:end_idx) = slice_results{i}{2};
            results_arch_type(idx:end_idx) = slice_results{i}{3};
            results_specs(idx:end_idx) = slice_results{i}{4};
            results_fleet_road(idx:end_idx) = slice_results{i}{5};
            results_fleet_bike(idx:end_idx) = slice_results{i}{6};
            results_throughput(idx:end_idx) = slice_results{i}{7};
            results_waittime(idx:end_idx) = slice_results{i}{8};
            results_road_avail(idx:end_idx) = slice_results{i}{9};
            results_bike_avail(idx:end_idx) = slice_results{i}{10};
            results_road_speed(idx:end_idx) = slice_results{i}{11};
            results_bike_speed(idx:end_idx) = slice_results{i}{12};
            results_road_range(idx:end_idx) = slice_results{i}{13};
            results_bike_range(idx:end_idx) = slice_results{i}{14};
            results_road_cost(idx:end_idx) = slice_results{i}{15};
            results_bike_cost(idx:end_idx) = slice_results{i}{16};
            idx = end_idx + 1;
        end
    end
end
final_idx = idx - 1; % Find last valid index overall
clear slice_results;

% Ensure progress bar shows 100% (might be slightly off due to skips)
if isvalid(d)
    d.Value = 1;
    d.Message = sprintf('Finished processing. Found %d valid designs.', final_idx);
end
pause(0.5); % Brief pause to see final message
close(d); % Close the dialog
close(fig);

%% -- Analyze Reference Architectures (from Task 3) -- %%
% Re-run the 8 specific architectures from Task 3,
% using their fixed fleet sizes

%Pre-allocate the reference table
num_ref_designs = length(ref_designs);
varNames_ref = [
    "Cost", "Throughput", "WaitTime", "Road_Avail", "Bike_Avail", ...
    "Num_Road", "Num_Bike", "MAU"
    ];
varTypes_ref = [
    "double", "double", "double", "double", "double", ...
    "double", "double", "double"
    ];
ref_T = table('Size', [num_ref_designs, length(varNames_ref)], ...
    'VariableTypes', varTypes_ref, 'VariableNames', varNames_ref);

%Loop through these architectures
for ii = 1:length(ref_designs)
    design = ref_designs{ii};
    archType = ref_archTypes{ii};
    fleetSize_road = ref_fleetSizes.road{ii};
    fleetSize_bike = ref_fleetSizes.bike{ii};

    if strcmp(archType, 'road')
        [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);
        if ~isValid, continue; end

        % passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;
        % singleVehicleThroughput = passengersPerTrip / avgTripTime_h;
        % availableVehicles = fleetSize_road * Road_EV_Design.availability;
        % fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput;
        passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;

        max_fleet_capacity = (passengersPerTrip / avgTripTime_h) * (fleetSize_road * Road_EV_Design.availability);
        actual_throughput_in_scenario = min(peak_demand_pass_hr, max_fleet_capacity);
        actual_fleet_trips_per_hr = actual_throughput_in_scenario / passengersPerTrip;
        actual_wait_time_min = 0.5 * (60 / actual_fleet_trips_per_hr);

        ref_T.Cost(ii) = cost.total_vehicle_cost * fleetSize_road;
        ref_T.Throughput(ii) = actual_throughput_in_scenario; % Use actual
        ref_T.WaitTime(ii) = actual_wait_time_min; % Use actual
        ref_T.Road_Avail(ii) = Road_EV_Design.availability;
        ref_T.Bike_Avail(ii) = 0;
        ref_T.Num_Road(ii) = fleetSize_road;
        ref_T.Num_Bike(ii) = 0;
        ref_T.Road_Speed(ii) = Road_EV_Design.mean_speed_km_h;
        ref_T.Road_Range(ii) = Road_EV_Design.range_km;
        ref_T.Road_Cost(ii) = cost.total_vehicle_cost;
        ref_T.Bike_Speed(ii) = 0; ref_T.Bike_Range(ii) = 0; ref_T.Bike_Cost(ii) = 0;

    elseif strcmp(archType, 'bike')
        [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);
        if ~isValid, continue; end

        % passengersPerTrip = Bike_EV_Design.Pax * load_factor_per_trip;
        % singleVehicleThroughput = passengersPerTrip / avgTripTime_h;
        % availableVehicles = fleetSize_bike * Bike_EV_Design.availability;
        % fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput;
        passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;

        max_fleet_capacity = (passengersPerTrip / avgTripTime_h) * (fleetSize_road * Road_EV_Design.availability);
        actual_throughput_in_scenario = min(peak_demand_pass_hr, max_fleet_capacity);
        actual_fleet_trips_per_hr = actual_throughput_in_scenario / passengersPerTrip;
        actual_wait_time_min = 0.5 * (60 / actual_fleet_trips_per_hr);

        ref_T.Cost(ii) = cost.total_vehicle_cost * fleetSize_bike;
        ref_T.Throughput(ii) = actual_throughput_in_scenario;
        ref_T.WaitTime(ii) = actual_wait_time_min;
        ref_T.Road_Avail(ii) = 0;
        ref_T.Bike_Avail(ii) = Bike_EV_Design.availability;
        ref_T.Num_Road(ii) = 0;
        ref_T.Num_Bike(ii) = fleetSize_bike;
        ref_T.Road_Speed(ii) = 0; ref_T.Road_Range(ii) = 0; ref_T.Road_Cost(ii) = 0;
        ref_T.Bike_Speed(ii) = Bike_EV_Design.mean_speed_km_h;
        ref_T.Bike_Range(ii) = Bike_EV_Design.range_km;
        ref_T.Bike_Cost(ii) = cost.total_vehicle_cost;

    elseif strcmp(archType, 'mixed')
        [Road_EV_Design, roadVehicle_cost, road_isValid] = calculateRoadVehicle(design.road, roadDB);
        [Bike_EV_Design, bikeVehicle_cost, bike_isValid] = calculateBikeVehicle(design.bike, bikeDB);
        if ~road_isValid || ~bike_isValid, continue; end

        passengersPerTrip_road = Road_EV_Design.Pax * load_factor_per_trip;
        max_capacity_road = (passengersPerTrip_road / avgTripTime_h) * (fleetSize_road * Road_EV_Design.availability);

        passengersPerTrip_bike = Bike_EV_Design.Pax * load_factor_per_trip;
        max_capacity_bike = (passengersPerTrip_bike / avgTripTime_h) * (fleetSize_bike * Bike_EV_Design.availability);

        max_total_fleet_capacity = max_capacity_road + max_capacity_bike;
        actual_throughput_in_scenario = min(peak_demand_pass_hr, max_total_fleet_capacity);

        % Assume demand is split proportionally to capacity
        proportion_road = max_capacity_road / max_total_fleet_capacity;
        actual_throughput_road = actual_throughput_in_scenario * proportion_road;
        actual_throughput_bike = actual_throughput_in_scenario * (1 - proportion_road);

        actual_trips_road = actual_throughput_road / passengersPerTrip_road;
        actual_trips_bike = actual_throughput_bike / passengersPerTrip_bike;
        totalFleetTripsPerHr = actual_trips_road + actual_trips_bike;

        actual_wait_time_min = 0.5 * (60 / totalFleetTripsPerHr); %Calculate the actual wait time in minutes based on fleet trips per hour


        ref_T.Cost(ii) = (roadVehicle_cost.total_vehicle_cost * fleetSize_road) + (bikeVehicle_cost.total_vehicle_cost * fleetSize_bike);
        ref_T.Throughput(ii) = actual_throughput_in_scenario;
        ref_T.WaitTime(ii) = actual_wait_time_min;
        ref_T.Road_Avail(ii) = Road_EV_Design.availability;
        ref_T.Bike_Avail(ii) = Bike_EV_Design.availability;
        ref_T.Num_Road(ii) = fleetSize_road;
        ref_T.Num_Bike(ii) = fleetSize_bike;
        ref_T.Road_Speed(ii) = Road_EV_Design.mean_speed_km_h;
        ref_T.Road_Range(ii) = Road_EV_Design.range_km;
        ref_T.Road_Cost(ii) = roadVehicle_cost.total_vehicle_cost;
        ref_T.Bike_Speed(ii) = Bike_EV_Design.mean_speed_km_h;
        ref_T.Bike_Range(ii) = Bike_EV_Design.range_km;
        ref_T.Bike_Cost(ii) = bikeVehicle_cost.total_vehicle_cost;
    end

    %Calculate MAU for this reference point
    design_metrics = struct();
    design_metrics.FleetThroughput_pass_hr = ref_T.Throughput(ii);
    design_metrics.AvgWaitTime_min = ref_T.WaitTime(ii);
    design_metrics.Road_Availability = ref_T.Road_Avail(ii);
    design_metrics.Bike_Availability = ref_T.Bike_Avail(ii);
    design_metrics.Fleet_Composition_Road_Vehicles = ref_T.Num_Road(ii);
    design_metrics.Fleet_Composition_Bike_Vehicles = ref_T.Num_Bike(ii);

    ref_T.MAU(ii) = computeMAU(design_metrics);
end

%% -- Consolidate All Results for Plotting & Saving -- %%

% Get the results from the parfor loops
valid_indices = 1:final_idx;
Cost_new = results_cost(valid_indices);
MAU_new = results_mau(valid_indices);
Type_new = results_arch_type(valid_indices);
Specs_new = results_specs(valid_indices);
FleetSizeRoad_new = results_fleet_road(valid_indices);
FleetSizeBike_new = results_fleet_bike(valid_indices);
Throughput_new = results_throughput(valid_indices);
WaitTime_new = results_waittime(valid_indices);
RoadAvail_new = results_road_avail(valid_indices);
BikeAvail_new = results_bike_avail(valid_indices);
RoadSpeed_new = results_road_speed(valid_indices);
BikeSpeed_new = results_bike_speed(valid_indices);
RoadRange_new = results_road_range(valid_indices);
BikeRange_new = results_bike_range(valid_indices);
RoadCost_new = results_road_cost(valid_indices);
BikeCost_new = results_bike_cost(valid_indices);

num_ref_points = height(ref_T);
Cost_ref = ref_T.Cost;
MAU_ref = ref_T.MAU;
FleetSizeRoad_ref = ref_T.Num_Road;
FleetSizeBike_ref = ref_T.Num_Bike;
Throughput_ref = ref_T.Throughput;
WaitTime_ref = ref_T.WaitTime;
RoadAvail_ref = ref_T.Road_Avail;
BikeAvail_ref = ref_T.Bike_Avail;
RoadSpeed_ref = ref_T.Road_Speed;
BikeSpeed_ref = ref_T.Bike_Speed;
RoadRange_ref = ref_T.Road_Range;
BikeRange_ref = ref_T.Bike_Range;
RoadCost_ref = ref_T.Road_Cost;
BikeCost_ref = ref_T.Bike_Cost;
Specs_ref = cell(num_ref_points, 1);
Type_ref = cell(num_ref_points, 1);

for i = 1:num_ref_points
    % Get the type
    Type_ref{i} = ref_archTypes{i}; % Use the 'archType' from the top

    % Re-build the spec string from the 'ref_designs' definition
    if strcmp(ref_archTypes{i}, 'road')
        d_spec = ref_designs{i};
        Specs_ref{i} = sprintf("C%d, P%d, G%d, M%d, A%d", ...
            d_spec.chassis, d_spec.battery_pack, d_spec.battery_charger, d_spec.motor, d_spec.autonomy);
    elseif strcmp(ref_archTypes{i}, 'bike')
        d_spec = ref_designs{i};
        Specs_ref{i} = sprintf("B%d, E%d, G%d, K%d", ...
            d_spec.frame, d_spec.battery_pack, d_spec.battery_charger, d_spec.motor);
    else % mixed
        d_spec_r = ref_designs{i}.road;
        d_spec_b = ref_designs{i}.bike;
        specStr_road = sprintf("Road: (C%d..A%d)", d_spec_r.chassis, d_spec_r.autonomy);
        specStr_bike = sprintf("Bike: (B%d..K%d)", d_spec_b.frame, d_spec_b.motor);
        Specs_ref{i} = sprintf("%s; %s (Ref)", specStr_road, specStr_bike);
    end
end
%Combine multiple arrays related to costs, specifications,
% and performance metrics for new and reference vehicles into larger arrays for further analysis.
Cost_all = [Cost_new; Cost_ref];
MAU_all = [MAU_new; MAU_ref];
Type_all = [Type_new; Type_ref];
Specs_all = [Specs_new; Specs_ref];
FleetSizeRoad_all = [FleetSizeRoad_new; FleetSizeRoad_ref];
FleetSizeBike_all = [FleetSizeBike_new; FleetSizeBike_ref];
Throughput_all = [Throughput_new; Throughput_ref];
WaitTime_all = [WaitTime_new; WaitTime_ref];
RoadAvail_all = [RoadAvail_new; RoadAvail_ref];
BikeAvail_all = [BikeAvail_new; BikeAvail_ref];
RoadSpeed_all = [RoadSpeed_new; RoadSpeed_ref];
BikeSpeed_all = [BikeSpeed_new; BikeSpeed_ref];
RoadRange_all = [RoadRange_new; RoadRange_ref];
BikeRange_all = [BikeRange_new; BikeRange_ref];
RoadCost_all = [RoadCost_new; RoadCost_ref];
BikeCost_all = [BikeCost_new; BikeCost_ref];

%Identify and Plot Pareto Frontier (on ALL data, including defined architectures)
isPareto = true(length(Cost_all), 1);
for i = 1:length(Cost_all)
    for j = 1:length(Cost_all)
        if i == j, continue; end
        if (Cost_all(j) <= Cost_all(i)) && (MAU_all(j) >= MAU_all(i)) && ((Cost_all(j) < Cost_all(i)) || (MAU_all(j) > MAU_all(i)))
            isPareto(i) = false;
            break;
        end
    end
end
paretoIndices = find(isPareto);
[paretoCostSorted, sortOrder] = sort(Cost_all(paretoIndices));
paretoMAUSorted = MAU_all(paretoIndices(sortOrder));

%% -- Plot the Tradespace -- %%
%Define High-Contrast Colors
color_bike = [0.84, 0.37, 0.0];
color_mixed = [0.34, 0.34, 0.34];
color_road = [0, 0.45, 0.70];
figure;
hold on;

%Plot scatterers from the master list
idx_bike = strcmp(Type_all, 'Bike');
idx_road = strcmp(Type_all, 'Road');
idx_mixed = strcmp(Type_all, 'Mixed');
scatter(Cost_all(idx_mixed) / 1e6, MAU_all(idx_mixed), 15, color_mixed, '.','DisplayName','Mixed Fleets');
scatter(Cost_all(idx_road) / 1e6, MAU_all(idx_road), 12, color_road, '.','DisplayName','Road Vehicles');
scatter(Cost_all(idx_bike) / 1e6, MAU_all(idx_bike), 25, color_bike, '.','DisplayName','Bike Vehicles');

xlabel('Total Fleet Cost ($ Millions)');
ylabel('Multi-Attribute Utility (MAU)');

title_str_line1 = 'Task 4: Off-Peak Scenario Tradespace (Cost vs. Utility)';
title_str_line2 = sprintf('%s Valid Architectures Found', num2str(length(Cost_all), '%d'));
title({title_str_line1, title_str_line2});
grid on; box on;

%Plot Utopia (and please take me to it after this OS)
plot(0, 1, 'ksq', 'MarkerSize', 10, 'MarkerFaceColor', 'g','DisplayName','Utopia Point');

% Plot the True Pareto Frontier
plot(paretoCostSorted / 1e6, paretoMAUSorted, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Pareto Frontier');

%Plot Task 3 Reference Points
num_baseline = length(ref_designs) - 3; %hand-picked designs - the 3 Pareto ones
num_pareto = length(ref_designs) - num_baseline; %Task 3 Pareto

%Plot the 5 Baseline Architectures
plot(ref_T.Cost(1:num_baseline) / 1e6, ref_T.MAU(1:num_baseline),...
    'p', 'MarkerSize', 14, ...
    'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'm', ...
    'DisplayName', 'Task 3 Reference Arch.');

%Plot the 3 Pareto Architectures
if num_pareto > 0
    for i = 1:num_pareto
        plot_idx = num_baseline + i;
        h_pareto(i) = plot(ref_T.Cost(plot_idx) / 1e6, ref_T.MAU(plot_idx), ...
            'rd', ...
            'MarkerSize', 10, ...
            'MarkerFaceColor', 'r', ...
            'LineWidth', 1.5, ...
            'DisplayName', sprintf('Pareto Design %d', i));
    end
end

legend
hold off;

%% -- Output Table to an Excel file and Save Plot -- %%

% --- Create the Final Table from the Master lists ---
T_results = table(Cost_all, MAU_all, isPareto, Type_all, Specs_all, ...
    FleetSizeRoad_all, FleetSizeBike_all, ...
    Throughput_all, WaitTime_all, ...
    RoadAvail_all, BikeAvail_all, ...
    RoadSpeed_all, BikeSpeed_all, ...
    RoadRange_all, BikeRange_all, ...
    RoadCost_all, BikeCost_all, ...
    'VariableNames', {'TotalFleetCost_USD', 'MAU', 'IsOnParetoFrontier', 'ArchType', 'Specifications', ...
    'FleetSize_Road', 'FleetSize_Bike', 'FleetThroughput_pass_hr', ...
    'AvgWaitTime_min', 'Road_Availability', 'Bike_Availability', ...
    'Road_Speed_kmh', 'Bike_Speed_kmh', ...
    'Road_Range_km', 'Bike_Range_km', ...
    'Road_Vehicle_Cost_USD', 'Bike_Vehicle_Cost_USD'});

varNames = T_results.Properties.VariableNames;
varNames = strrep(varNames, '_', ' ');
T_results.Properties.VariableNames = varNames;

targetDir = fullfile('..', '..', 'OS 4');
outputFileName = 'Task_4_All_Architectures_Parallel.xlsx'; % Renamed file
fullOutputPath = fullfile(targetDir, outputFileName);

if ~isfolder(targetDir)
    fprintf('Directory "%s" not found. Creating it...\n', targetDir);
    mkdir(targetDir);
end

writetable(T_results, fullOutputPath);

%Save the Tradespace Plot
figHandle = gcf;
plotFileName_fig = 'Task_4_All_Arch_Pareto_Plot.fig';
plotFileName_tif = 'Task_4_All_Arch_Pareto_Plot.tif';
fullPlotPath_fig = fullfile(targetDir, plotFileName_fig);
savefig(figHandle, fullPlotPath_fig);
fullPlotPath_tif = fullfile(targetDir, plotFileName_tif);
print(figHandle, fullPlotPath_tif, '-dtiff', '-r300');
fprintf('~~ Life is faster on Apple Silicon ~~\n');
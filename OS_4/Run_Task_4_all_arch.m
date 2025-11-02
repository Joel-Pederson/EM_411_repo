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

%Arch 1: Ultra Minimal Road Vehicle 
ref_designs{1}.chassis = 1;         % C1 (2 pax)
ref_designs{1}.battery_pack = 1;    % P1 (50 kWh)
ref_designs{1}.battery_charger = 1; % G1 (10 kW)
ref_designs{1}.motor = 1;           % M1 (50 kW)
ref_designs{1}.autonomy = 1;        % A3 (Level 3)
ref_archTypes{1} = 'road';
ref_fleetSizes.road{1} = 19;        %count of vehicles
ref_fleetSizes.bike{1} = 0;         %count of bikes

%Arch 2: Autonomous Shuttle Fleet 
ref_designs{2}.chassis = 4;         %C4 (8 pax shuttle) 
ref_designs{2}.battery_pack = 3;    %P3 (150kWh)
ref_designs{2}.battery_charger = 3; %G3 (60 kW)
ref_designs{2}.motor = 3;           %M3 (210 kW)
ref_designs{2}.autonomy = 2;        %A4 (Level 4)
ref_archTypes{2} = 'road';
ref_fleetSizes.road{2} = 4;        %count of vehicles
ref_fleetSizes.bike{2} = 0;         %count of bikes

%Arch 3: Electric Bike Fleet
ref_designs{3}.frame = 3;            % B3 (2 pax, 35 kg) 
ref_designs{3}.battery_pack = 2;     % E2 (1.5 kWh) 
ref_designs{3}.battery_charger = 2;  % G2 (0.6 kW)
ref_designs{3}.motor = 2;            % K2 (0.5 kW)
ref_archTypes{3} = 'bike';
ref_fleetSizes.road{3} = 0;          %count of vehicles
ref_fleetSizes.bike{3} = 26;        %count of bikes

%Arch 4: Mixed Fleet (Autonomous Road + Electric Bike) 
ref_designs{4}.road = ref_designs{1};        % Use Arch 1
ref_designs{4}.bike = ref_designs{3};        % Use Arch 3 bike 
ref_archTypes{4} = 'mixed';
ref_fleetSizes.road{4} = 15;              %count of vehicles
ref_fleetSizes.bike{4} = 5;              %count of bikes

%Arch 5: Mixed Fleet More Autonomy (Road + Bike)
ref_designs{5}.road = ref_designs{2};         % Use Arch 2 shuttle
ref_designs{5}.road.autonomy = 3;         % ...but with A5 (Level 5)
ref_designs{5}.bike = ref_designs{3};         % Use Arch 3 bike 
ref_designs{5}.bike.battery_pack = 2;     % E2 (1.5 kWh)
ref_designs{5}.bike.battery_charger = 1;  % G1 (0.2 kW)
ref_designs{5}.bike.motor = 1;            % K1 (0.35 kW)
ref_archTypes{5} = 'mixed';
ref_fleetSizes.road{5} = 3;              %count of vehicles
ref_fleetSizes.bike{5} = 10;              %count of bikes

%Arch 6: Task 3 Pareto Point 1 
ref_designs{6}.chassis = 8;         %C8 (30 pax shuttle) 
ref_designs{6}.battery_pack = 1;    %P1 (50 kWh)
ref_designs{6}.battery_charger = 3; %G3 (60 kW)
ref_designs{6}.motor = 1;           %M1 (50 kW)
ref_designs{6}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{6} = 'road';
ref_fleetSizes.road{6} = 1;         %count of vehicles (1 shuttle)
ref_fleetSizes.bike{6} = 0;         %count of bikes

%Arch 7: Task 3 Pareto Point 2 
ref_designs{7}.chassis = 6;         %C6 (16 pax shuttle) 
ref_designs{7}.battery_pack = 1;    %P1 (50 kWh)
ref_designs{7}.battery_charger = 3; %G3 (60 kW)
ref_designs{7}.motor = 1;           %M1 (50 kW)
ref_designs{7}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{7} = 'road';
ref_fleetSizes.road{7} = 2;         %count of vehicles (2 shuttles)
ref_fleetSizes.bike{7} = 0;         %count of bikes

%Arch 8: Task 3 Pareto Point 3
ref_designs{8}.chassis = 7;         %C7 (20 pax shuttle) 
ref_designs{8}.battery_pack = 6;    %P6 (310 kWh)
ref_designs{8}.battery_charger = 3; %G3 (60 kW)
ref_designs{8}.motor = 1;           %M1 (50 kW)
ref_designs{8}.autonomy = 1;        %A3 (Level 3)
ref_archTypes{8} = 'road';
ref_fleetSizes.road{8} = 2;         %count of vehicles (2 shuttles)
ref_fleetSizes.bike{8} = 0;         %count of bikes

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
%confidently lying about figure windows and MATLAB co-pilot new the syntax
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

%% -- Explore all PURE ROAD Vehicle Architectures -- %%
road_offset = 0; % Starting index for road results

parfor c_idx = 1:num_c % PARFOR loop
    % Need temporary storage inside parfor loop as jobs are handed out
    temp_cost = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_mau = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
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
                            temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice)};
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
            idx = end_idx + 1;
        end
    end
end
final_road_idx = idx - 1;
clear slice_results; % Clear temporary storage


%% -- Explore all PURE BIKE Vehicle Architectures -- %%
bike_offset = final_road_idx; % Start index for bike results
slice_results = cell(num_f, 1); % Reinitialize for bikes

parfor f_idx = 1:num_f 
    temp_cost = NaN(num_b_b * num_g_b * num_m_b, 1);
    temp_mau = NaN(num_b_b * num_g_b * num_m_b, 1);
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
                            temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice)};
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
            idx = end_idx + 1;
        end
     end
end
final_bike_idx = idx - 1;
clear slice_results;

%% -- Explore MIXED Fleet Architectures -- %%
mix_offset = final_bike_idx;
mix_ratios_road = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]; % Road contribution target
num_ratios = length(mix_ratios_road);
slice_results = cell(num_c, 1); % Reinitialize for mixed
parfor c_idx = 1:num_c % PARFOR loop for road chassis
    % Preallocate temp storage for ONE slice of the outer loop
    max_inner_iterations = num_b_r*num_g_r*num_m_r*num_a * num_bike_designs * num_ratios;
    temp_cost = NaN(max_inner_iterations, 1);
    temp_mau = NaN(max_inner_iterations, 1);
    temp_type = cell(max_inner_iterations, 1);
    temp_specs = cell(max_inner_iterations, 1);
    temp_fleet_r = NaN(max_inner_iterations, 1);
    temp_fleet_b = NaN(max_inner_iterations, 1);
    valid_count_slice = 0; % Index within this slice
    for b_r = 1:num_b_r
      for g_r = 1:num_g_r
        for m_r = 1:num_m_r
          for a = 1:num_a % <-- FIXED (was 'aa')
            
            % --- FIXED: Use 'design_road' as input ---
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
                        temp_type{valid_count_slice} = 'Mixed';
                        
                        % --- FIXED: Use 'a' not 'aa' ---
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
                           temp_fleet_r(1:valid_count_slice), temp_fleet_b(1:valid_count_slice)};
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

%Loop through these 8 architectures 
for ii = 1:length(ref_designs)
    design = ref_designs{ii};
    archType = ref_archTypes{ii};
    fleetSize_road = ref_fleetSizes.road{ii};
    fleetSize_bike = ref_fleetSizes.bike{ii};
    
    if strcmp(archType, 'road')
        [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);
        if ~isValid, continue; end
        
        passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput = passengersPerTrip / avgTripTime_h;
        availableVehicles = fleetSize_road * Road_EV_Design.availability;
        fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput;
        
        ref_T.Cost(ii) = cost.total_vehicle_cost * fleetSize_road;
        ref_T.Throughput(ii) = fleetThroughput_passengers_hr;
        ref_T.WaitTime(ii) = 0.5 * (60 / (fleetThroughput_passengers_hr / passengersPerTrip));
        ref_T.Road_Avail(ii) = Road_EV_Design.availability;
        ref_T.Bike_Avail(ii) = 0;
        ref_T.Num_Road(ii) = fleetSize_road;
        ref_T.Num_Bike(ii) = 0;
        
    elseif strcmp(archType, 'bike')
        [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);
        if ~isValid, continue; end
        
        passengersPerTrip = Bike_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput = passengersPerTrip / avgTripTime_h;
        availableVehicles = fleetSize_bike * Bike_EV_Design.availability;
        fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput;
        ref_T.Cost(ii) = cost.total_vehicle_cost * fleetSize_bike;
        ref_T.Throughput(ii) = fleetThroughput_passengers_hr;
        ref_T.WaitTime(ii) = 0.5 * (60 / (fleetThroughput_passengers_hr / passengersPerTrip));
        ref_T.Road_Avail(ii) = 0;
        ref_T.Bike_Avail(ii) = Bike_EV_Design.availability;
        ref_T.Num_Road(ii) = 0;
        ref_T.Num_Bike(ii) = fleetSize_bike;
        
    elseif strcmp(archType, 'mixed')
        [Road_EV_Design, roadVehicle_cost, road_isValid] = calculateRoadVehicle(design.road, roadDB);
        [Bike_EV_Design, bikeVehicle_cost, bike_isValid] = calculateBikeVehicle(design.bike, bikeDB);
        if ~road_isValid || ~bike_isValid, continue; end
        
        passengersPerTrip_road = Road_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput_road = passengersPerTrip_road / avgTripTime_h;
        availableVehicles_road = fleetSize_road * Road_EV_Design.availability;
        fleetThroughput_road = availableVehicles_road * singleVehicleThroughput_road;
        
        passengersPerTrip_bike = Bike_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput_bike = passengersPerTrip_bike / avgTripTime_h;
        availableVehicles_bike = fleetSize_bike * Bike_EV_Design.availability;
        fleetThroughput_bike = availableVehicles_bike * singleVehicleThroughput_bike;
        totalFleetCost = (roadVehicle_cost.total_vehicle_cost * fleetSize_road) + (bikeVehicle_cost.total_vehicle_cost * fleetSize_bike);
        totalFleetThroughput = fleetThroughput_road + fleetThroughput_bike;
        totalFleetTripsPerHr = (fleetThroughput_road / passengersPerTrip_road) + (fleetThroughput_bike / passengersPerTrip_bike);
        
        ref_T.Cost(ii) = totalFleetCost;
        ref_T.Throughput(ii) = totalFleetThroughput;
        ref_T.WaitTime(ii) = 0.5 * (60 / totalFleetTripsPerHr);
        ref_T.Road_Avail(ii) = Road_EV_Design.availability;
        ref_T.Bike_Avail(ii) = Bike_EV_Design.availability;
        ref_T.Num_Road(ii) = fleetSize_road;
        ref_T.Num_Bike(ii) = fleetSize_bike;
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
%% -- Plot the Tradespace -- %%
% Remove unused pre-allocated space and NaN values
valid_indices = 1:final_idx; 
Cost = results_cost(valid_indices);
MAU = results_mau(valid_indices);
Type = results_arch_type(valid_indices);
Specs = results_specs(valid_indices);
FleetSizeRoad = results_fleet_road(valid_indices);
FleetSizeBike = results_fleet_bike(valid_indices);

%Define High-Contrast Colors
color_bike = [0.84, 0.37, 0.0];   
color_mixed = [0.34, 0.34, 0.34];  
color_road = [0, 0.45, 0.70];     

figure;
hold on; 

%Plot scatterers 
idx_bike = strcmp(Type, 'Bike');
idx_road = strcmp(Type, 'Road');
idx_mixed = strcmp(Type, 'Mixed');
scatter(Cost(idx_mixed) / 1e6, MAU(idx_mixed), 16, color_mixed, '.'); 
scatter(Cost(idx_road) / 1e6, MAU(idx_road), 16, color_road, '.');    
scatter(Cost(idx_bike) / 1e6, MAU(idx_bike), 16, color_bike, '.'); 

xlabel('Total Fleet Cost ($ Millions)');
ylabel('Multi-Attribute Utility (MAU)');
title(sprintf('Task 4: Off-Peak Scenario Tradespace (Cost vs. Utility)\n%d Valid Architectures Found', final_idx));
grid on; box on;
plot(0, 1, 'ksq', 'MarkerSize', 10, 'MarkerFaceColor', 'g');

%Identify and Plot Pareto Frontier (for the new off-peak tradespace)
isPareto = true(length(Cost), 1); 
for i = 1:length(Cost)
    for j = 1:length(Cost)
        if i == j, continue; end 
        if (Cost(j) <= Cost(i)) && (MAU(j) >= MAU(i)) && ((Cost(j) < Cost(i)) || (MAU(j) > MAU(i)))
            isPareto(i) = false; 
            break; 
        end
    end
end
paretoIndices = find(isPareto);
[paretoCostSorted, sortOrder] = sort(Cost(paretoIndices));
paretoMAUSorted = MAU(paretoIndices(sortOrder));
plot(paretoCostSorted / 1e6, paretoMAUSorted, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Pareto Frontier');

%Plot Task 3 Reference Points
num_baseline = 5; %hand-picked ones
num_pareto = length(ref_designs) - num_baseline; %Task 3 Pareto

% %Plot the 5 Baseline Architectures 
% plot(ref_T.Cost(1:num_baseline) / 1e6, ref_T.MAU(1:num_baseline), ...
%      'k*', ... 
%      'MarkerSize', 12, ...
%      'LineWidth', 1.5, ...
%      'DisplayName', 'Task 3 Baseline Archs');
     
%Plot the 3 Pareto Architectures
% if num_pareto > 0
%     plot(ref_T.Cost(num_baseline+1:end) / 1e6, ref_T.MAU(num_baseline+1:end), ...
%          'rd', ...
%          'MarkerSize', 10, ...
%          'MarkerFaceColor', 'r', ...
%          'LineWidth', 1.5, ...
%          'DisplayName', 'Task 3 Pareto Archs');
% end

legend('Mixed Fleets', 'Road Vehicles', 'Bike Vehicles', 'Utopia Point', ...
       'Off-Peak Pareto Frontier', ...
       'Location', 'southeast');
%ylim([min(MAU) - 0.05, 1.05]); % Pad the y-axis

%Add Task 2 Reference Architecture
plot(398600/1e6, 0.917801539,"pentagram",'MarkerSize',14,'MarkerEdgeColor','k','MarkerFaceColor','m','DisplayName','Reference Architecture')

%Add Interesting Task 3 Pareto Frontier Designs
plot(188400/1e6, 0.970558015797232,"diamond",'MarkerSize',10,'MarkerEdgeColor','k','MarkerFaceColor','b','DisplayName','Pareto Design 1')
plot(130400/1e6, 0.950885394805296,"diamond",'MarkerSize',10,'MarkerEdgeColor','k','MarkerFaceColor','m','DisplayName','Pareto Design 2')
plot(79200/1e6, 0.945472973184039,"diamond",'MarkerSize',10,'MarkerEdgeColor','k','MarkerFaceColor','k','DisplayName','Pareto Design 3')

hold off;

%% -- Output Table to an Excel file and Save Plot -- %%
T_results = table(Cost, MAU, isPareto, Type, Specs, FleetSizeRoad, FleetSizeBike, ...
                  'VariableNames', {'TotalFleetCost_USD', 'MAU', 'IsOnParetoFrontier', 'ArchType', 'Specifications', 'FleetSize_Road', 'FleetSize_Bike'});

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
fprintf('\nFull results table saved to %s\n', fullOutputPath);

% Save the Tradespace Plot 
figHandle = gcf;

plotFileName_fig = 'Task_4_All_Arch_Pareto_Plot.fig';
plotFileName_tif = 'Task_4_All_Arch_Pareto_Plot.tif';

fullPlotPath_fig = fullfile(targetDir, plotFileName_fig);
savefig(figHandle, fullPlotPath_fig);

fullPlotPath_tif = fullfile(targetDir, plotFileName_tif);
print(figHandle, fullPlotPath_tif, '-dtiff', '-r300'); 

fprintf('Plot saved to %s\n', targetDir);
fprintf('~~ Life is faster on Apple Silicon ~~\n');
%% -- EM.411 OS 4 Task 3 - Full Tradespace Exploration (Parallel w/ Waitbar) -- %%
% Explores pure road, pure bike, and strategic mixed fleets using parfor.
% Calculates fleet size, cost, and utility for each valid design.
% Dependencies: MATLAB Parallel Computing Toolbox
% https://github.com/Joel-Pederson/EM_411_repo
%% Scenario:
% Peak rush-hour traffic in the morning (0800)
% Model Note: This uses a demand-limited modeling approach. So the
% performance of the system cannot exceed mean demand as defined in appendix B
%% -- Load Database -- %%
[roadDB, bikeDB] = load_DB(); 

%% -- Define Fleet-Level Model Assumptions -- %%
%Values from Table 1 unless otherwise noted
max_travel_time_min = 7; %max transportation time
dwell_time_s = 60; %time for passengers get in and out
average_trip_time_min = (max_travel_time_min + (dwell_time_s / 60));
avgTripTime_h = average_trip_time_min / 60;
peak_demand_pass_hr = 150; % Target throughput
load_factor_per_trip = 0.75; %from appendix B

%% -- Initialize Results Storage -- %%
% Calculate total number of designs for pre-allocation
num_c = length(roadDB.chassis); num_b_r = length(roadDB.battery_pack); num_g_r = length(roadDB.battery_charger); num_m_r = length(roadDB.motor); num_a = length(roadDB.autonomy);
num_f = length(bikeDB.frame); num_b_b = length(bikeDB.battery_pack); num_g_b = length(bikeDB.battery_charger); num_m_b = length(bikeDB.motor);

num_road_designs = num_c * num_b_r * num_g_r * num_m_r * num_a;
num_bike_designs = num_f * num_b_b * num_g_b * num_m_b;
num_mixed_designs = num_road_designs * num_bike_designs * 3; % 3 ratios per combo

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

% Create Progress Dialog
d = uiprogressdlg(figure('Name','Tradespace Exploration'), 'Title','Please Wait',...
                  'Message','Starting exploration...', 'Value',0, 'Cancelable','off');

% Create DataQueue and specify the callback
queue = parallel.pool.DataQueue;
afterEach(queue, @updateProgress); % Call updateProgress after each send

% Function to update progress dialog (nested function)
function updateProgress(~) %created this waitbar config with the help of MATLAB co-pilot because the Mathworks does not make this easy to do in parallel enviornment...
    processed_count = processed_count + 1; % Increment based on message received
    if mod(processed_count, update_frequency) == 0 || processed_count == total_designs_estimate
         progress_value = processed_count / total_designs_estimate;
         if isvalid(d) % Check if dialog hasn't been closed
             d.Value = progress_value;
             d.Message = sprintf('Processing design %d of ~%d (%.0f%%)...', ...
                                 processed_count, total_designs_estimate, progress_value*100);
             drawnow limitrate; % Update UI, limit rate
         end
    end
end

%% -- Explore all PURE ROAD Vehicle Architectures -- %%
road_offset = 0; % Starting index for road results

parfor c_idx = 1:num_c % PARFOR loop
    % Need temporary storage inside parfor loop
    temp_cost = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_mau = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_type = cell(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_specs = cell(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_fleet_r = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    temp_fleet_b = NaN(num_b_r * num_g_r * num_m_r * num_a, 1);
    valid_count_slice = 0; % Count valid designs in this "slice"

    for bb = 1:num_b_r
        for gg = 1:num_g_r
            for mm = 1:num_m_r
                for aa = 1:num_a

                    design = struct('chassis', c_idx, 'battery_pack', bb, 'battery_charger', gg, 'motor', mm, 'autonomy', aa);
                    [perf, cost, isValid] = calculateRoadVehicle(design, roadDB);

                    if ~isValid
                        send(queue, 1); % Send update even for invalid
                        continue;
                    end

                    passengersPerTrip = perf.Pax * load_factor_per_trip;
                    singleVehicleThroughput_up = passengersPerTrip / avgTripTime_h;
                    effectiveVehicleThroughput = singleVehicleThroughput_up * perf.availability;

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
                                            'Road_Availability', perf.availability, 'Bike_Availability', 0, ...
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
                [perf, cost, isValid] = calculateBikeVehicle(design, bikeDB);

                if ~isValid
                    send(queue, 1);
                    continue;
                end

                passengersPerTrip = perf.Pax * load_factor_per_trip;
                singleVehicleThroughput_up = passengersPerTrip / avgTripTime_h;
                effectiveVehicleThroughput = singleVehicleThroughput_up * perf.availability;

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
                                        'Road_Availability', 0, 'Bike_Availability', perf.availability, ...
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

%% -- Explore MIXED Fleet Architectures (Parallel) -- %%
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
          for aa = 1:num_a
            design_road = struct('chassis', c_idx, 'battery_pack', b_r, 'battery_charger', g_r, 'motor', m_r, 'autonomy', aa);
            [perf_road, cost_road, isValid_road] = calculateRoadVehicle(design_road, roadDB);
            if ~isValid_road
                % Need to account for skipped iterations in progress counter
                num_skipped = num_bike_designs * num_ratios;
                send(queue, ones(num_skipped,1)); % Send multiple updates
                continue;
            end

            pass_r = perf_road.Pax * load_factor_per_trip;
            thrpt_up_r = pass_r / avgTripTime_h;
            eff_thrpt_r = thrpt_up_r * perf_road.availability;
            if eff_thrpt_r <= 0
                num_skipped = num_bike_designs * num_ratios;
                send(queue, ones(num_skipped,1));
                continue;
            end

            for f = 1:num_f
              for b_b = 1:num_b_b
                for g_b = 1:num_g_b
                  for m_b = 1:num_m_b
                    design_bike = struct('frame', f, 'battery_pack', b_b, 'battery_charger', g_b, 'motor', m_b);
                    [perf_bike, cost_bike, isValid_bike] = calculateBikeVehicle(design_bike, bikeDB);
                    if ~isValid_bike
                        num_skipped = num_ratios;
                        send(queue, ones(num_skipped,1));
                        continue;
                    end

                    pass_b = perf_bike.Pax * load_factor_per_trip;
                    thrpt_up_b = pass_b / avgTripTime_h;
                    eff_thrpt_b = thrpt_up_b * perf_bike.availability;
                    if eff_thrpt_b <= 0
                        num_skipped = num_ratios;
                        send(queue, ones(num_skipped,1));
                        continue;
                    end

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
                                                'Road_Availability', perf_road.availability, 'Bike_Availability', perf_bike.availability, ...
                                                'Fleet_Composition_Road_Vehicles', req_fs_r, 'Fleet_Composition_Bike_Vehicles', req_fs_b);

                        valid_count_slice = valid_count_slice + 1;
                        temp_cost(valid_count_slice) = totalFleetCost;
                        temp_mau(valid_count_slice) = computeMAU(design_metrics);
                        temp_type{valid_count_slice} = 'Mixed';
                        temp_specs{valid_count_slice} = sprintf("R(C%d..A%d)+B(F%d..M%d)", c_idx, aa, f, m_b); % Abbreviated
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

% --- Consolidate Mixed Results ---
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

fprintf('Exploration complete. %d valid architectures found.\n', final_idx);

%% --- 4. Plot the Tradespace --- %%
% Remove unused pre-allocated space and NaN values
valid_indices = 1:final_idx; % Use indices up to the last valid one found
Cost = results_cost(valid_indices);
MAU = results_mau(valid_indices);
Type = results_arch_type(valid_indices);
Specs = results_specs(valid_indices);
FleetSizeRoad = results_fleet_road(valid_indices);
FleetSizeBike = results_fleet_bike(valid_indices);

% Plot the tradespace, color-coded by vehicle type
figure;
h = gscatter(Cost / 1e6, MAU, Type, 'rbm', 'o.o', 6, 'on'); % Red=Road, Blue=Bike, Magenta=Mixed, smaller markers
xlabel('Total Fleet Cost ($ Millions)');
ylabel('Multi-Attribute Utility (MAU)');
title('Task 3: Tradespace Exploration (Cost vs. Utility)');
grid on;
axis padded;

% Add Utopia Point
hold on;
plot(0, 1, 'ksq', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
text(max(Cost/1e6)*0.01, 0.98, 'Utopia Point', 'FontWeight', 'bold');

% --- Identify and Plot Pareto Frontier (Approximate) ---
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
legend('Road Vehicles', 'Bike Vehicles', 'Mixed Fleets', 'Utopia Point','Pareto Frontier', 'Location', 'southeast');
hold off;

fprintf('Tradespace plot generated with Pareto Frontier.\n');

%% --- 5. Output Table to an Excel file -- %%
T_results = table(Cost, MAU, Type, Specs, FleetSizeRoad, FleetSizeBike, ...
                  'VariableNames', {'TotalFleetCost_USD', 'MAU', 'ArchType', 'Specifications', 'FleetSize_Road', 'FleetSize_Bike'});

varNames = T_results.Properties.VariableNames;
varNames = strrep(varNames, '_', ' ');
T_results.Properties.VariableNames = varNames;

targetDir = fullfile('..', '..', 'OS 4');
outputFileName = 'Task_3_All_Architectures_Parallel.xlsx'; % Renamed file
fullOutputPath = fullfile(targetDir, outputFileName);
if ~isfolder(targetDir)
    fprintf('Directory "%s" not found. Creating it...\n', targetDir);
    mkdir(targetDir);
end
writetable(T_results, fullOutputPath);
fprintf('\nFull results table saved to %s\n', fullOutputPath);
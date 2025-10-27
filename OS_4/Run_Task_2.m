%% -- EM.411 OS 4 Task 2 -- %%
% This script models 5 unique fleet architectures and generates the
% data table required for the Task 2 deliverable.
% https://github.com/Joel-Pederson/EM_411_repo

%% Scenario:
% Peak rush-hour traffic in the morning (0800)

%% -- Load Database -- %%
[roadDB, bikeDB] = load_DB();

%% -- Define Fleet-Level Model Assumptions -- %%
%Values from Table 1 unless otherwise noted
max_travel_time_min = 7; %max transportation time between any 2 locations within system boundary
dwell_time_s = 60; %time for passengers get in and out
average_trip_time_min = (max_travel_time_min + (dwell_time_s / 60));
peak_passenger_throughput_per_hour = 150; %passengers per hour at peak
off_peak_passenger_throughput_per_hour = 50; %passengers per hour during off-peak
daily_passenger_volume = 1500; %passengers per day
load_factor_per_trip = 0.75; %from appendix B
max_wait_time_within_boundary_min = 5; %maximum waiting time for transportation within system boundary
max_wait_time_outside_of_boundary_min = 20; %maximum waiting time for transportation outside of system boundary

%% -- Define Unique Architectures -- %%

designs = {};     % Stores the component indices for each architecture
archTypes = {};   % Stores the type: 'road' or 'bike'
fleetSizes = [];  % Stores the fleet size assumption for each architecture

% Option 1 - Ultra Minimal Road Vehicle
% 'design' must be a struct containing the index for EACH component.
designs{1}.chassis = 1;         % C1 (2 pax)
designs{1}.battery_pack = 1;    % P1 (50 kWh)
designs{1}.battery_charger = 1; % G1 (10 kW)
designs{1}.motor = 1;           % M1 (50 kW)
designs{1}.autonomy = 2;        % A4 (Level 4)
archTypes{1} = 'road';
fleetSizes.road{1} = 25; %count of vehicles
fleetSizes.bike{1} = 0;

% Option 2 - TBD
% designs{2}.chassis = ;         
% designs{2}.battery_pack = ;    
% designs{2}.battery_charger = ; 
% designs{2}.motor = ;          
% designs{2}.autonomy = ;      
% archTypes{2} = 'road';
% fleetSizes.road{2} = ; %count of vehicles
% fleetSizes.bike{2} = ;

% Option 3 - All Bike Fleet
% designs{2}.battery_pack = ;    
% designs{2}.battery_charger = ; 
% designs{2}.motor = ;          
% archTypes{2} = 'bike';
% fleetSizes.road{2} = 0; %count of vehicles
% fleetSizes.bike{2} = ;

% Option 4 - TBD

% % Option 5 - Mixed Fleet (Road + Bike)
% designs{5}.road = designs{1}; % Use the TBD design
% designs{5}.bike = designs{4}; % Use the TBD design
% designs{5}.archTypes = 'mixed';
% fleetSizes{5}.road = 15; % Assumption: 15 road vehicles
% fleetSizes{5}.bike = 50; % Assumption: 50 bikes

%% -- Execute Model -- %%
T = table;
avgTripTime_h = average_trip_time_min / 60; % Convert to hours for simplicity
for ii = 1:length(designs)
    design = designs{ii};
    archType = archTypes{ii};
    fleetSize_road = fleetSizes.road{ii};
    fleetSize_bike = fleetSizes.bike{ii};
    
    T.Architecture(ii) = {sprintf("Architecture %d", ii)};
    
    if strcmp(archType, 'road')
        [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);
        
        if ~isValid 
            str = sprintf('WARNING: Road Arch %d (Chassis %s, Battery %s) is INVALID. Must replace it. Skipping for now...\n', ...
                ii, roadDB.chassis(design.chassis).Name, roadDB.battery_pack(design.battery_pack).Name);
            warning(str);
            continue
        end
        
        % Fleet Calculations for Road 
        T.Fleet_Size(ii,1) = fleetSize_road + fleetSize_bike;
        T.Fleet_Composition_Road_Vehicles(ii,1) = fleetSize_road;
        T.Fleet_Composition_Bike_Vehicles(ii,1) = fleetSize_bike;
        T.Fleet_Cost_USD(ii,1) = cost.total_vehicle_cost * fleetSize_road;
        T.Road_Vehicle_Cost_USD(ii,1) = cost.total_vehicle_cost;
        T.Bike_Vehicle_Cost_USD(ii,1) = 0;
        
        % Performance Metrics for Road 
        %Throughput
        %Reference for throughput and headway equations: 
        %   https://en.wikibooks.org/wiki/Fundamentals_of_Transportation/Network_Design_and_Frequency
        %   https://en.wikibooks.org/wiki/Fundamentals_of_Transportation/Transit_Operations_and_Capacity
        passengersPerTrip = Road_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput = passengersPerTrip / avgTripTime_h; %persons per hour per vehicle
        availableVehicles = fleetSize_road * Road_EV_Design.availability;
        fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput; %persons per hour for the fleet
        fleetTripsPerHr = fleetThroughput_passengers_hr / passengersPerTrip; %compute trips based on persons per hour throughput
        headway_min = 60 / fleetTripsPerHr; %inverse of frequency - number of vehicles per hour 
        
        T.FleetThroughput_pass_hr(ii) = fleetThroughput_passengers_hr;
        T.AvgWaitTime_min(ii) = 0.5 * headway_min;
        T.Road_Speed_kmh(ii) = Road_EV_Design.mean_speed_km_h;
        T.Road_Availability(ii) = Road_EV_Design.availability;
        T.Road_Range_km(ii) = Road_EV_Design.range_km;
        T.Bike_Speed_kmh(ii) = 0; 
        T.Bike_Availability(ii) = 0;
        T.Bike_Range_km(ii) = 0;
        
        % Build Vehicle Spec String 
        specStr = sprintf("C%d, P%d, G%d, M%d, A%d", ...
            design.chassis, design.battery_pack, design.battery_charger, ...
            design.motor, design.autonomy);
        T.VehicleSpecs(ii) = {specStr};
        
    elseif strcmp(archType, 'bike')
        [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);
        
        if ~isValid
            str = sprintf('WARNING: Bike Arch %d (Frame %s, Battery %s) is INVALID. Must replace it. Skipping for now...\n', ...
                ii, bikeDB.frame(design.frame).Name, bikeDB.battery_pack(design.battery_pack).Name);
            warning(str);
            continue
        end
        
        % Fleet Calculations for Bike
        T.Fleet_Size(ii,1) = fleetSize_road + fleetSize_bike;
        T.Fleet_Composition_Road_Vehicles(ii,1) = fleetSize_road;
        T.Fleet_Composition_Bike_Vehicles(ii,1) = fleetSize_bike;
        T.Fleet_Cost_USD(ii,1) = cost.total_vehicle_cost * fleetSize_bike;
        T.Road_Vehicle_Cost_USD(ii,1) = 0;
        T.Bike_Vehicle_Cost_USD(ii,1) = cost.total_vehicle_cost;
        
        % Performance Metrics for Bike
        passengersPerTrip = Bike_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput = passengersPerTrip / avgTripTime_h; %persons per hour per vehicle
        availableVehicles = fleetSize_bike * Bike_EV_Design.availability;
        fleetThroughput_passengers_hr = availableVehicles * singleVehicleThroughput; %persons per hour for the fleet
        fleetTripsPerHr = fleetThroughput_passengers_hr / passengersPerTrip; %compute trips based on persons per hour throughput
        headway_min = 60 / fleetTripsPerHr; %inverse of frequency - number of vehicles per hour [cite: 209]
        
        T.FleetThroughput_pass_hr(ii) = fleetThroughput_passengers_hr;
        T.AvgWaitTime_min(ii) = 0.5 * headway_min;
        T.Road_Speed_kmh(ii) = 0;
        T.Road_Availability(ii) = 0;
        T.Road_Range_km(ii) = 0;
        T.Bike_Speed_kmh(ii) = Bike_EV_Design.mean_speed_km_h;
        T.Bike_Availability(ii) = Bike_EV_Design.availability;
        T.Bike_Range_km(ii) = Bike_EV_Design.range_km;
        
        % Build Vehicle Spec String 
        specStr = sprintf("B%d, E%d, G%d, K%d", ...
            design.frame, design.battery_pack, design.battery_charger, design.motor);
        T.VehicleSpecs(ii) = {specStr};
        
    elseif strcmp(archType, 'mixed')
        [Road_EV_Design, roadVehicle_cost, road_isValid] = calculateRoadVehicle(design.road, roadDB);
        [Bike_EV_Design, bikeVehicle_cost, bike_isValid] = calculateBikeVehicle(design.bike, bikeDB);
        
        if ~road_isValid || ~bike_isValid
            str = sprintf('WARNING: Mixed Arch %d has an invalid component. Must replace it. Skipping for now...\n', ii);
            warning(str);
            continue
        end
        
        % Fleet Calculations for Mixed 
        T.Fleet_Size(ii,1) = fleetSize_road + fleetSize_bike;
        T.Fleet_Composition_Road_Vehicles(ii,1) = fleetSize_road;
        T.Fleet_Composition_Bike_Vehicles(ii,1) = fleetSize_bike;
        
        fleetCost_road = roadVehicle_cost.total_vehicle_cost * fleetSize_road;
        fleetCost_bike = bikeVehicle_cost.total_vehicle_cost * fleetSize_bike;
        T.Fleet_Cost_USD(ii,1) = fleetCost_road + fleetCost_bike;
        
        T.Road_Vehicle_Cost_USD(ii,1) = roadVehicle_cost.total_vehicle_cost;
        T.Bike_Vehicle_Cost_USD(ii,1) = bikeVehicle_cost.total_vehicle_cost;
        
        % Performance (Road) 
        passengersPerTrip_road = Road_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput_road = passengersPerTrip_road / avgTripTime_h;
        availableVehicles_road = fleetSize_road * Road_EV_Design.availability;
        fleetThroughput_road = availableVehicles_road * singleVehicleThroughput_road;
        
        % Performance (Bike)
        passengersPerTrip_bike = Bike_EV_Design.Pax * load_factor_per_trip;
        singleVehicleThroughput_bike = passengersPerTrip_bike / avgTripTime_h;
        availableVehicles_bike = fleetSize_bike * Bike_EV_Design.availability;
        fleetThroughput_bike = availableVehicles_bike * singleVehicleThroughput_bike;
        
        % Performance (Total) 
        totalFleetThroughput = fleetThroughput_road + fleetThroughput_bike;
        totalFleetTripsPerHr = (fleetThroughput_road / passengersPerTrip_road) + ...
                               (fleetThroughput_bike / passengersPerTrip_bike);
        headway_min = 60 / totalFleetTripsPerHr; %inverse of frequency - number of vehicles per hour 
        
        T.FleetThroughput_pass_hr(ii) = totalFleetThroughput;
        T.AvgWaitTime_min(ii) = 0.5 * headway_min;
        
        % Show both road and bike specs 
        T.Road_Speed_kmh(ii) = Road_EV_Design.mean_speed_km_h;
        T.Road_Availability(ii) = Road_EV_Design.availability;
        T.Road_Range_km(ii) = Road_EV_Design.range_km;
        T.Bike_Speed_kmh(ii) = Bike_EV_Design.mean_speed_km_h;
        T.Bike_Availability(ii) = Bike_EV_Design.availability;
        T.Bike_Range_km(ii) = Bike_EV_Design.range_km;
        
        % Build Vehicle Spec String 
        specStr_road = sprintf("Road: (C%d, P%d, G%d, M%d, A%d)", ...
            design.road.chassis, design.road.battery_pack, design.road.battery_charger, ...
            design.road.motor, design.road.autonomy);
        specStr_bike = sprintf("Bike: (B%d, E%d, G%d, K%d)", ...
            design.bike.frame, design.bike.battery_pack, design.bike.battery_charger, ...
            design.bike.motor);
        T.VehicleSpecs(ii) = {sprintf("%s; %s", specStr_road, specStr_bike)};
        
    else % Error handling
        str = sprintf('Design %d does not have a compatable or defined archType. Must be road, bike, or mixed.',ii);
        error(str)
    end
end %end model execution


%% -- Output Table to an Excel file -- %%
% Prepare variable names for Excel 
varNames = T.Properties.VariableNames;
% Replace all underscores with spaces (e.g., "Fleet Cost USD")
varNames = strrep(varNames, '_', ' ');
T.Properties.VariableNames = varNames;

targetDir = fullfile('..', '..', 'OS 4'); % Goes up two levels, looks for "OS 4"
outputFileName = 'Task_2_Analysis.xlsx';
fullOutputPath = fullfile(targetDir, outputFileName);
if ~isfolder(targetDir)
    fprintf('Directory "%s" not found. Creating it...\n', targetDir);
    mkdir(targetDir); 
end
writetable(T, fullOutputPath);
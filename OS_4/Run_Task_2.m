%% -- EM.411 OS 4 Task 2 -- %%
% This script models 5 unique fleet architectures and generates the
% data table required for the Task 2 deliverable
% https://github.com/Joel-Pederson/EM_411_repo

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
fleetSizes{1} = 25; % Our assumption for fleet size

% Option 2 - TBD

% Option 3 - All Bike Fleet

% Option 4 - TBD

% % Option 5 - Mixed Fleet (Road + Bike)
% designs{5}.road = designs{1}; % Use the TBD design
% designs{5}.bike = designs{4}; % Use the TBD design
% designs{5}.archTypes = 'mixed';
% fleetSizes{5}.road = 15; % Assumption: 15 road vehicles
% fleetSizes{5}.bike = 50; % Assumption: 50 bikes

%% -- Execute Model -- %%
for ii = 1:length(designs)
    design = designs{ii};
    archType = archTypes{ii};
    fleetSize = fleetSizes{ii};

    if strcmp(archType, 'road')
        [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);
        if ~isValid % Check if the current state is valid; if not, skip to the next iteration
            continue
        end
        %Fleet calculations
        

    elseif strcmp(archType, 'bike')
        [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);
        if ~isValid
            continue
        end

    elseif strcmp(archType, 'mixed')
        %Calculate Road component
        [Road_EV_Design, roadVehicle_cost, road_isValid] = calculateRoadVehicle(design, roadDB);
        %Calculate Bike component
        [Bike_EV_Design, bikeVehicle_cost, bike_isValid] = calculateBikeVehicle(design, bikeDB);

        if ~road_isValid || ~bike_isValid
            isValid = 0;
            continue
        end
    else % Error handling for incompatible or undefined architecture type - alert user
        str = sprintf('Design %d does not have a compatable or defined archType. Must be road, bike, or mixed.',ii);
        error(str)
    end
end %end model execution

% EV_design.total_fleet_cost =
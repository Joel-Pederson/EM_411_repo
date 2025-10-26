%% -- EM.411 OS 4 Task 2 -- %%
% This script models 5 unique fleet architectures and generates the
% data table required for the Task 2 deliverable
clear all;

%% -- Load Database -- %%
[roadDB, bikeDB] = load_DB();

%% -- 2. Define Fleet-Level Model Assumptions -- %%


%% -- 3. Define Unique Architectures -- %%

designs = {};     % Stores the component indices for each arch
archTypes = {};   % Stores the type: 'road' or 'bike'
fleetSizes = [];  % Stores the fleet size assumption for each arch

% Option 1 - Ultra Minimal Road Vehicle 
% 'design' must be a struct containing the index for EACH component.
design{1}.chassis = 1;         % C1 (2 pax)
design{1}.battery_pack = 1;    % P1 (50 kWh)
design{1}.battery_charger = 1; % G1 (10 kW)
design{1}.motor = 1;           % M1 (50 kW)
design{1}.autonomy = 2;        % A4 (Level 4)
archTypes{1} = 'road';
fleetSizes(1) = 25; % Our assumption for fleet size

% Option 2 - TBD

% Option 3 - All Bike Fleet

% Option 4 - TBD

% Option 5 - TBD

[Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB);
[Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB);

% EV_design.total_fleet_cost = 
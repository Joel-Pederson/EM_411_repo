%% -- EM.411 OS 4 Task 2 -- %%

[roadDB, bikeDB] = load_DB();

% -- 2. Define a Test Architecture --
% 'design' must be a struct containing the index for EACH component.
% Let's pick a simple "all 1s" architecture for our first test:
test_design.chassis = 1;         % C1 (2 pax)
test_design.battery_pack = 1;  % P1 (50 kWh)
test_design.battery_charger = 1; % G1 (10 kW)
test_design.motor = 1;           % M1 (50 kW)
test_design.autonomy = 2;        % A4 (Level 4) - Let's pick 2 for variety

[Road_EV_Design, cost, isValid] = calculateRoadVehicle(test_design, roadDB);
[Bike_EV_Design, cost, isValid] = calculateBikeVehicle(test_design, bikeDB);

% EV_design.total_fleet_cost = 
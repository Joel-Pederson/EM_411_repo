function [Road_EV_Design, cost, isValid] = calculateRoadVehicle(design, roadDB)
% Calculates performance, cost, and validity for a single road vehicle architecture.
% Inputs:
% 'design' is a struct of indices, e.g., design.chassis = 1, design.battery_pack = 2, ...'roadDB' is the database from load_DB()
% Outputs:
% 'Road_EV_Design' - struct of performance metrics (range, speed, availability, etc.)
% 'cost' - struct of cost metrics (vehicle cost)
% 'isValid' - boolean flag


%% -- 1. Look up components -- %%
% Get the component structs from roadDB using the indices in 'design'

chassis = roadDB.chassis(design.chassis);
battery = roadDB.battery_pack(design.battery_pack);
charger = roadDB.battery_charger(design.battery_charger);
motor = roadDB.motor(design.motor);
autonomy = roadDB.autonomy(design.autonomy);

%% -- 2. Check Constraints -- %%
% Check the battery pack weight constraint from Appendix C
% "The battery pack weight shall be no greater than 1/3 of the chassis weight"
% Also note that "Only one battery pack may be used in a given architecture"
if battery.Weight_kg > (chassis.Weight_kg / 3)
    isValid = false;
    Road_EV_Design = []; % Return empty results
    cost = [];
    return; % Exit the function early
else
    isValid = true;
end

%% -- 3. Implement Appendix B Equations  -- %%
% All equations taken from Appendix B unless otherwise noted
speed_limit_mph = 25; % miles per hour, taken from: https://www.cambridgema.gov/streetsandtransportation/policiesordinancesandplans/visionzero/speedlimitsincambridge
passenger.mean_weight_kg = 100;
Road_EV_Design.mean_load_factor_per_trip = 0.75; %dimensionless
passenger.group_weight_kg = chassis.Pax * Road_EV_Design.mean_load_factor_per_trip * passenger.mean_weight_kg; %compute the total weight of all passengers. Not specifically given as an equation in App. B
Road_EV_Design.total_vehicle_weight_kg = chassis.Weight_kg + battery.Weight_kg + charger.Weight_kg + motor.Weight_kg + passenger.group_weight_kg + autonomy.Weight_kg;
Road_EV_Design.total_vehicle_cost = chassis.Cost + battery.Cost + charger.Cost + motor.Cost + autonomy.Cost;
cost.total_vehicle_cost = Road_EV_Design.total_vehicle_cost;
Road_EV_Design.battery_charge_time_h = battery.Capacity_kWh / charger.Power_kW;
Road_EV_Design.power_consumption_Wh_km = chassis.NominalPower_Wh_km + 0.1 * (Road_EV_Design.total_vehicle_weight_kg - chassis.Weight_kg) + autonomy.AddedPower_Wh_km;
Road_EV_Design.range_km = (battery.Capacity_kWh * 1000) / Road_EV_Design.power_consumption_Wh_km; %have to convert capacity's kilo-watt hours to watt hours
Road_EV_Design.mean_speed_km_h = 700 * (motor.Power_kW / Road_EV_Design.total_vehicle_weight_kg);%Note: 700 is a constant of proportionality that converts this ratio into an average speed. Provided by assignment instructions
if Road_EV_Design.mean_speed_km_h > mphToKmph(speed_limit_mph) %if EV_design.mean_speed exceeds legal speed limit, set mean_speed_km_h to speed limit
    Road_EV_Design.mean_speed_km_h = mphToKmph(speed_limit_mph);
end
Road_EV_Design.up_time_h = Road_EV_Design.range_km / Road_EV_Design.mean_speed_km_h;
Road_EV_Design.down_time_h = Road_EV_Design.battery_charge_time_h + 0.25;
Road_EV_Design.availability = Road_EV_Design.up_time_h / (Road_EV_Design.up_time_h + Road_EV_Design.down_time_h); %dimensionless
Road_EV_Design.benchmark_availability = 0.75;
Road_EV_Design.Pax = chassis.Pax;
end

%% -- Subfunctions -- %%
function kmph = mphToKmph(mph)
    kmph = mph * 1.60934; % Conversion factor
end
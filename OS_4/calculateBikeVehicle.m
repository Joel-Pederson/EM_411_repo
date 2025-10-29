function [Bike_EV_Design, cost, isValid] = calculateBikeVehicle(design, bikeDB)
% Calculates performance, cost, and validity for a single E-Bike architecture
% Inputs:
% 'design' is a struct of indices, e.g., design.frame = 1, design.battery_pack = 1, 'bikeDB' is the database from load_DB()
% Outputs:
% 'Bike_EV_Design' - struct of performance metrics (range, speed, availability, etc.)
% 'cost' - struct of cost metrics (vehicle cost)
% 'isValid' - boolean flag

%% -- 1. Look up components -- %%
% Get the component structs from roadDB using the indices in 'design'

frame = bikeDB.frame(design.frame);
battery = bikeDB.battery_pack(design.battery_pack);
charger = bikeDB.battery_charger(design.battery_charger);
motor = bikeDB.motor(design.motor);

%% -- 2. Check Constraints -- %%
% Check the battery pack weight constraint from Appendix D
% "The battery pack weight shall be no greater than 1/2 of the frame weight"
% Also note that "Only one battery pack may be used in a given architecture"
if battery.Weight_kg > (frame.Weight_kg / 2)
    isValid = false;
    Bike_EV_Design = []; % Return empty results
    cost = [];
    return; % Exit the function early
else
    isValid = true;
end

%% -- 3. Implement Appendix B Equations  -- %%
% All equations taken from Appendix B unless otherwise noted
speed_limit_mph = 25; % miles per hour, taken from: https://www.cambridgema.gov/streetsandtransportation/policiesordinancesandplans/visionzero/speedlimitsincambridge
passenger.mean_weight_kg = 100;
Bike_EV_Design.mean_load_factor_per_trip = 0.75; %dimensionless
passenger.group_weight_kg = frame.Pax * Bike_EV_Design.mean_load_factor_per_trip * passenger.mean_weight_kg; %compute the total weight of all passengers. Not specifically given as an equation in App. B
Bike_EV_Design.total_vehicle_weight_kg = frame.Weight_kg + battery.Weight_kg + charger.Weight_kg + motor.Weight_kg + passenger.group_weight_kg;
Bike_EV_Design.total_vehicle_cost = frame.Cost + battery.Cost + charger.Cost + motor.Cost;
cost.total_vehicle_cost = Bike_EV_Design.total_vehicle_cost;
Bike_EV_Design.battery_charge_time_h = battery.Capacity_kWh / charger.Power_kW;
Bike_EV_Design.power_consumption_Wh_km = frame.NominalPower_Wh_km; %see appendix D note under bike frame
Bike_EV_Design.range_km = (battery.Capacity_kWh * 1000) / Bike_EV_Design.power_consumption_Wh_km; %have to convert capacity's kilo-watt hours to watt hours
Bike_EV_Design.mean_speed_km_h = 4861 * (motor.Power_kW / Bike_EV_Design.total_vehicle_weight_kg);%Note: 4500 is a constant of proportionality that converts this ratio into an average speed.
                                                                                                  %See documentation for rationale behind value of 4500
if Bike_EV_Design.mean_speed_km_h > mphToKmph(speed_limit_mph) %if EV_design.mean_speed exceeds legal speed limit, set mean_speed_km_h to speed limit
    Bike_EV_Design.mean_speed_km_h = mphToKmph(speed_limit_mph);
end
Bike_EV_Design.up_time_h = Bike_EV_Design.range_km / Bike_EV_Design.mean_speed_km_h;
Bike_EV_Design.down_time_h = Bike_EV_Design.battery_charge_time_h + 0.25;
Bike_EV_Design.availability = Bike_EV_Design.up_time_h / (Bike_EV_Design.up_time_h + Bike_EV_Design.down_time_h); %dimensionless
Bike_EV_Design.benchmark_availability = 0.75;
Bike_EV_Design.Pax = frame.Pax;
%% -- Subfunctions -- %%
    function kmph = mphToKmph(mph)
        kmph = mph * 1.60934; % Conversion factor
    end

end
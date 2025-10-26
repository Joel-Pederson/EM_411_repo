function [roadDB, bikeDB] = load_DB()
% Creates and returns structs containing all component data from Appendices
% C and D since the data was not provided in a parsable form
% Inputs: none
% Outputs: database values for road vehicle and bike
% Note: all 'cost' values are in USD
%% -- Road Vehicle Database (Appendix C) -- %%
% Battery Pack 
roadDB.battery_pack(1) = struct('Name', 'P1', 'Capacity_kWh', 50, 'Cost', 6000, 'Weight_kg', 110);
roadDB.battery_pack(2) = struct('Name', 'P2', 'Capacity_kWh', 100, 'Cost', 11000, 'Weight_kg', 220);
roadDB.battery_pack(3) = struct('Name', 'P3', 'Capacity_kWh', 150, 'Cost', 15000, 'Weight_kg', 340);
roadDB.battery_pack(4) = struct('Name', 'P4', 'Capacity_kWh', 190, 'Cost', 19000, 'Weight_kg', 450);
roadDB.battery_pack(5) = struct('Name', 'P5', 'Capacity_kWh', 250, 'Cost', 25000, 'Weight_kg', 570);
roadDB.battery_pack(6) = struct('Name', 'P6', 'Capacity_kWh', 310, 'Cost', 30000, 'Weight_kg', 680);
roadDB.battery_pack(7) = struct('Name', 'P7', 'Capacity_kWh', 600, 'Cost', 57000, 'Weight_kg', 1400);

% Chassis
roadDB.chassis(1) = struct('Name', 'C1', 'Pax', 2, 'Weight_kg', 1350, 'Cost', 12000, 'NominalPower_Wh_km', 140); %Pax is a (apparently) common abbreviation for passengers in the transportation field
roadDB.chassis(2) = struct('Name', 'C2', 'Pax', 4, 'Weight_kg', 1600, 'Cost', 17000, 'NominalPower_Wh_km', 135);
roadDB.chassis(3) = struct('Name', 'C3', 'Pax', 6, 'Weight_kg', 1800, 'Cost', 21000, 'NominalPower_Wh_km', 145);
roadDB.chassis(4) = struct('Name', 'C4', 'Pax', 8, 'Weight_kg', 2000, 'Cost', 29000, 'NominalPower_Wh_km', 150);
roadDB.chassis(5) = struct('Name', 'C5', 'Pax', 10, 'Weight_kg', 2200, 'Cost', 31000, 'NominalPower_Wh_km', 160);
roadDB.chassis(6) = struct('Name', 'C6', 'Pax', 16, 'Weight_kg', 2500, 'Cost', 33000, 'NominalPower_Wh_km', 165);
roadDB.chassis(7) = struct('Name', 'C7', 'Pax', 20, 'Weight_kg', 4000, 'Cost', 38000, 'NominalPower_Wh_km', 180);
roadDB.chassis(8) = struct('Name', 'C8', 'Pax', 30, 'Weight_kg', 7000, 'Cost', 47000, 'NominalPower_Wh_km', 210);

% Battery charger
roadDB.battery_charger(1) = struct('Name','G1','Power_kW', 10, 'Cost',1000, 'Weight_kg', 1);
roadDB.battery_charger(2) = struct('Name','G2','Power_kW', 20, 'Cost',2500, 'Weight_kg', 1.8);
roadDB.battery_charger(3) = struct('Name','G3','Power_kW', 60, 'Cost',7000, 'Weight_kg', 5);

% Motor and inverter module
roadDB.motor(1) = struct('Name', 'M1', 'Weight_kg', 35, 'Power_kW', 50, 'Cost', 4200);
roadDB.motor(2) = struct('Name', 'M2', 'Weight_kg', 80, 'Power_kW', 100, 'Cost', 9800);
roadDB.motor(3) = struct('Name', 'M3', 'Weight_kg', 110, 'Power_kW', 210, 'Cost', 13650);
roadDB.motor(4) = struct('Name', 'M4', 'Weight_kg', 200, 'Power_kW', 350, 'Cost', 20600);

% Autonomous system
roadDB.autonomy(1) = struct('Name', 'A3', 'Level', 3, 'Weight_kg', 30, 'AddedPower_Wh_km', 1.5, 'Cost', 15000);
roadDB.autonomy(2) = struct('Name', 'A4', 'Level', 4, 'Weight_kg', 60, 'AddedPower_Wh_km', 2.5, 'Cost', 35000);
roadDB.autonomy(3) = struct('Name', 'A5', 'Level', 5, 'Weight_kg', 120, 'AddedPower_Wh_km', 5.0, 'Cost', 60000);

%% --- Electric Bike Database (Appendix D) ---
% Bike Battery Pack
bikeDB.battery_pack(1) = struct('Name', 'E1', 'Capacity_kWh', 0.5, 'Cost', 600, 'Weight_kg', 5);
bikeDB.battery_pack(2) = struct('Name', 'E2', 'Capacity_kWh', 1.5, 'Cost', 1500, 'Weight_kg', 11);
bikeDB.battery_pack(3) = struct('Name', 'E3', 'Capacity_kWh', 3.0, 'Cost', 2600, 'Weight_kg', 17);

% Bike Frame
bikeDB.frame(1) = struct('Name', 'B1', 'Pax', 1, 'Weight_kg', 20, 'Cost', 2000, 'NominalPower_Wh_km', 30);
bikeDB.frame(2) = struct('Name', 'B2', 'Pax', 1, 'Weight_kg', 17, 'Cost', 3000, 'NominalPower_Wh_km', 25);
bikeDB.frame(3) = struct('Name', 'B3', 'Pax', 2, 'Weight_kg', 35, 'Cost', 3500, 'NominalPower_Wh_km', 40);

% Battery Charger
bikeDB.battery_charger(1) = struct('Name', 'G1', 'Power_kW', 0.2, 'Cost', 300, 'Weight_kg', 0.5);
bikeDB.battery_charger(2) = struct('Name', 'G2', 'Power_kW', 0.6, 'Cost', 500, 'Weight_kg', 1.2);

% Bike Motor and Inverter Module
bikeDB.motor(1) = struct('Name', 'K1', 'Weight_kg', 5, 'Power_kW', 0.35, 'Cost', 300);
bikeDB.motor(2) = struct('Name', 'K2', 'Weight_kg', 4, 'Power_kW', 0.5, 'Cost', 400);
bikeDB.motor(3) = struct('Name', 'K3', 'Weight_kg', 7, 'Power_kW', 1.5, 'Cost', 600);

end
function [perf, cost, isValid] = calculateRoadVehicle(design, roadDB)
% Calculates performance, cost, and validity for a single road vehicle architecture.
% Inputs:
% 'design' is a struct of indices, e.g., design.chassis = 1, design.battery_pack = 2, ...
% 'roadDB' is the database from load_DB()
% Outputs: 

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
        perf = []; % Return empty results
        cost = [];
        return; % Exit the function early
    else
        isValid = true;
    end    

    %% -- 3. Implement Appendix B Equations [cite: 161-176] -- %%
    % Let's start with Total Vehicle Cost and Total Vehicle Weight
    
end
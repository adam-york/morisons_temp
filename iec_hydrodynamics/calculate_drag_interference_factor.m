function drag_interference_factor = calculate_drag_interference_factor(fitting_function, potential_flow_factor, attachment_wave_angle)
    %% Eq C.21, IEC 61400-3-1 2019
    blockage_factor = calculate_drag_blockage_factor(fitting_function);
    attachment_wave_angle_rad = deg2rad(attachment_wave_angle);
    drag_interference_factor = (1 + abs(cos(2 * attachment_wave_angle_rad) .* (blockage_factor .* fitting_function - 1))) .* potential_flow_factor .^2;
end

function blockage_factor = calculate_drag_blockage_factor(fitting_function)
    %% Eq C.22, IEC 61400-3-1 2019
    blockage_factor = ones(size(fitting_function));  %% default to 1 (if fitting function is > 50)

    idx = fitting_function < 0.4;
    blockage_factor(idx) = ...
      -5.9309 .* fitting_function(idx).^3 ...
      + 9.9604 .* fitting_function(idx).^2 ...
      - 5.4055 .* fitting_function(idx) ...
      + 2;

    idx = fitting_function >= 0.4 & fitting_function < 50;
    blockage_factor(idx) = -0.01923 .* fitting_function(idx) + 1.0596;
end

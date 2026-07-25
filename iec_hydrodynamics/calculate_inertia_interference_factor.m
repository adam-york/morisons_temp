function inertia_interference_factor = calculate_inertia_interference_factor(fitting_function, potential_flow_factor, attachment_wave_angle)
  %% Eq C.24, IEC 61400-3-1 2019
  blockage_factor = calculate_inertia_blockage_factor(fitting_function);
  attachment_wave_angle_rad = deg2rad(attachment_wave_angle);
  inertia_interference_factor = (1 + abs(cos(2 .* attachment_wave_angle_rad) .* (blockage_factor .* fitting_function - 1)) ) .* potential_flow_factor;
end

function blockage_factor = calculate_inertia_blockage_factor(fitting_function)
  %% Eq C.25, IEC 61400-3-1 2019
  blockage_factor = 1 + ( 1 + 10 .* fitting_function) .^ (-1);
end

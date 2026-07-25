function potential_flow_factor = calculate_potential_flow_factor(main_od, centre_to_centre_distance, attachment_wave_angle)
  %% See Eq C.19, IEC 61400-3-1 2019
  attachment_wave_angle_rad = deg2rad(attachment_wave_angle);
  potential_flow_factor = 1 - (2 .* centre_to_centre_distance ./ main_od).^(-2) .* cos (2 .* attachment_wave_angle_rad);
end

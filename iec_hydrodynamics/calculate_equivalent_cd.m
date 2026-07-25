function equivalent_cd = calculate_equivalent_cd(main_od, attachment_od, centre_to_centre_distance, attachment_wave_angle, cd_nominal, mg_thickness, wave_spreading_factor)
  %% Eq C.18, IEC 61400-3-1 2019
  %% Cdeq of the attachments only. I.e. the first term for the monopile is ignored
  face_to_face_distance = centre_to_centre_distance - main_od ./ 2 - attachment_od ./ 2;
  potential_flow_factor = calculate_potential_flow_factor(main_od, centre_to_centre_distance, attachment_wave_angle);
  fitting_function = calculate_fitting_function(main_od, attachment_od, face_to_face_distance);
  drag_interference_factor = calculate_drag_interference_factor(fitting_function, potential_flow_factor, attachment_wave_angle);
  attachment_mg_od = attachment_od + 2 .* mg_thickness;
  equivalent_cds = wave_spreading_factor .^2 * (attachment_mg_od ./ main_od .* cd_nominal .* drag_interference_factor);
  equivalent_cd = sum(equivalent_cds);
end

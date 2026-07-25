function equivalent_cm = calculate_equivalent_cm(main_od, attachment_od, centre_to_centre_distance, attachment_wave_angle, cm_nominal, mg_thickness, wave_spreading_factor)
  %% Eq C.19, IEC 61400-3-1 2019
  %% Cmeq of the attachments only. I.e. the first term for the monopile is ignored
  face_to_face_distance = centre_to_centre_distance - main_od ./ 2 - attachment_od ./ 2;
  potential_flow_factor = calculate_potential_flow_factor(main_od, centre_to_centre_distance, attachment_wave_angle);
  fitting_function = calculate_fitting_function(main_od, attachment_od, face_to_face_distance);
  inertia_interference_factor = calculate_inertia_interference_factor(fitting_function, potential_flow_factor, attachment_wave_angle);
  attachment_mg_od = attachment_od + 2 .* mg_thickness;
  equivalent_cms = wave_spreading_factor .* (1 +(cm_nominal - 1) .* inertia_interference_factor) .* (attachment_mg_od ./ main_od).^2;
  equivalent_cm = sum(equivalent_cms);
end

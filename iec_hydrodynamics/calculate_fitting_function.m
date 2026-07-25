function fitting_function = calculate_fitting_function(main_od, attachment_od, face_to_face_distance)
  %% See Eq C.21, IEC 61400-3-1 2019
  fitting_function = face_to_face_distance ./ attachment_od .* 0.5 .^(attachment_od ./ main_od);
end

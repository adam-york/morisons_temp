function [additional_thickness, cd_d] = calculate_equivalent_hydro_properties(main_od, mg_thk, main_cm, main_cd, attachment_cms, attachment_cds)
  % Calculates an equivalent additional thickness for a single member to account for the attachment_cms. Calculates Cd*OD value to account for the attachment_cds
  additional_thickness = calculate_equivalent_additional_thickness(main_od, mg_thk, main_cm, attachment_cms);
  cd_d = calculate_cd_d(main_od, main_cd, attachment_cds);
end


function equivalent_additional_thickness = calculate_equivalent_additional_thickness(main_od, mg_thk, main_cm, attachment_cms)
  main_od_mg = main_od + 2 * mg_thk;
  total_cm = main_cm+ sum(attachment_cms);
  
  %% Inertial force is proportional to total Cm and cross-secitonal area (i.e. diameter^2) 
  equivalent_od = main_od_mg * (total_cm / main_cm) ^ 0.5;
  equivalent_additional_thickness = (equivalent_od - main_od_mg) / 2;  
end


function cd_d = calculate_cd_d(main_od, main_cd, attachment_cds)
  total_cd = main_cd + sum(attachment_cds);  %% associated with main_od
  cd_d = total_cd * main_od;
end
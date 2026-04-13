function id_rms_out = calcular_id_dinamica(te_val, rpm_val, v_bus_val, t_wind, interp_id)
% CALCULAR_ID_DINAMICA - Model Empíric d'Alta Fidelitat (DOE 5)
% Calcula la injecció de corrent Id basada en regressió polinòmica de dades reals
% de Motorland, capturant efectes tèrmics no lineals i saturació MTPV.

    % Valor base de la LUT (Excel)
    id_rms_base = interp_id(te_val, rpm_val); 
    
    % Activem el model dinàmic només sota càrrega efectiva
    if te_val > 5 && rpm_val > 500
        % Normalització de factors (centrat en 126V i 25ºC)
        dV = min(v_bus_val - 126.0, 0.0); 
        dT = max(t_wind - 25.0, 0.0);
        sat_r = (min(rpm_val, 5000.0)/5000.0);
        sat_t = (te_val/126.0);
        
        % POLINOMI COMPLEX D'ALT ORDRE (Error global ~20A)
        % Inclou termes quadràtics de temperatura i creuats Termo-Elèctrics
        id_mod = id_rms_base - 10.9686 * dV ...
                 + 21.2685 * (dV * sat_r) ...
                 - 0.1510 * dT ...
                 + 0.0507 * (dT.^2) ...
                 + 0.0011 * (dV * (dT.^2)) ...
                 - 60.9290 * (sat_t^2) ...
                 - 109.0508 * (sat_r^2) ...
                 + 157.1269;
                 
        % LÍMIT INFERIOR FÍSIC (Topall de firmware XION)
        id_mod = max(id_mod, -530.0);
        
        % La Id sempre ha de ser negativa o zero (flux destructiu)
        id_rms_out = min(id_mod, 0); 
    else
        % Fora de rang de treball, usem la LUT pura
        id_rms_out = id_rms_base;
    end
end

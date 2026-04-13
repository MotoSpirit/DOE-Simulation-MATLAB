function [id_final, iq_final, te_lim] = limitar_corriente_y_tension(te_ref, rpm, i_max, v_bus, t_wind, interp_id, interp_iq, max_te, max_rpm)
% LIMITAR_CORRIENTE_Y_TENSION - LIMITADOR DE PARELL MULTI-FACTOR (DOE 5)
% Ajusta el parell motor demanat per respectar els límits de corrent (RMS) de l'inversor
% i les restriccions de voltatge (MTPV) considerant la temperatura i el bus DC.

    % 1. Clipping de seguretat: només positius i RPM dins rang
    te_ref = max(te_ref, 0.0);             % No parell negatiu
    rpm    = min(max(rpm, 0.0), max_rpm);  % RPM dins de la LUT

    % 2. Avaluar punt d'operació inicial
    % Nota: La LUT de Iq es clipa a max_te per evitar extrapolació
    id_test = calcular_id_dinamica(te_ref, rpm, v_bus, t_wind, interp_id);
    iq_test = interp_iq(min(te_ref, max_te), rpm); 
    
    i_mag = sqrt(id_test^2 + iq_test^2);
    
    % Si estem dins del límit de corrent, retornem el valor nominal
    if i_mag <= i_max
        id_final = id_test;
        iq_final = iq_test;
        te_lim = te_ref;
        return;
    end
    
    % 3. Búsqueda Binaria de Parell (si se superen els 610A)
    te_alto = te_ref;
    te_bajo = 0.0;
    
    for k = 1:12 % 12 iteracions per precisió absoluta
        te_mitad = (te_alto + te_bajo) / 2.0;
        
        id_test    = calcular_id_dinamica(te_mitad, rpm, v_bus, t_wind, interp_id);
        iq_test    = interp_iq(min(te_mitad, max_te), rpm);
        i_mag_test = sqrt(id_test^2 + iq_test^2);
        
        if i_mag_test > i_max
            te_alto = te_mitad;
        else
            te_bajo = te_mitad;
        end
    end
    
    te_lim   = te_bajo;
    id_final = calcular_id_dinamica(te_lim, rpm, v_bus, t_wind, interp_id);
    iq_final = interp_iq(min(te_lim, max_te), rpm);
end

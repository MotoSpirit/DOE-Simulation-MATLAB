function [rendiment_motor, rendiment_inversor] = calcular_rendiment(rpm, parell)
    % CALCULAR_RENDIMENT Calcula el rendiment del motor i l'inversor donat
    % el parell (Nm) i les revolucions (RPM).
    %
    % Ús:
    %   [rend, rend_inv] = calcular_rendiment(3000, 50)
    %
    % Inputs:
    %   - rpm: Revolucions per minut (pot ser un vector o matriu d'inputs)
    %   - parell: Parell en Nm (mateixa dimensió que rpm)
    %
    % Outputs:
    %   - rendiment_motor: Rendiment del motor (%) per als punts demanats
    %   - rendiment_inversor: Rendiment de l'inversor (%) per als punts demanats
    
    % Obtenir el directori on es troba aquest script
    func_dir = fileparts(mfilename('fullpath'));
    excel_path = fullfile(func_dir, 'EffInversoriMotor.xlsx');

    % Verificar que l'arxiu existeix
    if ~isfile(excel_path)
        error('Arxiu %s no trobat. Comproveu la ruta.', excel_path);
    end

    % Llegir les dades de l'Excel, conservant els noms de les columnes per evitar
    % problemes amb caràcters especials
    opts = detectImportOptions(excel_path);
    if isprop(opts, 'VariableNamingRule')
        opts.VariableNamingRule = 'preserve';
    end
    dades = readtable(excel_path, opts);

    % Obtenir les diferents matrius i vectors segons les columnes d'aquest Excel
    % Format de columnes: 1->Speed_RPM, 2->Torque_Nm, 3->InvEff, 4->EmEff
    speed_data = dades{:, 1};
    torque_data = dades{:, 2};
    inv_eff_data = dades{:, 3};
    mot_eff_data = dades{:, 4};

    % Crear l'objecte interpolador (tipus scatteredInterpolant donat que
    % les dades de laboratori normalment estaran escampades i no en un "grid" perfecte de xarxa)
    % S'utilitza mètode d'interpolació lineal i per als punts fora de les dades el
    % valor més proper (nearest) per evitar errors i extrapolacions boges.
    F_inversor = scatteredInterpolant(speed_data, torque_data, inv_eff_data, 'linear', 'nearest');
    F_motor = scatteredInterpolant(speed_data, torque_data, mot_eff_data, 'linear', 'nearest');

    % Calcular el rendiment per als punts específicament demanats
    rendiment_inversor = F_inversor(rpm, parell);
    rendiment_motor = F_motor(rpm, parell);
end

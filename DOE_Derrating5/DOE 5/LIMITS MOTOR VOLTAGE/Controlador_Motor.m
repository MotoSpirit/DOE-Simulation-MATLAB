% =========================================================================
% 1. CARGA DE DATOS Y PREPARACIÓN DE INTERPOLADORES
% =========================================================================

% --- CARGA TUS EXCELS REALES (LUTs del motor) ---
disp('Cargando mapas de ID e IQ...');

% Utilizamos readmatrix. Para replicar "index_col=0", cogemos las últimas 64x64
raw_id = readmatrix('Mapa_Final_ID.xlsx');
raw_iq = readmatrix('Mapa_Final_IQ.xlsx');

axis_rpm = raw_id(1, 2:end);   % fila 1, columnas 2..65 → [0, 100, 200, ..., 6300]
axis_te  = raw_id(2:end, 1)'; % col 1, filas 2..65   → [0, 2, 4, ..., 126]

% Extraer la cuadrícula 64x64 de datos, omitiendo etiquetas de índices o cabeceras si existen
LUT_Id = raw_id(end-63:end, end-63:end) / sqrt(2);
LUT_Iq = raw_iq(end-63:end, end-63:end) / sqrt(2);

% Crear los interpoladores
[Te_grid, RPM_grid] = ndgrid(axis_te, axis_rpm);
interp_id = griddedInterpolant(Te_grid, RPM_grid, LUT_Id, 'linear', 'linear');
interp_iq = griddedInterpolant(Te_grid, RPM_grid, LUT_Iq, 'linear', 'linear');

% =========================================================================
% 3. PROCESAMIENTO DE TU ARCHIVO Y GRAFICADO (El bloque main va primero en MATLAB)
% =========================================================================
limite_corriente_inversor = 610.0;

disp('Cargando datos de entrada (voltage_RPM_Torque.xlsx)...');
% Se carga como tabla. Si tienes MATLAB reciente 'VariableNamingRule','preserve' evita cambios de formato.
df_inputs = readtable('voltage_RPM_Torque.xlsx');

% Preasignamos memoria para el bucle
num_rows = height(df_inputs);
resultados_id = zeros(num_rows, 1);
resultados_iq = zeros(num_rows, 1);
resultados_te = zeros(num_rows, 1);

disp('Calculando corrientes para cada punto de operación...');

max_te_mapa = axis_te(end);
max_rpm_mapa = axis_rpm(end);

for i = 1:num_rows
    v_bus = df_inputs.Voltaje_V(i);
    rpm = df_inputs.Velocidad_RPM(i);
    te_ref = df_inputs.Torque_Nm(i);
    t_wind_def = 25.0; % Temperatura per defecte per anàlisi de punts d'operació
    
    [id_out, iq_out, te_lim] = limitar_corriente_y_tension( ...
        te_ref, rpm, limite_corriente_inversor, v_bus, t_wind_def, interp_id, interp_iq, max_te_mapa, max_rpm_mapa);
        
    resultados_id(i) = id_out;
    resultados_iq(i) = iq_out;
    resultados_te(i) = te_lim;
end

% Añadir los resultados como nuevas columnas a la tabla
df_inputs.Id_Calculado_A = resultados_id;
df_inputs.Iq_Calculado_A = resultados_iq;
df_inputs.Torque_Limitado_Nm = resultados_te;

disp('Cálculos finalizados. Generando gráfico...');



% =========================================================================
% 2. FUNCIONES LOCALES ALGORÍTMICAS (En MATLAB van al final del script)
% =========================================================================

% Les fòrmules de limitació ara s'utilitzen des dels fitxers standalone 
% calcular_id_dinamica.m i limitar_corriente_y_tension.m al directori actual.

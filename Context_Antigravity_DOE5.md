# 🏍️ SISTEMA DE SIMULACIÓ MOTOSPIRIT (DOE 5)
Aquest document resumeix l'arquitectura, el funcionament i els aprenentatges tècnics recents del simulador de dinàmica i elèctrica per l'estudi paramètric i d'optimització (DOE). Serveix com a punt de partida o "Context" immediat per a un assistent d'Intel·ligència Artificial (Antigravity).

## 🎯 Objectiu del Sistema
L'entorn pretén testejar virtualment el Powertrain d'una moto elèctrica sobre la "Volta_Ideal" (per exemple, Motorland) per optimitzar-ne: configuracions de bateria (S, P, Cel·les), transmissions (Caixa de canvis vs Directa), parameteritzacions de control motor i respostes tèrmiques (Deratings) massivament.

## 🗂️ Fitxers Principals i Arquitectura

### 1. `Script_DOE_5.m` (Orquestrador)
- Conté la Interfície Gràfica (GUI) on s'escullen tots els paràmetres de la simulació.
- Acumula matrius combinatòries iterant per a cada execució (`sim_queue`).
- **Prerequisits de Rendiment:** Per evitar alentir la simulació principal 100x, carrega prèviament a la RAM mapes pesats (com l'Eficiència Motor/Inversor `EffInversoriMotor.xlsx` convertit a variables `scatteredInterpolant`, o els mapes ID/IQ de limitació de Voltatge). I els injecta empaquetats sota la variable genèrica `cond_ini` cap als sub-simuladors.
- S'encarrega d'integrar les mètriques d'energia individuals per volta (càlcul numèric de Consum en `Ah` i `kWh` a través de les voltes 1 a 7) i exportar el llibre excel mestre `Resultats_DOE_5_RPM.xlsx`.

### 2. `FÍSICA/matlabdefinitiu/simulacio_moto_canut.m` (Física Fonamental & Subsistemes)
L'ànima del sistema. Interacciona a un ritme alt de `dt=0.01` segons.
- **Batalla de Modes:** Decideix si la moto actua per "Força Bruta" (`FISICA`) aplicant tot el "Torque" disponible tenint en compte les acceleracions i resistències clàssiques; o bé actua de mode passiu calcant el ritme ideal quan es preveu un revolt iminent (Mode `COPIA`).
- **Bateria Thevenin "Real-Time":** Integra equacions de circuit equivalent (R, C depenent de T i SOC) actualitzant paràmetres tèrmics `f_SOC`, `f_T` i filtrant (EWMA) la potència per evitar disrupcions numèriques brusques al calcular la relació Arrel Quadrada: `discriminant = Voc_pack^2 - 4 * R_pack * P_elec`.
- **Dinàmica de Deratings Tèrmics:** Extreu la limitació progressiva de la temperatura via model radiador M3. Línies d'escalfament constant de "Coppers" i "Irons".

### 3. `Dashboard_DOE_Integrated.m` (Anàlisi Visual)
Aplicatiu post processat que llegeix tot el catàleg compilat de `rmec` produït. Interfície de panells completíssima per verificar solapaments a temps real i estudiar per què una transmissió sobreviu i l'altra es torra massivament.

---

## ⚠️ Lleis de la Física del Model (Aprenentatges Importants i Fixes Recents)

- **El Mite del Corrent Exagerat de la Caixa vs Directa**: Anteriorment, es dividia rígidament la potència del motor pel `rendiment_mecanic` de la cadena/caixa abans de demanar-li l'energia la Bateria (línies ~791 de `simulacio_moto_canut`). **Això s'ha trencat i corregit**. El rendiment mecànic no pot augmentar màgicament els `Ampers` elèctrics de sortida, l'energia elèctrica es decideix **ÚNICAMENT** prelegant l'arxiu d'eficiències del motor `EffInversoriMotor.xlsx`. Qualsevol Antigravity ha de respectar aquesta llei termodinàmica en tot moment.
- **Efecte Avalanche Voltatge ("Sag")**: Moltes diferències "inesperades" de pics de potència o Intensitat s'han derivat literalment de la debilitat del SOC sota estrès sever.  Quan el "Voltaje" col·lapsa sota una petició massiva (60kW), l'Amperatge creix exageradament per compensar-li (`I = P/V`), exacerbant l'estrès sobre thevenin. Si modifiques el pes o escales malament la tracció de la moto i aquesta accelera molt ràpid o s'estanca fora del rang òptim del seu radi, farà "xoc de voltatge".
- Els arrays dinàmics de la llibreria de "Race Laps" `Ah` i `kWh` dins dels arrays globals cal instanciar-los amb prudència. Acostumen a dimensionar-se directament al loop amb condicions de llindar detectades (`lap_actual += 1`).

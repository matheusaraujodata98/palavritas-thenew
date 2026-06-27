-- Calcula a taxa média global de retenção no dia seguinte (Curto Prazo)
SELECT 
    AVG(played_next_day::INT::FLOAT) AS "Retenção Global D1" 
FROM fato_retencao;
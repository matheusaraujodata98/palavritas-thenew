-- Calcula a taxa média global de sobrevivência após 30 dias (Longo Prazo)
SELECT 
    AVG(active_d30::INT::FLOAT) AS "Retenção Global D30" 
FROM fato_retencao;
-- Analisa o impacto da vitória ou derrota na retenção do dia seguinte (D1)
SELECT 
    result AS "Resultado da Partida",
    AVG(played_next_day::INT::FLOAT) AS "Retenção D1"
FROM fato_retencao
GROUP BY result
ORDER BY "Retenção D1" DESC;
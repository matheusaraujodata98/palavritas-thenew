-- Mapeia as 10 palavras com maior taxa de retenção D1 (Mínimo de 100 partidas)
SELECT 
    word AS "Palavra",
    COUNT(*) AS "Volume de Partidas",
    AVG(played_next_day::INT::FLOAT) AS "Retenção D1"
FROM fato_retencao
GROUP BY word
HAVING COUNT(*) > 100
ORDER BY "Retenção D1" DESC
LIMIT 10;
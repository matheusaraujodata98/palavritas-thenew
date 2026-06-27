-- Avalia a sinergia entre o hábito de leitura da newsletter e a retenção de longo prazo (D30)
SELECT 
    CASE 
        WHEN newsletter_open_before_game = TRUE THEN 'Lê antes de jogar'
        WHEN newsletter_open_before_game = FALSE THEN 'Não lê antes'
        ELSE 'Sem Dados'
    END AS "Hábito de Leitura",
    AVG(active_d30::INT::FLOAT) AS "Retenção D30"
FROM fato_retencao
WHERE newsletter_open_before_game IS NOT NULL
GROUP BY newsletter_open_before_game
ORDER BY "Retenção D30" DESC;
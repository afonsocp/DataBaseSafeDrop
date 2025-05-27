-- ========================================
-- 7. CONSULTAS SQL COMPLEXAS (RELATÓRIOS) 
-- ========================================

-- CONSULTA 1: Relatório completo de ocorrências por tipo e usuário
-- Utiliza: JOIN múltiplas tabelas, COUNT, AVG, GROUP BY, HAVING, subquery, ORDER BY
SELECT 
    t.nome AS tipo_ocorrencia,
    u.tipo_usuario,
    COUNT(o.id_ocorrencia) AS total_ocorrencias,
    COUNT(DISTINCT u.id_usuario) AS usuarios_distintos,
    AVG(CASE 
        WHEN o.nivel_risco = 'baixo' THEN 1
        WHEN o.nivel_risco = 'moderado' THEN 2
        WHEN o.nivel_risco = 'alto' THEN 3
    END) AS media_nivel_risco,
    COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 1 END) AS ocorrencias_alto_risco,
    ROUND(COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 1 END) * 100.0 / COUNT(*), 2) AS percentual_alto_risco,
    -- Subquery para calcular média de ocorrências por usuário deste tipo
    (SELECT AVG(sub_count.total)
     FROM (
         SELECT COUNT(*) as total
         FROM ocorrencias o2
         JOIN usuarios u2 ON o2.id_usuario = u2.id_usuario
         WHERE o2.id_tipo = t.id_tipo AND u2.tipo_usuario = u.tipo_usuario
         GROUP BY u2.id_usuario
     ) sub_count
    ) AS media_ocorrencias_por_usuario,
    MIN(o.data_ocorrencia) AS primeira_ocorrencia,
    MAX(o.data_ocorrencia) AS ultima_ocorrencia
FROM 
    tipos_ocorrencia t
JOIN 
    ocorrencias o ON t.id_tipo = o.id_tipo
JOIN 
    usuarios u ON o.id_usuario = u.id_usuario
GROUP BY 
    t.id_tipo, t.nome, u.tipo_usuario
HAVING 
    COUNT(o.id_ocorrencia) >= 1  -- Apenas tipos com pelo menos 1 ocorrência
    AND COUNT(DISTINCT u.id_usuario) >= 1  -- Pelo menos 1 usuário distinto
ORDER BY 
    total_ocorrencias DESC, 
    percentual_alto_risco DESC,
    t.nome;

-- CONSULTA 2: Análise de ocupação e eficiência de abrigos com checkins
-- Utiliza: JOIN múltiplas tabelas, SUM, COUNT, AVG, GROUP BY, HAVING, subquery, ORDER BY
SELECT 
    a.nome AS nome_abrigo,
    a.capacidade_total,
    a.vagas_disponiveis,
    (a.capacidade_total - a.vagas_disponiveis) AS ocupacao_atual,
    ROUND(((a.capacidade_total - a.vagas_disponiveis) * 100.0 / a.capacidade_total), 2) AS taxa_ocupacao,
    COUNT(c.id_checkin) AS total_checkins_historico,
    COUNT(DISTINCT c.id_usuario) AS usuarios_distintos_atendidos,
    COUNT(CASE WHEN c.data_saida IS NULL THEN 1 END) AS checkins_ativos,
    COUNT(CASE WHEN c.data_saida IS NOT NULL THEN 1 END) AS checkins_finalizados,
    -- Média de permanência para checkins finalizados
    AVG(CASE 
        WHEN c.data_saida IS NOT NULL 
        THEN EXTRACT(DAY FROM (c.data_saida - c.data_entrada))
    END) AS media_dias_permanencia,
    -- Subquery: Total de ocorrências próximas (raio de 0.1 grau)
    (SELECT COUNT(*)
     FROM ocorrencias o
     WHERE ABS(o.latitude - (-23.56)) < 0.1  -- Assumindo coordenadas próximas
       AND ABS(o.longitude - (-46.65)) < 0.1
       AND o.data_ocorrencia >= SYSDATE - 30  -- Últimos 30 dias
    ) AS ocorrencias_proximas_30dias,
    -- Distribuição por tipo de usuário
    SUM(CASE WHEN u.tipo_usuario = 'cidadao' THEN 1 ELSE 0 END) AS checkins_cidadaos,
    SUM(CASE WHEN u.tipo_usuario = 'voluntario' THEN 1 ELSE 0 END) AS checkins_voluntarios,
    SUM(CASE WHEN u.tipo_usuario = 'orgao_publico' THEN 1 ELSE 0 END) AS checkins_orgaos_publicos
FROM 
    abrigos a
LEFT JOIN 
    checkins_abrigos c ON a.id_abrigo = c.id_abrigo
LEFT JOIN 
    usuarios u ON c.id_usuario = u.id_usuario
GROUP BY 
    a.id_abrigo, a.nome, a.capacidade_total, a.vagas_disponiveis
HAVING 
    a.capacidade_total > 0  -- Apenas abrigos com capacidade válida
ORDER BY 
    taxa_ocupacao DESC,
    total_checkins_historico DESC,
    usuarios_distintos_atendidos DESC;

-- CONSULTA 3: Relatório de alertas e sua efetividade por fonte e urgência
-- Utiliza: JOIN múltiplas tabelas, COUNT, AVG, GROUP BY, HAVING, subquery, ORDER BY
SELECT 
    al.fonte,
    al.nivel_urgencia,
    COUNT(al.id_alerta) AS total_alertas,
    COUNT(DISTINCT al.id_ocorrencia) AS ocorrencias_distintas_alertadas,
    COUNT(DISTINCT o.id_usuario) AS usuarios_distintos_afetados,
    -- Distribuição por nível de risco das ocorrências relacionadas
    COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 1 END) AS alertas_risco_alto,
    COUNT(CASE WHEN o.nivel_risco = 'moderado' THEN 1 END) AS alertas_risco_moderado,
    COUNT(CASE WHEN o.nivel_risco = 'baixo' THEN 1 END) AS alertas_risco_baixo,
    -- Tempo médio entre ocorrência e alerta
    AVG(EXTRACT(HOUR FROM (al.data_emissao - o.data_ocorrencia))) AS media_horas_resposta,
    -- Subquery: Percentual de ocorrências que geraram alertas
    ROUND(
        (COUNT(DISTINCT al.id_ocorrencia) * 100.0 / 
         (SELECT COUNT(DISTINCT o2.id_ocorrencia) 
          FROM ocorrencias o2 
          WHERE o2.data_ocorrencia >= SYSDATE - 90)  -- Últimos 90 dias
        ), 2
    ) AS percentual_cobertura_alertas,
    -- Distribuição temporal
    COUNT(CASE WHEN al.data_emissao >= SYSDATE - 1 THEN 1 END) AS alertas_ultimas_24h,
    COUNT(CASE WHEN al.data_emissao >= SYSDATE - 7 THEN 1 END) AS alertas_ultima_semana,
    COUNT(CASE WHEN al.data_emissao >= SYSDATE - 30 THEN 1 END) AS alertas_ultimo_mes,
    -- Tipos de ocorrência mais alertados
    (SELECT t.nome 
     FROM tipos_ocorrencia t
     JOIN ocorrencias o3 ON t.id_tipo = o3.id_tipo
     JOIN alertas al3 ON o3.id_ocorrencia = al3.id_ocorrencia
     WHERE al3.fonte = al.fonte AND al3.nivel_urgencia = al.nivel_urgencia
     GROUP BY t.nome
     ORDER BY COUNT(*) DESC
     FETCH FIRST 1 ROW ONLY
    ) AS tipo_ocorrencia_mais_alertado
FROM 
    alertas al
JOIN 
    ocorrencias o ON al.id_ocorrencia = o.id_ocorrencia
JOIN 
    tipos_ocorrencia t ON o.id_tipo = t.id_tipo
JOIN 
    usuarios u ON o.id_usuario = u.id_usuario
GROUP BY 
    al.fonte, al.nivel_urgencia
HAVING 
    COUNT(al.id_alerta) >= 1  -- Pelo menos 1 alerta
    AND AVG(EXTRACT(HOUR FROM (al.data_emissao - o.data_ocorrencia))) IS NOT NULL
ORDER BY 
    al.nivel_urgencia DESC,
    total_alertas DESC,
    media_horas_resposta ASC;

-- CONSULTA 4: Análise geográfica de ocorrências e proximidade com abrigos
-- Utiliza: JOIN múltiplas tabelas, COUNT, AVG, GROUP BY, HAVING, subquery complexa, ORDER BY
SELECT 
    -- Agrupamento por região (arredondamento de coordenadas)
    ROUND(o.latitude, 2) AS regiao_latitude,
    ROUND(o.longitude, 2) AS regiao_longitude,
    COUNT(o.id_ocorrencia) AS total_ocorrencias_regiao,
    COUNT(DISTINCT o.id_tipo) AS tipos_ocorrencia_distintos,
    COUNT(DISTINCT o.id_usuario) AS usuarios_distintos_reportaram,
    -- Distribuição por nível de risco
    COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 1 END) AS ocorrencias_alto_risco,
    COUNT(CASE WHEN o.nivel_risco = 'moderado' THEN 1 END) AS ocorrencias_risco_moderado,
    COUNT(CASE WHEN o.nivel_risco = 'baixo' THEN 1 END) AS ocorrencias_baixo_risco,
    -- Cálculo de densidade de risco
    ROUND(
        (COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 3 
                    WHEN o.nivel_risco = 'moderado' THEN 2 
                    WHEN o.nivel_risco = 'baixo' THEN 1 END) * 1.0 / COUNT(*)), 2
    ) AS indice_risco_medio,
    -- Subquery complexa: Abrigos próximos e sua capacidade
    (SELECT COUNT(*)
     FROM abrigos a
     WHERE ABS(a.latitude - ROUND(o.latitude, 2)) < 0.05  -- Raio menor para proximidade
       AND ABS(a.longitude - ROUND(o.longitude, 2)) < 0.05
    ) AS abrigos_proximos,
    (SELECT COALESCE(SUM(a.vagas_disponiveis), 0)
     FROM abrigos a
     WHERE ABS(a.latitude - ROUND(o.latitude, 2)) < 0.05
       AND ABS(a.longitude - ROUND(o.longitude, 2)) < 0.05
       AND a.status = 'ativo'
    ) AS vagas_disponiveis_proximas,
    -- Alertas gerados para esta região
    COUNT(DISTINCT al.id_alerta) AS alertas_emitidos,
    AVG(CASE WHEN al.nivel_urgencia = 'alta' THEN 3
             WHEN al.nivel_urgencia = 'media' THEN 2
             WHEN al.nivel_urgencia = 'baixa' THEN 1 END) AS media_urgencia_alertas,
    -- Tempo médio de resolução (para ocorrências resolvidas)
    AVG(CASE 
        WHEN o.status = 'resolvido' 
        THEN EXTRACT(DAY FROM (SYSDATE - o.data_ocorrencia))
    END) AS media_dias_resolucao,
    -- Tipo de ocorrência mais comum na região
    (SELECT t.nome
     FROM tipos_ocorrencia t
     JOIN ocorrencias o2 ON t.id_tipo = o2.id_tipo
     WHERE ROUND(o2.latitude, 2) = ROUND(o.latitude, 2)
       AND ROUND(o2.longitude, 2) = ROUND(o.longitude, 2)
     GROUP BY t.nome
     ORDER BY COUNT(*) DESC
     FETCH FIRST 1 ROW ONLY
    ) AS tipo_mais_comum
FROM 
    ocorrencias o
JOIN 
    tipos_ocorrencia t ON o.id_tipo = t.id_tipo
JOIN 
    usuarios u ON o.id_usuario = u.id_usuario
LEFT JOIN 
    alertas al ON o.id_ocorrencia = al.id_ocorrencia
WHERE 
    o.data_ocorrencia >= SYSDATE - 180  -- Últimos 6 meses
GROUP BY 
    ROUND(o.latitude, 2), ROUND(o.longitude, 2)
HAVING 
    COUNT(o.id_ocorrencia) >= 2  -- Regiões com pelo menos 2 ocorrências
    AND COUNT(DISTINCT o.id_usuario) >= 1  -- Pelo menos 1 usuário distinto
ORDER BY 
    indice_risco_medio DESC,
    total_ocorrencias_regiao DESC,
    ocorrencias_alto_risco DESC;

-- CONSULTA 5: Relatório de performance e engajamento de usuários
-- Utiliza: JOIN múltiplas tabelas, SUM, COUNT, AVG, GROUP BY, HAVING, subqueries, ORDER BY
SELECT 
    u.tipo_usuario,
    u.nome AS nome_usuario,
    u.email,
    EXTRACT(DAY FROM (SYSDATE - u.data_cadastro)) AS dias_desde_cadastro,
    -- Estatísticas de ocorrências
    COUNT(o.id_ocorrencia) AS total_ocorrencias_reportadas,
    COUNT(CASE WHEN o.nivel_risco = 'alto' THEN 1 END) AS ocorrencias_alto_risco,
    COUNT(CASE WHEN o.status = 'resolvido' THEN 1 END) AS ocorrencias_resolvidas,
    ROUND(
        COUNT(CASE WHEN o.status = 'resolvido' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(o.id_ocorrencia), 0), 2
    ) AS taxa_resolucao_percent,
    -- Diversidade de tipos de ocorrência reportados
    COUNT(DISTINCT o.id_tipo) AS tipos_distintos_reportados,
    -- Estatísticas de checkins em abrigos
    COUNT(c.id_checkin) AS total_checkins_realizados,
    COUNT(CASE WHEN c.data_saida IS NULL THEN 1 END) AS checkins_ativos,
    AVG(CASE 
        WHEN c.data_saida IS NOT NULL 
        THEN EXTRACT(DAY FROM (c.data_saida - c.data_entrada))
    END) AS media_dias_permanencia_abrigos,
    -- Subquery: Ranking do usuário por atividade no seu tipo
    (SELECT COUNT(*) + 1
     FROM usuarios u2
     LEFT JOIN ocorrencias o2 ON u2.id_usuario = o2.id_usuario
     WHERE u2.tipo_usuario = u.tipo_usuario
       AND u2.id_usuario != u.id_usuario
     GROUP BY u2.id_usuario
     HAVING COUNT(o2.id_ocorrencia) > COUNT(o.id_ocorrencia)
    ) AS ranking_atividade_no_tipo,
    -- Subquery: Alertas relacionados às suas ocorrências
    (SELECT COUNT(DISTINCT al.id_alerta)
     FROM alertas al
     WHERE al.id_ocorrencia IN (
         SELECT o3.id_ocorrencia 
         FROM ocorrencias o3 
         WHERE o3.id_usuario = u.id_usuario
     )
    ) AS alertas_gerados_suas_ocorrencias,
    -- Frequência de atividade (ocorrências por mês)
    ROUND(
        COUNT(o.id_ocorrencia) * 30.0 / 
        NULLIF(EXTRACT(DAY FROM (SYSDATE - u.data_cadastro)), 0), 2
    ) AS ocorrencias_por_mes,
    -- Última atividade
    GREATEST(
        COALESCE(MAX(o.data_ocorrencia), TO_DATE('1900-01-01', 'YYYY-MM-DD')),
        COALESCE(MAX(c.data_entrada), TO_DATE('1900-01-01', 'YYYY-MM-DD'))
    ) AS ultima_atividade,
    -- Classificação de engajamento
    CASE 
        WHEN COUNT(o.id_ocorrencia) >= 5 AND COUNT(c.id_checkin) >= 2 THEN 'MUITO_ATIVO'
        WHEN COUNT(o.id_ocorrencia) >= 3 OR COUNT(c.id_checkin) >= 1 THEN 'ATIVO'
        WHEN COUNT(o.id_ocorrencia) >= 1 THEN 'OCASIONAL'
        ELSE 'INATIVO'
    END AS nivel_engajamento,
    -- Subquery: Comparação com média do grupo
    (SELECT AVG(sub_count.total_ocorrencias)
     FROM (
         SELECT COUNT(o4.id_ocorrencia) as total_ocorrencias
         FROM usuarios u4
         LEFT JOIN ocorrencias o4 ON u4.id_usuario = o4.id_usuario
         WHERE u4.tipo_usuario = u.tipo_usuario
         GROUP BY u4.id_usuario
     ) sub_count
    ) AS media_ocorrencias_do_grupo
FROM 
    usuarios u
LEFT JOIN 
    ocorrencias o ON u.id_usuario = o.id_usuario
LEFT JOIN 
    checkins_abrigos c ON u.id_usuario = c.id_usuario
LEFT JOIN 
    tipos_ocorrencia t ON o.id_tipo = t.id_tipo
WHERE 
    u.data_cadastro >= SYSDATE - 365  -- Usuários cadastrados no último ano
GROUP BY 
    u.id_usuario, u.tipo_usuario, u.nome, u.email, u.data_cadastro
HAVING 
    EXTRACT(DAY FROM (SYSDATE - u.data_cadastro)) >= 7  -- Pelo menos 1 semana de cadastro
ORDER BY 
    u.tipo_usuario,
    total_ocorrencias_reportadas DESC,
    total_checkins_realizados DESC,
    dias_desde_cadastro;


-- ========================================
-- 5. BLOCOS ANÔNIMOS COM CONSULTAS COMPLEXAS
-- ========================================

-- Bloco Anônimo 1: Análise Completa de Ocorrências e Alertas por Região
DECLARE
    v_total_ocorrencias NUMBER;
    v_regiao VARCHAR2(50);
    v_risco_medio NUMBER;
    v_status_emergencia VARCHAR2(20);
    v_contador NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ANÁLISE COMPLETA DE OCORRÊNCIAS E ALERTAS POR REGIÃO ===');
    DBMS_OUTPUT.PUT_LINE('Data/Hora: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Obtém status geral de emergência
    v_status_emergencia := obter_status_emergencia();
    DBMS_OUTPUT.PUT_LINE('STATUS GERAL DO SISTEMA: ' || v_status_emergencia);
    DBMS_OUTPUT.PUT_LINE('Taxa de Ocupação Média dos Abrigos: ' || calcular_taxa_ocupacao_media() || '%');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Análise por regiões (dividindo em quadrantes)
    FOR regiao_rec IN (
        SELECT 
            CASE 
                WHEN latitude >= -23.55 AND longitude >= -46.65 THEN 'NORDESTE'
                WHEN latitude >= -23.55 AND longitude < -46.65 THEN 'NOROESTE'
                WHEN latitude < -23.55 AND longitude >= -46.65 THEN 'SUDESTE'
                ELSE 'SUDOESTE'
            END as regiao,
            COUNT(o.id_ocorrencia) as total_ocorrencias,
            COUNT(DISTINCT o.id_tipo) as tipos_distintos,
            COUNT(a.id_alerta) as total_alertas,
            AVG(CASE o.nivel_risco 
                WHEN 'baixo' THEN 1 
                WHEN 'moderado' THEN 2 
                WHEN 'alto' THEN 3 
            END) as risco_medio_numerico
        FROM ocorrencias o
        LEFT JOIN alertas a ON o.id_ocorrencia = a.id_ocorrencia
        GROUP BY 
            CASE 
                WHEN latitude >= -23.55 AND longitude >= -46.65 THEN 'NORDESTE'
                WHEN latitude >= -23.55 AND longitude < -46.65 THEN 'NOROESTE'
                WHEN latitude < -23.55 AND longitude >= -46.65 THEN 'SUDESTE'
                ELSE 'SUDOESTE'
            END
        HAVING COUNT(o.id_ocorrencia) > 0
        ORDER BY risco_medio_numerico DESC, total_ocorrencias DESC
    ) LOOP
        v_contador := v_contador + 1;
        
        DBMS_OUTPUT.PUT_LINE('REGIÃO ' || regiao_rec.regiao || ':');
        DBMS_OUTPUT.PUT_LINE('  - Total de Ocorrências: ' || regiao_rec.total_ocorrencias);
        DBMS_OUTPUT.PUT_LINE('  - Tipos Distintos: ' || regiao_rec.tipos_distintos);
        DBMS_OUTPUT.PUT_LINE('  - Total de Alertas: ' || regiao_rec.total_alertas);
        DBMS_OUTPUT.PUT_LINE('  - Risco Médio: ' || ROUND(regiao_rec.risco_medio_numerico, 2));
        
        -- Análise condicional por região
        IF regiao_rec.risco_medio_numerico >= 2.5 THEN
            DBMS_OUTPUT.PUT_LINE('  ⚠️  ATENÇÃO: Região de ALTO RISCO!');
        ELSIF regiao_rec.risco_medio_numerico >= 1.5 THEN
            DBMS_OUTPUT.PUT_LINE('  ⚡ Região de risco MODERADO');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  ✅ Região de risco BAIXO');
        END IF;
        
        -- Subquery para verificar abrigos próximos
        FOR abrigo_rec IN (
            SELECT nome, vagas_disponiveis, capacidade_total
            FROM abrigos
            WHERE ROWNUM <= 2  -- Limita a 2 abrigos por região para exemplo
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  - Abrigo próximo: ' || abrigo_rec.nome || 
                               ' (' || abrigo_rec.vagas_disponiveis || '/' || 
                               abrigo_rec.capacidade_total || ' vagas)');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    
    -- Verifica se não há dados
    IF v_contador = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Nenhuma ocorrência encontrada no sistema.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total de regiões analisadas: ' || v_contador);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== FIM DA ANÁLISE ===');
END;
/

-- Bloco Anônimo 2: Relatório de Eficiência de Abrigos e Recomendações
DECLARE
    v_total_checkins NUMBER;
    v_media_permanencia NUMBER;
    v_abrigo_mais_eficiente VARCHAR2(100);
    v_recomendacao VARCHAR2(500);
    v_contador_criticos NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== RELATÓRIO DE EFICIÊNCIA DE ABRIGOS ===');
    DBMS_OUTPUT.PUT_LINE('Gerado em: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Análise geral do sistema
    SELECT COUNT(*), AVG(NVL(EXTRACT(DAY FROM (SYSDATE - data_entrada)), 0))
    INTO v_total_checkins, v_media_permanencia
    FROM checkins_abrigos
    WHERE data_saida IS NULL;
    
    DBMS_OUTPUT.PUT_LINE('ESTATÍSTICAS GERAIS:');
    DBMS_OUTPUT.PUT_LINE('Total de pessoas abrigadas: ' || v_total_checkins);
    DBMS_OUTPUT.PUT_LINE('Média de permanência: ' || ROUND(v_media_permanencia, 1) || ' dias');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Loop através dos abrigos com análise detalhada
    FOR abrigo_rec IN (
        SELECT 
            a.id_abrigo,
            a.nome,
            a.capacidade_total,
            a.vagas_disponiveis,
            (a.capacidade_total - a.vagas_disponiveis) as ocupacao_atual,
            ROUND(((a.capacidade_total - a.vagas_disponiveis) / a.capacidade_total) * 100, 2) as taxa_ocupacao,
            COUNT(c.id_checkin) as total_checkins_historico,
            COUNT(CASE WHEN c.data_saida IS NULL THEN 1 END) as checkins_ativos,
            AVG(CASE WHEN c.data_saida IS NULL THEN 
                EXTRACT(DAY FROM (SYSDATE - c.data_entrada)) 
                ELSE 
                EXTRACT(DAY FROM (c.data_saida - c.data_entrada)) 
            END) as media_permanencia_abrigo
        FROM abrigos a
        LEFT JOIN checkins_abrigos c ON a.id_abrigo = c.id_abrigo
        GROUP BY a.id_abrigo, a.nome, a.capacidade_total, a.vagas_disponiveis
        ORDER BY taxa_ocupacao DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('ABRIGO: ' || abrigo_rec.nome);
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Capacidade: ' || abrigo_rec.capacidade_total || ' pessoas');
        DBMS_OUTPUT.PUT_LINE('Ocupação atual: ' || abrigo_rec.ocupacao_atual || ' (' || abrigo_rec.taxa_ocupacao || '%)');
        DBMS_OUTPUT.PUT_LINE('Checkins históricos: ' || abrigo_rec.total_checkins_historico);
        DBMS_OUTPUT.PUT_LINE('Checkins ativos: ' || abrigo_rec.checkins_ativos);
        DBMS_OUTPUT.PUT_LINE('Média de permanência: ' || ROUND(NVL(abrigo_rec.media_permanencia_abrigo, 0), 1) || ' dias');
        
        -- Análise condicional e recomendações
        IF abrigo_rec.taxa_ocupacao > 90 THEN
            v_contador_criticos := v_contador_criticos + 1;
            v_recomendacao := 'URGENTE: Redirecionar pessoas. Solicitar recursos extras.';
            DBMS_OUTPUT.PUT_LINE('🚨 STATUS: CRÍTICO');
        ELSIF abrigo_rec.taxa_ocupacao > 75 THEN
            v_recomendacao := 'ALERTA: Preparar plano de contingência.';
            DBMS_OUTPUT.PUT_LINE('⚠️  STATUS: ALERTA');
        ELSIF abrigo_rec.taxa_ocupacao > 50 THEN
            v_recomendacao := 'ATENÇÃO: Monitorar regularmente.';
            DBMS_OUTPUT.PUT_LINE('⚡ STATUS: ATENÇÃO');
        ELSE
            v_recomendacao := 'NORMAL: Capacidade disponível para receber mais pessoas.';
            DBMS_OUTPUT.PUT_LINE('✅ STATUS: NORMAL');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Recomendação: ' || v_recomendacao);
        
        -- Subquery para verificar tipos de usuários no abrigo
        FOR tipo_rec IN (
            SELECT 
                u.tipo_usuario,
                COUNT(*) as quantidade
            FROM checkins_abrigos c
            JOIN usuarios u ON c.id_usuario = u.id_usuario
            WHERE c.id_abrigo = abrigo_rec.id_abrigo
              AND c.data_saida IS NULL
            GROUP BY u.tipo_usuario
            ORDER BY quantidade DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('- ' || tipo_rec.tipo_usuario || ': ' || tipo_rec.quantidade || ' pessoas');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    
    -- Resumo final com recomendações gerais
    DBMS_OUTPUT.PUT_LINE('=== RESUMO E RECOMENDAÇÕES GERAIS ===');
    DBMS_OUTPUT.PUT_LINE('Abrigos em situação crítica: ' || v_contador_criticos);
    
    IF v_contador_criticos > 0 THEN
        DBMS_OUTPUT.PUT_LINE('🚨 AÇÃO NECESSÁRIA: Sistema com abrigos sobrecarregados!');
        DBMS_OUTPUT.PUT_LINE('Recomendações:');
        DBMS_OUTPUT.PUT_LINE('1. Ativar abrigos de emergência');
        DBMS_OUTPUT.PUT_LINE('2. Redistribuir pessoas entre abrigos');
        DBMS_OUTPUT.PUT_LINE('3. Solicitar recursos adicionais');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ Sistema de abrigos operando adequadamente.');
    END IF;
END;
/
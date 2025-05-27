-- ========================================
-- 4. FUNÇÕES PARA RETORNO DE DADOS PROCESSADOS
-- ========================================

-- Função 1: Calcular risco médio por região (baseado em coordenadas)
CREATE OR REPLACE FUNCTION calcular_risco_medio_regiao(
    p_latitude_min NUMBER,
    p_latitude_max NUMBER,
    p_longitude_min NUMBER,
    p_longitude_max NUMBER
) RETURN NUMBER IS
    v_risco_medio NUMBER;
    v_total_pontos NUMBER := 0;
    v_soma_riscos NUMBER := 0;
BEGIN
    -- Calcula a média ponderada dos níveis de risco na região
    FOR rec IN (
        SELECT nivel_risco, COUNT(*) as quantidade
        FROM ocorrencias
        WHERE latitude BETWEEN p_latitude_min AND p_latitude_max
          AND longitude BETWEEN p_longitude_min AND p_longitude_max
        GROUP BY nivel_risco
    ) LOOP
        v_total_pontos := v_total_pontos + rec.quantidade;
        
        -- Atribui pesos aos níveis de risco
        CASE rec.nivel_risco
            WHEN 'baixo' THEN v_soma_riscos := v_soma_riscos + (rec.quantidade * 1);
            WHEN 'moderado' THEN v_soma_riscos := v_soma_riscos + (rec.quantidade * 2);
            WHEN 'alto' THEN v_soma_riscos := v_soma_riscos + (rec.quantidade * 3);
        END CASE;
    END LOOP;
    
    -- Evita divisão por zero
    IF v_total_pontos = 0 THEN
        RETURN 0;
    ELSE
        v_risco_medio := v_soma_riscos / v_total_pontos;
        RETURN ROUND(v_risco_medio, 2);
    END IF;
END;
/

-- Função 2: Retornar total de ocorrências por região e tipo
CREATE OR REPLACE FUNCTION total_ocorrencias_por_regiao(
    p_latitude_centro NUMBER,
    p_longitude_centro NUMBER,
    p_raio NUMBER DEFAULT 0.01  -- Raio em graus (aproximadamente 1km)
) RETURN NUMBER IS
    v_total NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM ocorrencias
    WHERE SQRT(POWER(latitude - p_latitude_centro, 2) + POWER(longitude - p_longitude_centro, 2)) <= p_raio;
    
    RETURN v_total;
END;
/

-- Função 3: Calcular taxa de ocupação média dos abrigos
CREATE OR REPLACE FUNCTION calcular_taxa_ocupacao_media RETURN NUMBER IS
    v_taxa_media NUMBER;
BEGIN
    SELECT ROUND(AVG((capacidade_total - vagas_disponiveis) / capacidade_total * 100), 2)
    INTO v_taxa_media
    FROM abrigos
    WHERE capacidade_total > 0;
    
    RETURN NVL(v_taxa_media, 0);
END;
/

-- Função 4: Obter status de emergência baseado em múltiplos fatores
CREATE OR REPLACE FUNCTION obter_status_emergencia RETURN VARCHAR2 IS
    v_ocorrencias_alto_risco NUMBER;
    v_alertas_alta_urgencia NUMBER;
    v_taxa_ocupacao_media NUMBER;
    v_status VARCHAR2(20);
BEGIN
    -- Conta ocorrências de alto risco nas últimas 24 horas
    SELECT COUNT(*)
    INTO v_ocorrencias_alto_risco
    FROM ocorrencias
    WHERE nivel_risco = 'alto'
      AND data_ocorrencia > SYSDATE - 1;
    
    -- Conta alertas de alta urgência nas últimas 24 horas
    SELECT COUNT(*)
    INTO v_alertas_alta_urgencia
    FROM alertas
    WHERE nivel_urgencia = 'alta'
      AND data_emissao > SYSDATE - 1;
    
    -- Obtém taxa de ocupação média
    v_taxa_ocupacao_media := calcular_taxa_ocupacao_media();
    
    -- Define status baseado nos critérios
    IF v_ocorrencias_alto_risco >= 3 OR v_alertas_alta_urgencia >= 5 OR v_taxa_ocupacao_media > 90 THEN
        v_status := 'CRITICO';
    ELSIF v_ocorrencias_alto_risco >= 2 OR v_alertas_alta_urgencia >= 3 OR v_taxa_ocupacao_media > 75 THEN
        v_status := 'ALTO';
    ELSIF v_ocorrencias_alto_risco >= 1 OR v_alertas_alta_urgencia >= 1 OR v_taxa_ocupacao_media > 50 THEN
        v_status := 'MODERADO';
    ELSE
        v_status := 'NORMAL';
    END IF;
    
    RETURN v_status;
END;
/
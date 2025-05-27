-- ========================================
-- 6. CURSORES EXPLÍCITOS 
-- ========================================

-- CURSOR EXPLÍCITO 1: Procedure para relatório de ocupação de abrigos
CREATE OR REPLACE PROCEDURE relatorio_ocupacao_abrigos AS
    -- Declaração do cursor para abrigos
    CURSOR c_abrigos IS
        SELECT 
            a.id_abrigo,
            a.nome,
            a.capacidade_total,
            a.vagas_disponiveis,
            (a.capacidade_total - a.vagas_disponiveis) as ocupacao_atual,
            ROUND(((a.capacidade_total - a.vagas_disponiveis) / a.capacidade_total) * 100, 2) as percentual_ocupacao
        FROM abrigos a
        ORDER BY percentual_ocupacao DESC;
    
    -- Declaração do cursor para checkins ativos por abrigo
    CURSOR c_checkins(p_id_abrigo NUMBER) IS
        SELECT 
            u.nome as nome_usuario,
            u.tipo_usuario,
            c.data_entrada,
            ROUND(SYSDATE - c.data_entrada) as dias_permanencia
        FROM checkins_abrigos c
        JOIN usuarios u ON c.id_usuario = u.id_usuario
        WHERE c.id_abrigo = p_id_abrigo AND c.data_saida IS NULL
        ORDER BY c.data_entrada;
    
    -- Variáveis para armazenar dados dos cursores
    v_id_abrigo abrigos.id_abrigo%TYPE;
    v_nome_abrigo abrigos.nome%TYPE;
    v_capacidade abrigos.capacidade_total%TYPE;
    v_vagas abrigos.vagas_disponiveis%TYPE;
    v_ocupacao NUMBER;
    v_percentual NUMBER;
    
    v_nome_usuario usuarios.nome%TYPE;
    v_tipo_usuario usuarios.tipo_usuario%TYPE;
    v_data_entrada checkins_abrigos.data_entrada%TYPE;
    v_dias_permanencia NUMBER;
    
    -- Contadores
    v_total_abrigos NUMBER := 0;
    v_total_pessoas NUMBER := 0;
    v_contador_checkins NUMBER;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== RELATÓRIO DE OCUPAÇÃO DE ABRIGOS ===');
    DBMS_OUTPUT.PUT_LINE('Data/Hora: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    -- ABERTURA DO CURSOR PRINCIPAL
    OPEN c_abrigos;
    
    -- LOOP PRINCIPAL - Percorre todos os abrigos
    LOOP
        -- FETCH dos dados do abrigo
        FETCH c_abrigos INTO v_id_abrigo, v_nome_abrigo, v_capacidade, v_vagas, v_ocupacao, v_percentual;
        
        -- Condição de saída do loop
        EXIT WHEN c_abrigos%NOTFOUND;
        
        -- Incrementa contadores
        v_total_abrigos := v_total_abrigos + 1;
        v_total_pessoas := v_total_pessoas + v_ocupacao;
        
        -- Exibe informações do abrigo
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ABRIGO: ' || v_nome_abrigo);
        DBMS_OUTPUT.PUT_LINE('Capacidade: ' || v_capacidade || ' | Ocupação: ' || v_ocupacao || ' (' || v_percentual || '%)');
        DBMS_OUTPUT.PUT_LINE('Vagas disponíveis: ' || v_vagas);
        
        -- Status do abrigo baseado na ocupação
        IF v_percentual >= 90 THEN
            DBMS_OUTPUT.PUT_LINE('STATUS: CRÍTICO - Quase lotado!');
        ELSIF v_percentual >= 75 THEN
            DBMS_OUTPUT.PUT_LINE('STATUS: ALERTA - Alta ocupação');
        ELSIF v_percentual >= 50 THEN
            DBMS_OUTPUT.PUT_LINE('STATUS: MODERADO - Ocupação normal');
        ELSE
            DBMS_OUTPUT.PUT_LINE('STATUS: BAIXO - Muitas vagas disponíveis');
        END IF;
        
        -- ABERTURA DO CURSOR SECUNDÁRIO para checkins
        OPEN c_checkins(v_id_abrigo);
        
        DBMS_OUTPUT.PUT_LINE('Pessoas registradas:');
        v_contador_checkins := 0;
        
        -- LOOP SECUNDÁRIO - Percorre checkins do abrigo atual
        LOOP
            -- FETCH dos dados do checkin
            FETCH c_checkins INTO v_nome_usuario, v_tipo_usuario, v_data_entrada, v_dias_permanencia;
            
            -- Condição de saída do loop secundário
            EXIT WHEN c_checkins%NOTFOUND;
            
            v_contador_checkins := v_contador_checkins + 1;
            
            -- Exibe informações da pessoa
            DBMS_OUTPUT.PUT_LINE('  ' || v_contador_checkins || '. ' || v_nome_usuario || 
                               ' (' || v_tipo_usuario || ') - ' || 
                               v_dias_permanencia || ' dias');
        END LOOP;
        
        -- FECHAMENTO DO CURSOR SECUNDÁRIO
        CLOSE c_checkins;
        
        IF v_contador_checkins = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  Nenhuma pessoa registrada atualmente.');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('------------------------------------------');
    END LOOP;
    
    -- FECHAMENTO DO CURSOR PRINCIPAL
    CLOSE c_abrigos;
    
    -- Resumo geral
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== RESUMO GERAL ===');
    DBMS_OUTPUT.PUT_LINE('Total de abrigos: ' || v_total_abrigos);
    DBMS_OUTPUT.PUT_LINE('Total de pessoas abrigadas: ' || v_total_pessoas);
    DBMS_OUTPUT.PUT_LINE('====================');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Garantir fechamento dos cursores em caso de erro
        IF c_abrigos%ISOPEN THEN
            CLOSE c_abrigos;
        END IF;
        IF c_checkins%ISOPEN THEN
            CLOSE c_checkins;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Erro: ' || SQLERRM);
END;
/

-- CURSOR EXPLÍCITO 2: Bloco anônimo para análise de ocorrências por usuário
DECLARE
    -- Cursor para usuários com ocorrências
    CURSOR c_usuarios_ocorrencias IS
        SELECT 
            u.id_usuario,
            u.nome,
            u.tipo_usuario,
            COUNT(o.id_ocorrencia) as total_ocorrencias
        FROM usuarios u
        LEFT JOIN ocorrencias o ON u.id_usuario = o.id_usuario
        GROUP BY u.id_usuario, u.nome, u.tipo_usuario
        HAVING COUNT(o.id_ocorrencia) > 0
        ORDER BY COUNT(o.id_ocorrencia) DESC;
    
    -- Cursor para detalhes das ocorrências de um usuário específico
    CURSOR c_detalhes_ocorrencias(p_id_usuario NUMBER) IS
        SELECT 
            o.id_ocorrencia,
            t.nome as tipo_ocorrencia,
            o.nivel_risco,
            o.status,
            o.data_ocorrencia,
            ROUND(SYSDATE - o.data_ocorrencia) as dias_desde_ocorrencia
        FROM ocorrencias o
        JOIN tipos_ocorrencia t ON o.id_tipo = t.id_tipo
        WHERE o.id_usuario = p_id_usuario
        ORDER BY o.data_ocorrencia DESC;
    
    -- Variáveis para o cursor principal
    v_id_usuario usuarios.id_usuario%TYPE;
    v_nome_usuario usuarios.nome%TYPE;
    v_tipo_usuario usuarios.tipo_usuario%TYPE;
    v_total_ocorrencias NUMBER;
    
    -- Variáveis para o cursor de detalhes
    v_id_ocorrencia ocorrencias.id_ocorrencia%TYPE;
    v_tipo_ocorrencia tipos_ocorrencia.nome%TYPE;
    v_nivel_risco ocorrencias.nivel_risco%TYPE;
    v_status ocorrencias.status%TYPE;
    v_data_ocorrencia ocorrencias.data_ocorrencia%TYPE;
    v_dias_desde NUMBER;
    
    -- Contadores e estatísticas
    v_contador_usuarios NUMBER := 0;
    v_total_geral_ocorrencias NUMBER := 0;
    v_contador_detalhes NUMBER;
    v_ocorrencias_alto_risco NUMBER;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ANÁLISE DE OCORRÊNCIAS POR USUÁRIO ===');
    DBMS_OUTPUT.PUT_LINE('Data/Hora: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    -- ABERTURA DO CURSOR PRINCIPAL
    OPEN c_usuarios_ocorrencias;
    
    -- LOOP PRINCIPAL - Percorre usuários com ocorrências
    LOOP
        -- FETCH dos dados do usuário
        FETCH c_usuarios_ocorrencias INTO v_id_usuario, v_nome_usuario, v_tipo_usuario, v_total_ocorrencias;
        
        -- Condição de saída do loop
        EXIT WHEN c_usuarios_ocorrencias%NOTFOUND;
        
        -- Incrementa contadores
        v_contador_usuarios := v_contador_usuarios + 1;
        v_total_geral_ocorrencias := v_total_geral_ocorrencias + v_total_ocorrencias;
        
        -- Exibe informações do usuário
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(v_contador_usuarios || '. USUÁRIO: ' || v_nome_usuario);
        DBMS_OUTPUT.PUT_LINE('   Tipo: ' || v_tipo_usuario || ' | Total de ocorrências: ' || v_total_ocorrencias);
        
        -- Classificação do usuário baseada no número de ocorrências
        IF v_total_ocorrencias >= 5 THEN
            DBMS_OUTPUT.PUT_LINE('   CLASSIFICAÇÃO: USUÁRIO MUITO ATIVO');
        ELSIF v_total_ocorrencias >= 3 THEN
            DBMS_OUTPUT.PUT_LINE('   CLASSIFICAÇÃO: USUÁRIO ATIVO');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   CLASSIFICAÇÃO: USUÁRIO OCASIONAL');
        END IF;
        
        -- ABERTURA DO CURSOR SECUNDÁRIO para detalhes das ocorrências
        OPEN c_detalhes_ocorrencias(v_id_usuario);
        
        DBMS_OUTPUT.PUT_LINE('   Detalhes das ocorrências:');
        v_contador_detalhes := 0;
        v_ocorrencias_alto_risco := 0;
        
        -- LOOP SECUNDÁRIO - Percorre ocorrências do usuário atual
        LOOP
            -- FETCH dos detalhes da ocorrência
            FETCH c_detalhes_ocorrencias INTO v_id_ocorrencia, v_tipo_ocorrencia, 
                  v_nivel_risco, v_status, v_data_ocorrencia, v_dias_desde;
            
            -- Condição de saída do loop secundário
            EXIT WHEN c_detalhes_ocorrencias%NOTFOUND;
            
            v_contador_detalhes := v_contador_detalhes + 1;
            
            -- Conta ocorrências de alto risco
            IF v_nivel_risco = 'alto' THEN
                v_ocorrencias_alto_risco := v_ocorrencias_alto_risco + 1;
            END IF;
            
            -- Exibe detalhes da ocorrência
            DBMS_OUTPUT.PUT_LINE('     ' || v_contador_detalhes || '. ' || v_tipo_ocorrencia || 
                               ' (' || v_nivel_risco || ') - ' || v_status || 
                               ' - há ' || v_dias_desde || ' dias');
        END LOOP;
        
        -- FECHAMENTO DO CURSOR SECUNDÁRIO
        CLOSE c_detalhes_ocorrencias;
        
        -- Estatísticas do usuário
        IF v_ocorrencias_alto_risco > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ATENÇÃO: ' || v_ocorrencias_alto_risco || ' ocorrência(s) de ALTO RISCO!');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('   ------------------------------------------');
    END LOOP;
    
    -- FECHAMENTO DO CURSOR PRINCIPAL
    CLOSE c_usuarios_ocorrencias;
    
    -- Estatísticas gerais
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== ESTATÍSTICAS GERAIS ===');
    DBMS_OUTPUT.PUT_LINE('Usuários com ocorrências: ' || v_contador_usuarios);
    DBMS_OUTPUT.PUT_LINE('Total geral de ocorrências: ' || v_total_geral_ocorrencias);
    
    IF v_contador_usuarios > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Média de ocorrências por usuário: ' || 
                           ROUND(v_total_geral_ocorrencias / v_contador_usuarios, 2));
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('============================');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Garantir fechamento dos cursores em caso de erro
        IF c_usuarios_ocorrencias%ISOPEN THEN
            CLOSE c_usuarios_ocorrencias;
        END IF;
        IF c_detalhes_ocorrencias%ISOPEN THEN
            CLOSE c_detalhes_ocorrencias;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Erro: ' || SQLERRM);
END;
/

-- CURSOR EXPLÍCITO 3: Procedure para monitoramento de alertas críticos
CREATE OR REPLACE PROCEDURE monitorar_alertas_criticos AS
    -- Cursor para alertas de alta urgência
    CURSOR c_alertas_criticos IS
        SELECT 
            a.id_alerta,
            a.titulo,
            a.mensagem,
            a.nivel_urgencia,
            a.data_emissao,
            a.fonte,
            ROUND((SYSDATE - a.data_emissao) * 24, 2) as horas_desde_emissao
        FROM alertas a
        WHERE a.nivel_urgencia = 'alta'
        ORDER BY a.data_emissao DESC;
    
    -- Cursor para ocorrências relacionadas aos alertas
    CURSOR c_ocorrencia_alerta(p_id_alerta NUMBER) IS
        SELECT 
            o.id_ocorrencia,
            o.descricao,
            o.nivel_risco,
            o.status,
            t.nome as tipo_ocorrencia,
            u.nome as nome_usuario
        FROM alertas a
        LEFT JOIN ocorrencias o ON a.id_ocorrencia = o.id_ocorrencia
        LEFT JOIN tipos_ocorrencia t ON o.id_tipo = t.id_tipo
        LEFT JOIN usuarios u ON o.id_usuario = u.id_usuario
        WHERE a.id_alerta = p_id_alerta;
    
    -- Variáveis para cursor de alertas
    v_id_alerta alertas.id_alerta%TYPE;
    v_titulo alertas.titulo%TYPE;
    v_mensagem alertas.mensagem%TYPE;
    v_nivel_urgencia alertas.nivel_urgencia%TYPE;
    v_data_emissao alertas.data_emissao%TYPE;
    v_fonte alertas.fonte%TYPE;
    v_horas_desde NUMBER;
    
    -- Variáveis para cursor de ocorrências
    v_id_ocorrencia ocorrencias.id_ocorrencia%TYPE;
    v_descricao ocorrencias.descricao%TYPE;
    v_nivel_risco ocorrencias.nivel_risco%TYPE;
    v_status ocorrencias.status%TYPE;
    v_tipo_ocorrencia tipos_ocorrencia.nome%TYPE;
    v_nome_usuario usuarios.nome%TYPE;
    
    -- Contadores
    v_total_alertas NUMBER := 0;
    v_alertas_recentes NUMBER := 0;
    v_alertas_antigos NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== MONITORAMENTO DE ALERTAS CRÍTICOS ===');
    DBMS_OUTPUT.PUT_LINE('Data/Hora: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('=========================================');
    
    -- ABERTURA DO CURSOR PRINCIPAL
    OPEN c_alertas_criticos;
    
    -- LOOP PRINCIPAL - Percorre alertas críticos
    LOOP
        -- FETCH dos dados do alerta
        FETCH c_alertas_criticos INTO v_id_alerta, v_titulo, v_mensagem, 
              v_nivel_urgencia, v_data_emissao, v_fonte, v_horas_desde;
        
        -- Condição de saída do loop
        EXIT WHEN c_alertas_criticos%NOTFOUND;
        
        -- Incrementa contadores
        v_total_alertas := v_total_alertas + 1;
        
        -- Classifica alertas por tempo
        IF v_horas_desde <= 24 THEN
            v_alertas_recentes := v_alertas_recentes + 1;
        ELSE
            v_alertas_antigos := v_alertas_antigos + 1;
        END IF;
        
        -- Exibe informações do alerta
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ALERTA CRÍTICO #' || v_id_alerta);
        DBMS_OUTPUT.PUT_LINE('Título: ' || v_titulo);
        DBMS_OUTPUT.PUT_LINE('Mensagem: ' || v_mensagem);
        DBMS_OUTPUT.PUT_LINE('Fonte: ' || v_fonte);
        DBMS_OUTPUT.PUT_LINE('Emitido há: ' || v_horas_desde || ' horas');
        
        -- Status temporal do alerta
        IF v_horas_desde <= 1 THEN
            DBMS_OUTPUT.PUT_LINE('⏰ STATUS: MUITO RECENTE - Ação imediata necessária!');
        ELSIF v_horas_desde <= 6 THEN
            DBMS_OUTPUT.PUT_LINE('⏰ STATUS: RECENTE - Monitorar de perto');
        ELSIF v_horas_desde <= 24 THEN
            DBMS_OUTPUT.PUT_LINE('⏰ STATUS: DENTRO DO PRAZO - Acompanhar evolução');
        ELSE
            DBMS_OUTPUT.PUT_LINE('⏰ STATUS: ANTIGO - Verificar se ainda é relevante');
        END IF;
        
        -- ABERTURA DO CURSOR SECUNDÁRIO para ocorrência relacionada
        OPEN c_ocorrencia_alerta(v_id_alerta);
        
        -- FETCH da ocorrência relacionada (apenas uma por alerta)
        FETCH c_ocorrencia_alerta INTO v_id_ocorrencia, v_descricao, v_nivel_risco, 
              v_status, v_tipo_ocorrencia, v_nome_usuario;
        
        IF c_ocorrencia_alerta%FOUND THEN
            DBMS_OUTPUT.PUT_LINE('📍 Ocorrência relacionada:');
            DBMS_OUTPUT.PUT_LINE('   ID: ' || v_id_ocorrencia || ' | Tipo: ' || v_tipo_ocorrencia);
            DBMS_OUTPUT.PUT_LINE('   Risco: ' || v_nivel_risco || ' | Status: ' || v_status);
            DBMS_OUTPUT.PUT_LINE('   Reportado por: ' || v_nome_usuario);
            IF v_descricao IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('   Descrição: ' || SUBSTR(v_descricao, 1, 100) || 
                                   CASE WHEN LENGTH(v_descricao) > 100 THEN '...' ELSE '' END);
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('📍 Nenhuma ocorrência específica relacionada');
        END IF;
        
        -- FECHAMENTO DO CURSOR SECUNDÁRIO
        CLOSE c_ocorrencia_alerta;
        
        DBMS_OUTPUT.PUT_LINE('------------------------------------------');
    END LOOP;
    
    -- FECHAMENTO DO CURSOR PRINCIPAL
    CLOSE c_alertas_criticos;
    
    -- Resumo do monitoramento
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== RESUMO DO MONITORAMENTO ===');
    DBMS_OUTPUT.PUT_LINE('Total de alertas críticos: ' || v_total_alertas);
    DBMS_OUTPUT.PUT_LINE('Alertas recentes (≤24h): ' || v_alertas_recentes);
    DBMS_OUTPUT.PUT_LINE('Alertas antigos (>24h): ' || v_alertas_antigos);
    
    IF v_total_alertas = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✅ Nenhum alerta crítico ativo no momento.');
    ELSIF v_alertas_recentes > 5 THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  ATENÇÃO: Muitos alertas críticos recentes!');
        DBMS_OUTPUT.PUT_LINE('   Recomenda-se revisão urgente dos protocolos.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Garantir fechamento dos cursores em caso de erro
        IF c_alertas_criticos%ISOPEN THEN
            CLOSE c_alertas_criticos;
        END IF;
        IF c_ocorrencia_alerta%ISOPEN THEN
            CLOSE c_ocorrencia_alerta;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Erro no monitoramento: ' || SQLERRM);
END;
/

-- Exemplos de execução dos cursores explícitos
/*
-- Para executar a procedure de relatório de ocupação:
EXEC relatorio_ocupacao_abrigos;

-- Para executar o bloco anônimo de análise de ocorrências:
-- (O bloco anônimo é executado diretamente)

-- Para executar o monitoramento de alertas críticos:
EXEC monitorar_alertas_criticos;
*/
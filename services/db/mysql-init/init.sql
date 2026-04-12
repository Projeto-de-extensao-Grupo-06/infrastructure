SET NAMES utf8mb4;
ALTER DATABASE solarway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Configurações Globais e Permissões
CREATE USER IF NOT EXISTS 'solarway'@'%' IDENTIFIED BY '06241234';
GRANT ALL PRIVILEGES ON *.* TO 'solarway'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- 1. Funções Base
CREATE FUNCTION IF NOT EXISTS unaccent(str TEXT) 
RETURNS TEXT DETERMINISTIC 
RETURN str COLLATE utf8mb4_unicode_ci;

-- 2. DDL Básica (Tabelas dependentes de inserts iniciais)
-- Criamos as tabelas manualmente para garantir que existam ANTES dos inserts do script de inicialização.
-- O Hibernate fará o "update" delas depois, o que é seguro.

CREATE TABLE IF NOT EXISTS permission_group (
    id_permission_group BIGINT AUTO_INCREMENT PRIMARY KEY,
    role VARCHAR(255),
    main_module VARCHAR(255),
    access_client INT,
    access_project INT,
    access_budget INT,
    access_schedule INT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS address (
    id_address BIGINT AUTO_INCREMENT PRIMARY KEY,
    postal_code VARCHAR(255),
    street_name VARCHAR(255),
    number VARCHAR(255),
    neighborhood VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255),
    type VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS client (
    id_client BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    document_number VARCHAR(255),
    document_type VARCHAR(255),
    created_at DATETIME(6),
    updated_at DATETIME(6),
    phone VARCHAR(255),
    email VARCHAR(255),
    fk_main_address BIGINT,
    status VARCHAR(255),
    CONSTRAINT fk_client_address FOREIGN KEY (fk_main_address) REFERENCES address(id_address)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS coworker (
    id_coworker BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255),
    password VARCHAR(255),
    is_active BIT(1),
    fk_permission_group BIGINT,
    CONSTRAINT fk_coworker_permission FOREIGN KEY (fk_permission_group) REFERENCES permission_group(id_permission_group)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS project (
    id_project BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    status_weight INT,
    preview_status VARCHAR(255),
    is_active BIT(1),
    system_type VARCHAR(255),
    project_from VARCHAR(255),
    created_at DATETIME(6),
    deadline DATETIME(6),
    fk_client BIGINT,
    fk_responsible BIGINT,
    fk_address BIGINT,
    CONSTRAINT fk_project_client FOREIGN KEY (fk_client) REFERENCES client(id_client),
    CONSTRAINT fk_project_coworker FOREIGN KEY (fk_responsible) REFERENCES coworker(id_coworker),
    CONSTRAINT fk_project_address FOREIGN KEY (fk_address) REFERENCES address(id_address)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material (
    id_material BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    metric VARCHAR(255),
    hidden BIT(1),
    description TEXT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material_url (
    id_material_url BIGINT AUTO_INCREMENT PRIMARY KEY,
    url VARCHAR(500),
    fk_material BIGINT,
    price DECIMAL(19,2),
    hidden BIT(1),
    CONSTRAINT fk_material_url_material FOREIGN KEY (fk_material) REFERENCES material(id_material)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS coworker_project (
    fk_coworker BIGINT NOT NULL,
    fk_project BIGINT NOT NULL,
    is_responsible BIT(1),
    PRIMARY KEY (fk_coworker, fk_project),
    CONSTRAINT fk_cp_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker),
    CONSTRAINT fk_cp_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS schedule (
    id_schedule BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    start_date DATETIME(6),
    end_date DATETIME(6),
    type VARCHAR(255),
    status VARCHAR(255),
    is_active BIT(1),
    fk_project BIGINT,
    fk_coworker BIGINT NOT NULL,
    CONSTRAINT fk_schedule_project FOREIGN KEY (fk_project) REFERENCES project(id_project),
    CONSTRAINT fk_schedule_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS portfolio (
    id_portfolio BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    image_path VARCHAR(500),
    fk_project BIGINT,
    CONSTRAINT fk_portfolio_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retry_queue (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scheduled_date DATETIME(6),
    retrying BIT(1),
    fk_project BIGINT,
    CONSTRAINT fk_retry_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget (
    id_budget BIGINT AUTO_INCREMENT PRIMARY KEY,
    subtotal DECIMAL(19,2),
    total_cost DECIMAL(19,2),
    discount DECIMAL(19,2),
    material_cost DECIMAL(19,2),
    service_cost DECIMAL(19,2),
    created_at DATETIME(6),
    discount_type VARCHAR(255),
    final_budget BIT(1),
    fk_project BIGINT,
    CONSTRAINT fk_budget_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget_material (
    fk_budget BIGINT,
    fk_material_url BIGINT,
    quantity INT,
    price DECIMAL(19,2),
    PRIMARY KEY (fk_budget, fk_material_url),
    CONSTRAINT fk_bm_budget FOREIGN KEY (fk_budget) REFERENCES budget(id_budget),
    CONSTRAINT fk_bm_material_url FOREIGN KEY (fk_material_url) REFERENCES material_url(id_material_url)
) ENGINE=InnoDB;

-- 3. Carga de Dados (Inserts)
-- Usamos INSERT IGNORE para evitar erros se rodar mais de uma vez.

INSERT IGNORE INTO permission_group (id_permission_group, role, main_module, access_client, access_project, access_budget, access_schedule) VALUES
(1, 'ADMIN', 'PROJECT_LIST', 15, 15, 15, 15),
(2, 'TÉCNICO', 'SCHEDULE', 1, 7, 1, 15),
(3, 'SECRETÁRIA', 'CLIENT_LIST', 15, 3, 15, 1);

INSERT IGNORE INTO coworker (id_coworker, first_name, last_name, email, phone, password, is_active, fk_permission_group) VALUES
(1, 'Sálvio', 'Nobrega', 'salvio.admin@solarway.com.br', '11987654321', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 1),
(2, 'Cristiano', 'Ribeiro', 'cristiano.eng@solarway.com.br', '11912345678', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 2),
(3, 'Maria', 'Gomes', 'maria.tec@solarway.com.br', '11998765432', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 2),
(4, 'Ana', 'Vendas', 'ana.sales@solarway.com.br', '11955554444', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 3),
(5, 'Bryan', 'Rocha', 'bryangomesrocha@gmail.com', '11964275054', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 1);

INSERT IGNORE INTO address (id_address, postal_code, street_name, number, neighborhood, city, state, type) VALUES
(1, '13010-050', 'Rua XV de Novembro', '123', 'Centro', 'Campinas', 'SP', 'RESIDENTIAL'),
(2, '01311-000', 'Av. Paulista', '2000', 'Bela Vista', 'São Paulo', 'SP', 'BUILDING'),
(3, '88015-000', 'Rua Bocaiúva', '90', 'Centro', 'Florianópolis', 'SC', 'COMMERCIAL'),
(4, '22021-001', 'Av. Atlântica', '500', 'Copacabana', 'Rio de Janeiro', 'RJ', 'RESIDENTIAL'),
(5, '30130-000', 'Rua da Bahia', '1000', 'Centro', 'Belo Horizonte', 'MG', 'COMMERCIAL'),
(6, '70000-000', 'Asa Norte', 'SQN 102', 'Plano Piloto', 'Brasília', 'DF', 'RESIDENTIAL');

INSERT IGNORE INTO client (id_client, first_name, last_name, document_number, document_type, created_at, phone, email, fk_main_address, status) VALUES
(1, 'João', 'Silva', '12345678901', 'CPF', '2025-08-01 10:00:00', '1933233431', 'joao.silva@example.com', 1, 'ACTIVE'),
(2, 'Maria', 'Oliveira', '12345678902', 'CPF', '2025-09-10 14:30:00', '2199865432', 'maria.oliveira@example.com', 2, 'ACTIVE'),
(3, 'Pedro', 'Santos', '11222333000144', 'CNPJ', '2025-10-05 09:00:00', '4899123456', 'pedro.santos@example.com', 3, 'ACTIVE'),
(4, 'Lucia', 'Ferreira', '98765432100', 'CPF', '2025-10-20 11:00:00', '21988887777', 'lucia.ferreira@example.com', 4, 'ACTIVE'),
(5, 'Empresa Tech', 'Solar', '55666777000199', 'CNPJ', '2025-11-01 15:45:00', '3133334444', 'contato@techsolar.com', 5, 'ACTIVE');

INSERT IGNORE INTO project (id_project, name, description, status, status_weight, preview_status, is_active, system_type, project_from, created_at, deadline, fk_client, fk_responsible, fk_address) VALUES
(1, 'Residência João Silva', 'Instalação 5kWp', 'SCHEDULED_TECHNICAL_VISIT', 5, 'CLIENT_AWAITING_CONTACT', TRUE, 'ON_GRID', 'SITE_BUDGET_FORM', CURRENT_TIMESTAMP, DATE_ADD('2025-09-15', INTERVAL 30 DAY), 1, 2, 1),
(2, 'Clínica Maria Oliveira', 'Backup Off-grid', 'INSTALLED', 10, 'SCHEDULED_INSTALLING_VISIT', TRUE, 'OFF_GRID', 'WHATSAPP_BOT', CURRENT_TIMESTAMP, DATE_ADD('2025-09-20', INTERVAL 30 DAY), 2, 3, 2),
(3, 'Comércio Pedro Santos', 'Sistema Comercial', 'COMPLETED', 13, 'INSTALLED', TRUE, 'ON_GRID', 'INTERNAL_MANUAL_ENTRY', CURRENT_TIMESTAMP, DATE_ADD('2025-10-02', INTERVAL 30 DAY), 3, 1, 3),
(4, 'Casa de Praia Lucia', 'Off-grid simples', 'FINAL_BUDGET', 7, 'TECHNICAL_VISIT_COMPLETED', TRUE, 'OFF_GRID', 'SITE_BUDGET_FORM', CURRENT_TIMESTAMP, DATE_ADD('2025-10-15', INTERVAL 30 DAY), 4, 4, 4),
(5, 'Tech Solar Sede', 'Alta demanda', 'NEW', 3, NULL, TRUE, 'ON_GRID', 'INTERNAL_MANUAL_ENTRY', CURRENT_TIMESTAMP, DATE_ADD('2025-10-28', INTERVAL 30 DAY), 5, 2, 5);

INSERT IGNORE INTO material (id_material, name, metric, hidden, description) VALUES
(1, 'Painel Solar 550W (Solar Center)', 'UNIT', FALSE, 'Ficha Técnica Painel'),
(2, 'Inversor On-Grid 5kW (Painel Forte)', 'UNIT', FALSE, 'Manual Inversor'),
(3, 'Cabo Solar 6mm', 'METER', FALSE, NULL),
(4, 'Bateria 5kWh (EcoSolar)', 'UNIT', FALSE, 'Certificação Bateria'),
(5, 'Estrutura de Fixação Telhado', 'UNIT', FALSE, NULL);

INSERT IGNORE INTO material_url (id_material_url, url, fk_material, price, hidden) VALUES
(1, 'https://solarcenter.com/fichas/painel550w.pdf', 1, 900.00, FALSE),
(2, 'https://painelforte.com.br/manual/inversor5kw.pdf', 2, 3500.00, FALSE),
(3, 'https://ecosolar.com.br/docs/bateria5kwh.pdf', 4, 2800.00, FALSE),
(4, 'https://solarcenter.com/fichas/cabo6mm.pdf', 3, 12.00, FALSE),
(5, 'https://produto.mercadolivre.com.br/MLB-4289430353', 1, 820.00, FALSE),
(6, 'https://produto.mercadolivre.com.br/MLB-5387656668', 2, 2999.00, FALSE),
(7, 'https://produto.mercadolivre.com.br/MLB-4939530756', 3, 285.00, FALSE),
(8, 'https://produto.mercadolivre.com.br/MLB-3927049001', 4, 5975.00, FALSE),
(9, 'https://produto.mercadolivre.com.br/MLB-1943499077', 5, 417.55, FALSE);

INSERT IGNORE INTO coworker_project (fk_coworker, fk_project, is_responsible) VALUES
(2, 1, TRUE),
(3, 2, TRUE),
(1, 3, TRUE),
(4, 4, TRUE),
(2, 5, TRUE);

INSERT IGNORE INTO schedule (id_schedule, title, description, start_date, end_date, type, status, is_active, fk_project, fk_coworker) VALUES
(1, 'Visita Técnica João', 'Medição de telhado', DATE_ADD(NOW(), INTERVAL 24 HOUR), DATE_ADD(NOW(), INTERVAL 26 HOUR), 'TECHNICAL_VISIT', 'MARKED', TRUE, 1, 2),
(2, 'Instalação Maria', 'Instalação Off-grid', DATE_ADD(NOW(), INTERVAL -10 DAY), DATE_ADD(NOW(), INTERVAL -7 DAY), 'INSTALL_VISIT', 'FINISHED', TRUE, 1, 3);

INSERT IGNORE INTO portfolio (id_portfolio, title, description, image_path, fk_project) VALUES
(1, 'Residência Sustentável', 'Sistema 5kWp em telhado cerâmico', '/images/portfolio/joao_v1.jpg', 1),
(2, 'Backup Hospitalar', 'Sistema de segurança energética', '/images/portfolio/maria_clinic.jpg', 2);

INSERT IGNORE INTO budget (id_budget, subtotal, total_cost, discount, material_cost, service_cost, created_at, discount_type, final_budget, fk_project) VALUES
(1, 15000.00, 10000.00, 50.00, 8000.00, 2000.00, NOW(), 'PERCENT', TRUE, 1),
(2, 35000.00, 25000.00, 250.00, 20000.00, 5000.00, NOW(), 'AMOUNT', TRUE, 2);

INSERT IGNORE INTO budget_material (fk_budget, fk_material_url, quantity, price) VALUES
(1, 1, 10, 900.00),
(1, 4, 100, 12.00),
(2, 2, 1, 3500.00),
(2, 3, 2, 2800.00);

-- 4. Views de Análise
CREATE OR REPLACE VIEW VIEW_ANALYSIS_PROJECT_FINANCE AS
SELECT
    p.id_project,
    p.project_from AS acquisition_channel,
    p.created_at,
    p.status,
    COALESCE(0, 0) AS total_revenue, -- Simplificado
    COALESCE(0, 0) AS total_project_cost,
    COALESCE(0, 0) AS profit_margin,
    'Outras Etapas' AS funnel_stage
FROM
    project p;